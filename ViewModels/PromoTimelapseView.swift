import SwiftUI
import Combine
import UserNotifications
import AudioToolbox

@MainActor
class PomodoroViewModel: ObservableObject {
    
    // MARK: - Persistence Keys
    private let tasksKey = "TempusTasks_v3"
    private let statsKey = "TempusStats_v3"
    private let settingsKey = "TempusSettings_v3"
    private let lastStateKey = "TempusLastState_v3"

    // MARK: - Public State
    @Published var timeLeft: TimeInterval
    @Published var currentMode: Mode = .pomodoro
    @Published var isRunning: Bool = false
    @Published var clockViewType: ClockViewType = .digital
    @Published var pendingTasks: [Task] = []
    @Published var completedTasks: [Task] = []
    
    // MARK: - Statistics State
    @Published var pomodoroSessionCount: Int = 0
    @Published var totalPomodorosCompleted: Int = 0
    @Published var totalTasksCompleted: Int = 0
    @Published var totalBreaksTaken: Int = 0
    @Published var focusTimeByDay: [String: TimeInterval] = [:]

    // MARK: - Settings
    @Published var pomodoroDuration: TimeInterval = 25 * 60
    @Published var shortBreakDuration: TimeInterval = 5 * 60
    @Published var longBreakDuration: TimeInterval = 15 * 60
    @Published var sessionsBeforeLongBreak: Int = 4
    @Published var isContinuousModeEnabled: Bool = false

    // MARK: - Computed Properties
    var currentModeDuration: TimeInterval {
        switch currentMode {
        case .pomodoro: return pomodoroDuration
        case .shortBreak: return shortBreakDuration
        case .longBreak: return longBreakDuration
        }
    }
    
    // MARK: - Private Properties
    private var timer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization & Lifecycle
    init() {
        self.timeLeft = 25 * 60
        loadSettings()
        loadTasks()
        loadStats()
        recalculateTimeLeftOnLaunch()
        setupBindingsForPersistence()
        setupLifecycleObserver()
        requestNotificationPermission()
    }
    
    private func setupBindingsForPersistence() {
        Publishers.CombineLatest($pendingTasks, $completedTasks)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveTasks() }
            .store(in: &cancellables)
            
        Publishers.CombineLatest4($focusTimeByDay, $totalPomodorosCompleted, $totalTasksCompleted, $totalBreaksTaken)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] (timeByDay, totalPomodoros, totalTasks, totalBreaks) in
                self?.saveStats(timeByDay: timeByDay, totalPomodoros: totalPomodoros, totalTasks: totalTasks, totalBreaks: totalBreaks)
            }
            .store(in: &cancellables)
        
        let settingsPublisher = Publishers.CombineLatest4($pomodoroDuration, $shortBreakDuration, $longBreakDuration, $sessionsBeforeLongBreak)
            .combineLatest($isContinuousModeEnabled)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] (settingsTuple, isContinuous) in
                let (pomodoro, short, long, sessions) = settingsTuple
                self?.saveSettings(pomodoro: pomodoro, short: short, long: long, sessions: sessions, isContinuous: isContinuous)
            }
        settingsPublisher.store(in: &cancellables)
    }
    
    private func setupLifecycleObserver() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).sink { [weak self] _ in self?.appWillResignActive() }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification).sink { [weak self] _ in self?.appWillEnterForeground() }.store(in: &cancellables)
    }
    
    // MARK: - Enums
    enum Mode: Codable {
        case pomodoro, shortBreak, longBreak
        var color: Color {
            switch self {
            case .pomodoro: return Color(red: 214/255, green: 72/255, blue: 62/255)
            case .shortBreak: return .green
            case .longBreak: return .blue
            }
        }
    }
    enum ClockViewType { case digital, analog }

    // MARK: - Timer Control
    func startPauseTimer() { isRunning ? pauseTimer() : startTimer() }
    
    private func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        let endDate = Date().addingTimeInterval(timeLeft)
        scheduleNotification(at: endDate)
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self else { return }
            if self.timeLeft > 1 { self.timeLeft -= 1 } else { self.timeLeft = 0; self.sessionDidFinish() }
        }
    }
    
    func pauseTimer() {
        guard isRunning else { return }
        isRunning = false
        timer?.cancel()
        cancelNotification()
        UserDefaults.standard.removeObject(forKey: self.lastStateKey)
    }

    func resetCurrentSession() { pauseTimer(); timeLeft = currentModeDuration }
    
    func skipToNextMode() {
        pauseTimer(); AudioServicesPlaySystemSound(1104)
        if currentMode == .pomodoro {
            let nextSessionCount = pomodoroSessionCount + 1
            currentMode = (nextSessionCount % sessionsBeforeLongBreak == 0) ? .longBreak : .shortBreak
        } else { currentMode = .pomodoro }
        resetCurrentSession()
    }
    
    private func sessionDidFinish() {
        let wasRunning = isRunning; pauseTimer(); AudioServicesPlaySystemSound(1005)
        if currentMode == .pomodoro {
            recordPomodoroCompletion(duration: self.pomodoroDuration)
            pomodoroSessionCount += 1
            currentMode = (pomodoroSessionCount % sessionsBeforeLongBreak == 0) ? .longBreak : .shortBreak
        } else {
            totalBreaksTaken += 1
            currentMode = .pomodoro
        }
        resetCurrentSession()
        if isContinuousModeEnabled && wasRunning { startTimer() }
    }
    
    func toggleClockView() { clockViewType = (clockViewType == .digital) ? .analog : .digital }
    
    // MARK: - Settings Management
    func restoreDefaultSettings() {
        pomodoroDuration = 25 * 60; shortBreakDuration = 5 * 60; longBreakDuration = 15 * 60; sessionsBeforeLongBreak = 4; isContinuousModeEnabled = false
        if !isRunning { timeLeft = currentModeDuration }
    }
    
    func resetPomodoroCycle() { pomodoroSessionCount = 0 }
    
    // MARK: - Task Management
    func addTask(text: String) { pendingTasks.append(Task(text: text)) }
    func updateTask(task: Task, newText: String) {
        if let index = pendingTasks.firstIndex(where: { $0.id == task.id }) { pendingTasks[index].text = newText }
        else if let index = completedTasks.firstIndex(where: { $0.id == task.id }) { completedTasks[index].text = newText }
    }
    func toggleTaskCompletion(task: Task) {
        if let index = pendingTasks.firstIndex(where: { $0.id == task.id }) {
            var taskToMove = pendingTasks.remove(at: index); taskToMove.isCompleted = true; completedTasks.insert(taskToMove, at: 0); totalTasksCompleted += 1
        } else if let index = completedTasks.firstIndex(where: { $0.id == task.id }) {
            var taskToMove = completedTasks.remove(at: index); taskToMove.isCompleted = false; pendingTasks.append(taskToMove)
            if totalTasksCompleted > 0 { totalTasksCompleted -= 1 }
        }
    }
    func deleteTask(at offsets: IndexSet, in_completedList: Bool) {
        let tasksAboutToBeDeleted = in_completedList ? offsets.map { completedTasks[$0] } : offsets.map { pendingTasks[$0] }
        let completedCountInSelection = tasksAboutToBeDeleted.filter { $0.isCompleted }.count
        if completedCountInSelection > 0 { totalTasksCompleted -= completedCountInSelection }
        if in_completedList { completedTasks.remove(atOffsets: offsets) } else { pendingTasks.remove(atOffsets: offsets) }
    }
    func movePendingTask(from source: IndexSet, to destination: Int) { pendingTasks.move(fromOffsets: source, toOffset: destination) }
    func clearCompletedTasks() { completedTasks.removeAll() }
    
    // MARK: - Statistics Management
    private func recordPomodoroCompletion(duration: TimeInterval) {
        let key = Date.keyFormatter.string(from: Date()); focusTimeByDay[key, default: 0] += duration; totalPomodorosCompleted += 1
    }
    var weeklyFocusStats: [FocusStat] {
        let calendar = Calendar.current; let today = Date()
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = Date.keyFormatter.string(from: date); let dayAbbrev = Date.dayFormatter.string(from: date).capitalized
            let duration = focusTimeByDay[key] ?? 0; return FocusStat(day: dayAbbrev, duration: duration)
        }
    }
    var totalFocusTimeFormatted: String {
        let totalSeconds = focusTimeByDay.values.reduce(0, +); let hours = Int(totalSeconds) / 3600; let minutes = (Int(totalSeconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    // MARK: - Background Handling & Notifications
    private func recalculateTimeLeftOnLaunch() {
        guard let lastState = loadLastState(), lastState.isRunning else { timeLeft = currentModeDuration; return }
        let timePassed = Date().timeIntervalSince(lastState.timestamp); let newTimeLeft = lastState.timeLeft - timePassed
        if newTimeLeft > 0 { self.timeLeft = newTimeLeft; self.currentMode = lastState.mode; startTimer()
        } else { self.timeLeft = 0; self.currentMode = lastState.mode; sessionDidFinish() }
    }
    private func appWillEnterForeground() { recalculateTimeLeftOnLaunch() }
    private func appWillResignActive() { if isRunning { saveLastState() } else { UserDefaults.standard.removeObject(forKey: lastStateKey) } }
    private func requestNotificationPermission() { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }
    private func scheduleNotification(at date: Date) {
        cancelNotification(); let content = UNMutableNotificationContent()
        content.title = "Time's up!"; content.body = currentMode == .pomodoro ? "Great work! Time for a well-deserved break." : "Break is over. Time to focus!"; content.sound = UNNotificationSound.default
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date), repeats: false)
        let request = UNNotificationRequest(identifier: "pomodoroEnd", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    private func cancelNotification() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pomodoroEnd"]) }
    
    // MARK: - Persistence
    private func saveTasks() { let allTasks = pendingTasks + completedTasks; if let data = try? JSONEncoder().encode(allTasks) { UserDefaults.standard.set(data, forKey: tasksKey) } }
    private func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: tasksKey), let allTasks = try? JSONDecoder().decode([Task].self, from: data) else { return }
        pendingTasks = allTasks.filter { !$0.isCompleted }; completedTasks = allTasks.filter { $0.isCompleted }
    }
    private func saveStats(timeByDay: [String: TimeInterval], totalPomodoros: Int, totalTasks: Int, totalBreaks: Int) {
        let stats: [String: Any] = ["focusTimeByDay": timeByDay, "totalPomodoros": totalPomodoros, "totalTasks": totalTasks, "totalBreaks": totalBreaks]
        if let data = try? JSONSerialization.data(withJSONObject: stats) { UserDefaults.standard.set(data, forKey: statsKey) }
    }
    private func loadStats() {
        guard let data = UserDefaults.standard.data(forKey: statsKey), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        focusTimeByDay = json["focusTimeByDay"] as? [String: TimeInterval] ?? [:]; totalPomodorosCompleted = json["totalPomodoros"] as? Int ?? 0; totalTasksCompleted = json["totalTasks"] as? Int ?? 0; totalBreaksTaken = json["totalBreaks"] as? Int ?? 0
    }
    private func saveSettings(pomodoro: TimeInterval, short: TimeInterval, long: TimeInterval, sessions: Int, isContinuous: Bool) {
        let settings: [String: Any] = ["pomodoroDuration": pomodoro, "shortBreakDuration": short, "longBreakDuration": long, "sessionsBeforeLongBreak": sessions, "isContinuousModeEnabled": isContinuous]
        UserDefaults.standard.set(settings, forKey: settingsKey)
    }
    private func loadSettings() {
        let settings = UserDefaults.standard.dictionary(forKey: settingsKey)
        pomodoroDuration = settings?["pomodoroDuration"] as? TimeInterval ?? 25 * 60; shortBreakDuration = settings?["shortBreakDuration"] as? TimeInterval ?? 5 * 60; longBreakDuration = settings?["longBreakDuration"] as? TimeInterval ?? 15 * 60
        sessionsBeforeLongBreak = settings?["sessionsBeforeLongBreak"] as? Int ?? 4; isContinuousModeEnabled = settings?["isContinuousModeEnabled"] as? Bool ?? false
        if !isRunning { timeLeft = currentModeDuration }
    }
    private func saveLastState() { let state = LastAppState(isRunning: isRunning, timeLeft: timeLeft, mode: currentMode, timestamp: Date()); if let data = try? JSONEncoder().encode(state) { UserDefaults.standard.set(data, forKey: lastStateKey) } }
    private func loadLastState() -> LastAppState? { guard let data = UserDefaults.standard.data(forKey: lastStateKey), let state = try? JSONDecoder().decode(LastAppState.self, from: data) else { return nil }; return state }
    struct LastAppState: Codable { let isRunning: Bool; let timeLeft: TimeInterval; let mode: Mode; let timestamp: Date }
    
}

/// Represents a data point for the statistics chart.
struct FocusStat: Identifiable {
    let id = UUID()
    let day: String
    let duration: TimeInterval
}

// MARK: - Utility Extensions
extension Date {
    static let keyFormatter: DateFormatter = { let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; return df }()
    static let dayFormatter: DateFormatter = { let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "E"; return df }()
}
