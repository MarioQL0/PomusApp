//
//  PomodoroViewModel.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 11/07/25.
//

import SwiftUI
import Combine
import UserNotifications
import AudioToolbox
import ActivityKit
import WidgetKit
import OSLog

@MainActor
class PomodoroViewModel: ObservableObject {
    
    // MARK: - Persistence Keys
    private let tasksKey = "PomusTasks_v3"
    private let statsKey = "PomusStats_v3"
    private let settingsKey = "PomusSettings_v3"
    private let lastStateKey = "PomusLastState_v3"
    private let appGroupID = "group.com.marioquezada.Pomus"
    private let logger = Logger(subsystem: "com.marioquezada.Pomus", category: "Timer")

    // MARK: - Public State
    /// The time remaining in the current session, in seconds.
    @Published var timeLeft: TimeInterval
    /// The current mode of the timer (pomodoro, short break, or long break).
    @Published var currentMode: Mode = .pomodoro
    /// Indicates if the timer is currently running or paused.
    var isRunning: Bool { timerState.isRunning }
    /// Controls whether the digital or analog clock is displayed.
    @Published var clockViewType: ClockViewType = .digital
    /// The array of tasks that are not yet completed.
    @Published var pendingTasks: [PomodoroTask] = []
    /// The array of tasks that have been completed.
    @Published var completedTasks: [PomodoroTask] = []
    
    // MARK: - Statistics State
    /// Counts focus sessions to determine when to take a long break.
    @Published var pomodoroSessionCount: Int = 0
    /// The total number of pomodoros completed historically.
    @Published var totalPomodorosCompleted: Int = 0
    /// The total number of completed tasks.
    @Published var totalTasksCompleted: Int = 0
    /// The total number of completed breaks.
    @Published var totalBreaksTaken: Int = 0
    /// A dictionary that stores the total focus time per day.
    @Published var focusTimeByDay: [String: TimeInterval] = [:]

    // MARK: - Settings
    @Published var pomodoroDuration: TimeInterval = 25 * 60
    @Published var shortBreakDuration: TimeInterval = 5 * 60
    @Published var longBreakDuration: TimeInterval = 15 * 60
    @Published var sessionsBeforeLongBreak: Int = 4
    @Published var isContinuousModeEnabled: Bool = false
    
    // MARK: - UI State
    /// Controls the visibility of the "Cycle Complete!" pop-up.
    @Published var showCongratulations = false
    /// Holds a reference to the current Live Activity to update or end it.
    @Published var currentActivity: Activity<PomusActivityAttributes>? = nil

    // MARK: - Computed Properties
    /// Returns the duration of the current session based on the current mode.
    var currentModeDuration: TimeInterval {
        switch currentMode {
        case .pomodoro: return pomodoroDuration
        case .shortBreak: return shortBreakDuration
        case .longBreak: return longBreakDuration
        }
    }
    
    // MARK: - Timer State & Private Properties
    /// The single source of truth for timing shared with widgets and live activity.
    @Published var timerState = PomusTimerState()

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
    
    /// Sets up Combine publishers to automatically save data when it changes.
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
    
    /// Observes system notifications to handle background/foreground state changes.
    private func setupLifecycleObserver() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).sink { [weak self] _ in self?.appWillResignActive() }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification).sink { [weak self] _ in self?.appWillEnterForeground() }.store(in: &cancellables)
    }
    
    // MARK: - Enums
    enum Mode: Codable {
        case pomodoro, shortBreak, longBreak
        var color: Color {
            switch self {
            case .pomodoro: return Color("FocusColor")
            case .shortBreak, .longBreak: return Color("BreakColor")
            }
        }
    }
    enum ClockViewType { case digital, analog }

    // MARK: - Timer Control
    /// Starts a new session or toggles between pause and resume depending on
    /// the current `timerState`. When idle it begins a focus session, when
    /// running it pauses, and when paused it resumes.
    func startPauseTimer() {
        switch timerState.status {
        case .idle:
            startFocus()
        case .focus, .breakTime:
            pause()
        case .paused:
            resume()
        }
    }

    /// Stops the current session and resets the timer to its initial state
    /// without starting a new one.
    func resetCurrentSession() {
        stop()
    }

    /// Starts a focus session using the configured `pomodoroDuration`.
    func startFocus() { startSession(duration: pomodoroDuration, status: .focus, modeName: "Focus", color: "FocusColor") }

    /// Starts a break session. If `long` is true the long break duration is used.
    func startBreak(long: Bool = false) {
        let duration = long ? longBreakDuration : shortBreakDuration
        let name = long ? "Long Break" : "Break"
        startSession(duration: duration, status: .breakTime, modeName: name, color: "BreakColor")
    }

    private func startSession(duration: TimeInterval, status: PomusTimerState.Status, modeName: String, color: String) {
        timer?.cancel()
        let now = Date()
        timerState.status = status
        timerState.startDate = now
        timerState.endDate = now.addingTimeInterval(duration)
        timerState.pauseDate = nil
        timerState.accumulatedPause = 0
        timerState.modeName = modeName
        timerState.modeColorName = color
        timerState.sessionCount = pomodoroSessionCount
        timerState.totalSessions = sessionsBeforeLongBreak
        timeLeft = duration
        logger.debug("Session started: \(modeName)")

        scheduleNotification(at: timerState.endDate!)
        if currentActivity == nil { startLiveActivity() } else { updateLiveActivity() }
        persistAndReload(reason: "start")

        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] date in
            self?.tick(now: date)
        }
    }

    /// Pauses the running timer and freezes progress everywhere.
    func pause() {
        guard timerState.isRunning else { return }
        timer?.cancel()
        timerState.status = .paused
        timerState.pauseDate = Date()
        timeLeft = timerState.remainingTime()
        cancelNotification()
        updateLiveActivity()
        persistAndReload(reason: "pause")
        saveLastState()
        logger.debug("Timer paused")
    }

    /// Resumes a previously paused timer.
    func resume() {
        guard timerState.status == .paused else { return }
        if let pauseDate = timerState.pauseDate {
            timerState.accumulatedPause += Date().timeIntervalSince(pauseDate)
        }
        timerState.pauseDate = nil
        timerState.status = timerState.modeName.contains("Break") ? .breakTime : .focus
        scheduleNotification(at: timerState.endDate!)
        updateLiveActivity()
        persistAndReload(reason: "resume")
        saveLastState()

        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] date in
            self?.tick(now: date)
        }
        logger.debug("Timer resumed")
    }

    /// Stops the current session and resets state to idle.
    func stop() {
        timer?.cancel()
        cancelNotification()
        timerState = PomusTimerState(status: .idle,
                                     sessionCount: pomodoroSessionCount,
                                     totalSessions: sessionsBeforeLongBreak,
                                     modeName: "",
                                     modeColorName: "FocusColor")
        timeLeft = currentModeDuration
        endLiveActivity()
        persistAndReload(reason: "stop")
        saveLastState()
        logger.debug("Timer stopped")
    }

    /// Called every second to update the remaining time and detect completion.
    private func tick(now: Date) {
        timeLeft = timerState.remainingTime(at: now)
        if timeLeft <= 0 {
            sessionDidFinish()
        }
    }

    /// Skips the current session and moves to the next one in the cycle.
    func skipToNextMode() {
        pause(); AudioServicesPlaySystemSound(1104)
        if currentMode == .pomodoro {
            let next = pomodoroSessionCount + 1
            currentMode = (next % sessionsBeforeLongBreak == 0) ? .longBreak : .shortBreak
        } else { currentMode = .pomodoro }
        let modeName = currentMode == .pomodoro ? "Focus" : (currentMode == .longBreak ? "Long Break" : "Break")
        let color = currentMode == .pomodoro ? "FocusColor" : "BreakColor"
        timerState.modeName = modeName
        timerState.modeColorName = color
        timerState.sessionCount = pomodoroSessionCount
        timerState.totalSessions = sessionsBeforeLongBreak
        timerState.startDate = Date()
        timerState.endDate = Date().addingTimeInterval(currentModeDuration)
        timerState.pauseDate = Date()
        timerState.accumulatedPause = 0
        timerState.status = .paused
        timeLeft = currentModeDuration
        persistAndReload(reason: "skip")
        saveLastState()
    }

    /// Handles the logic for when a session timer reaches zero.
    private func sessionDidFinish() {
        timer?.cancel()
        logger.debug("Session finished")
        AudioServicesPlaySystemSound(1005)

        if currentMode == .pomodoro {
            recordPomodoroCompletion(duration: pomodoroDuration)
            pomodoroSessionCount += 1
            currentMode = (pomodoroSessionCount % sessionsBeforeLongBreak == 0) ? .longBreak : .shortBreak
        } else {
            totalBreaksTaken += 1
            if pomodoroSessionCount >= sessionsBeforeLongBreak {
                pomodoroSessionCount = 0
                showCongratulationsView()
            }
            currentMode = .pomodoro
        }

        timerState.status = .idle
        timeLeft = currentModeDuration
        endLiveActivity()
        persistAndReload(reason: "finished")
        saveLastState()

        if isContinuousModeEnabled { startNextAutomatically() }
    }

    private func startNextAutomatically() {
        if currentMode == .pomodoro {
            startFocus()
        } else {
            startBreak(long: currentMode == .longBreak)
        }
    }
    
    /// Shows the "Cycle Complete!" pop-up and hides it after a delay.
    private func showCongratulationsView() {
        showCongratulations = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.showCongratulations = false
        }
    }
    
    /// Toggles between the digital and analog clock styles.
    func toggleClockView() { clockViewType = (clockViewType == .digital) ? .analog : .digital }
    
    // MARK: - Settings Management
    /// Resets all settings to their default values.
    func restoreDefaultSettings() {
        pomodoroDuration = 25 * 60; shortBreakDuration = 5 * 60; longBreakDuration = 15 * 60; sessionsBeforeLongBreak = 4; isContinuousModeEnabled = false
        if !isRunning { timeLeft = currentModeDuration }
    }
    
    /// Resets the current pomodoro cycle count to zero.
    func resetPomodoroCycle() { pomodoroSessionCount = 0 }
    
    // MARK: - Task Management
    func addTask(text: String, dueDate: Date? = nil) {
        pendingTasks.append(PomodoroTask(text: text, dueDate: dueDate))
    }

    func updateTask(task: PomodoroTask, newText: String, newDueDate: Date?) {
        if let index = pendingTasks.firstIndex(where: { $0.id == task.id }) {
            pendingTasks[index].text = newText
            pendingTasks[index].dueDate = newDueDate
        } else if let index = completedTasks.firstIndex(where: { $0.id == task.id }) {
            completedTasks[index].text = newText
            completedTasks[index].dueDate = newDueDate
        }
    }
    func toggleTaskCompletion(task: PomodoroTask) {
        if let index = pendingTasks.firstIndex(where: { $0.id == task.id }) {
            var taskToMove = pendingTasks.remove(at: index); taskToMove.isCompleted = true; completedTasks.insert(taskToMove, at: 0); totalTasksCompleted += 1
        } else if let index = completedTasks.firstIndex(where: { $0.id == task.id }) {
            var taskToMove = completedTasks.remove(at: index); taskToMove.isCompleted = false; pendingTasks.append(taskToMove)
            if totalTasksCompleted > 0 { totalTasksCompleted -= 1 }
        }
    }
    func deleteTask(at offsets: IndexSet, in_completedList: Bool) {
        let tasksToDelete = in_completedList ? offsets.map { completedTasks[$0] } : offsets.map { pendingTasks[$0] }
        let completedCount = tasksToDelete.filter { $0.isCompleted }.count
        if completedCount > 0 { totalTasksCompleted -= completedCount }
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
    
    // MARK: - Live Activity Management

    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, currentActivity == nil else { return }
        let attributes = PomusActivityAttributes()
        let content = PomusActivityAttributes.ContentState(timer: timerState)
        do {
            let activity = try Activity<PomusActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: content, staleDate: timerState.endDate)
            )
            self.currentActivity = activity
            logger.debug("Live activity started")
        } catch {
            logger.error("Error requesting Live Activity: \(error.localizedDescription)")
        }
        persistAndReload(reason: "startActivity")
    }

    func updateLiveActivity() {
        Task {
            let content = PomusActivityAttributes.ContentState(timer: timerState)
            await currentActivity?.update(using: content)
            logger.debug("Live activity update")
        }
        persistAndReload(reason: "updateActivity")
    }

    /// Ends the live activity immediately.
    func endLiveActivity() {
        Task {
            await currentActivity?.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
            logger.debug("Live activity ended")
        }
    }

    // MARK: - Widget & Extension Synchronization
    private func persistAndReload(reason: String) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(timerState) else { return }
        sharedDefaults.set(data, forKey: "timerState")
        WidgetCenter.shared.reloadAllTimelines()
        logger.info("Shared state sync: \(reason)")
    }
    
    // Legacy helpers removed in favor of `timerState` properties
    
    // MARK: - Background Handling & Notifications
    private func recalculateTimeLeftOnLaunch() {
        guard let lastState = loadLastState() else {
            timeLeft = currentModeDuration
            return
        }

        currentMode = lastState.mode
        let now = Date()
        let modeName = currentMode == .pomodoro ? "Focus" : (currentMode == .longBreak ? "Long Break" : "Break")
        let color = currentMode == .pomodoro ? "FocusColor" : "BreakColor"
        timerState.modeName = modeName
        timerState.modeColorName = color
        timerState.sessionCount = pomodoroSessionCount
        timerState.totalSessions = sessionsBeforeLongBreak

        if lastState.isRunning {
            let timePassed = now.timeIntervalSince(lastState.timestamp)
            let remaining = lastState.timeLeft - timePassed
            if remaining > 0 {
                timeLeft = remaining
                timerState.status = currentMode == .pomodoro ? .focus : .breakTime
                timerState.startDate = now.addingTimeInterval(-(currentModeDuration - remaining))
                timerState.endDate = timerState.startDate!.addingTimeInterval(currentModeDuration)
                timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] date in
                    self?.tick(now: date)
                }
                startLiveActivity()
            } else {
                timeLeft = 0
                sessionDidFinish()
            }
        } else {
            timeLeft = lastState.timeLeft
            if timeLeft < currentModeDuration {
                timerState.status = .paused
                timerState.startDate = now.addingTimeInterval(-(currentModeDuration - timeLeft))
                timerState.endDate = timerState.startDate!.addingTimeInterval(currentModeDuration)
                timerState.pauseDate = now
            } else {
                timerState.status = .idle
            }
        }
    }
    private func appWillEnterForeground() { recalculateTimeLeftOnLaunch() }
    private func appWillResignActive() { saveLastState() }
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
        guard let data = UserDefaults.standard.data(forKey: tasksKey), let allTasks = try? JSONDecoder().decode([PomodoroTask].self, from: data) else { return }
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
    
    struct LastAppState: Codable {
        let isRunning: Bool
        let timeLeft: TimeInterval
        let mode: Mode
        let timestamp: Date
    }
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
