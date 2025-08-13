//
//  PomodoroViewModel.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 11/07/25.
//
//  Reestructurado para una funcionalidad premium, robusta y estable.
//

import SwiftUI
import Combine
import UserNotifications
import AudioToolbox
import ActivityKit
import AVFoundation // Necesario para los sonidos de ambiente

@MainActor
class PomodoroViewModel: ObservableObject {

    // MARK: - Enums Públicos
    
    /// Define los modos de sesión posibles.
    enum Mode: Codable, Equatable {
        case pomodoro, shortBreak, longBreak
        
        var color: Color {
            switch self {
            case .pomodoro: return Color("FocusColor")
            case .shortBreak, .longBreak: return Color("BreakColor")
            }
        }
        
        var modeName: String {
            switch self {
            case .pomodoro: return "Focus"
            case .shortBreak: return "Break"
            case .longBreak: return "Long Break"
            }
        }
    }
    
    /// Define los tipos de vista del reloj.
    enum ClockViewType {
        case digital, analog
    }

    // MARK: - State Properties (La Única Fuente de la Verdad)
    
    @Published var timeLeft: TimeInterval
    @Published var currentMode: Mode = .pomodoro
    @Published var isRunning: Bool = false
    
    // UI State
    @Published var clockViewType: ClockViewType = .digital
    @Published var showCongratulations = false

    // Listas de Tareas
    @Published var pendingTasks: [PomodoroTask] = []
    @Published var completedTasks: [PomodoroTask] = []

    // Estadísticas
    @Published var pomodoroSessionCount: Int = 0
    @Published var totalPomodorosCompleted: Int = 0
    @Published var totalTasksCompleted: Int = 0
    @Published var totalBreaksTaken: Int = 0
    @Published var focusTimeByDay: [String: TimeInterval] = [:]

    // Ajustes del Usuario (Settings)
    @Published var pomodoroDuration: TimeInterval = 25 * 60
    @Published var shortBreakDuration: TimeInterval = 5 * 60
    @Published var longBreakDuration: TimeInterval = 15 * 60
    @Published var sessionsBeforeLongBreak: Int = 4
    @Published var isContinuousModeEnabled: Bool = false

    // MARK: - Premium Feature Properties
    
    /// Referencia a la Live Activity actual para poder actualizarla o terminarla.
    @Published private var currentActivity: Activity<PomusActivityAttributes>? = nil
    
    /// Reproductor de audio para los sonidos de ambiente.
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - Propiedades Computadas
    
    /// Devuelve la duración de la sesión actual basándose en el modo.
    var currentModeDuration: TimeInterval {
        switch currentMode {
        case .pomodoro: return pomodoroDuration
        case .shortBreak: return shortBreakDuration
        case .longBreak: return longBreakDuration
        }
    }

    // MARK: - Propiedades Privadas
    
    private var timer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    // Claves para persistencia de datos (UserDefaults)
    private let tasksKey = "PomusTasks_v3"
    private let statsKey = "PomusStats_v3"
    private let settingsKey = "PomusSettings_v3"
    private let lastStateKey = "PomusLastState_v3"

    // MARK: - Inicialización y Ciclo de Vida
    
    init() {
        // El tiempo restante se carga desde los ajustes guardados.
        self.timeLeft = UserDefaults.standard.double(forKey: "pomodoroDuration") > 0 ? UserDefaults.standard.double(forKey: "pomodoroDuration") : 25 * 60
        
        // Cargar todos los datos del usuario al iniciar.
        loadSettings()
        loadTasks()
        loadStats()
        
        // Configurar la reactividad y el manejo del ciclo de vida de la app.
        setupBindingsForPersistence()
        setupLifecycleObserver()
        requestNotificationPermission()
        
        // Revisa si había un estado guardado al cerrar la app.
        recalculateTimeLeftOnLaunch()
    }
    
    /// Configura Combine para guardar datos automáticamente cuando cambian.
    private func setupBindingsForPersistence() {
        // Guarda tareas cuando se modifican.
        Publishers.CombineLatest($pendingTasks, $completedTasks)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveTasks() }
            .store(in: &cancellables)
            
        // Guarda estadísticas cuando se actualizan.
        Publishers.CombineLatest4($focusTimeByDay, $totalPomodorosCompleted, $totalTasksCompleted, $totalBreaksTaken)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] (timeByDay, totalPomodoros, totalTasks, totalBreaks) in
                self?.saveStats(timeByDay: timeByDay, totalPomodoros: totalPomodoros, totalTasks: totalTasks, totalBreaks: totalBreaks)
            }
            .store(in: &cancellables)
        
        // Guarda los ajustes cuando el usuario los cambia.
        let settingsPublisher = Publishers.CombineLatest4($pomodoroDuration, $shortBreakDuration, $longBreakDuration, $sessionsBeforeLongBreak)
            .combineLatest($isContinuousModeEnabled)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] (settingsTuple, isContinuous) in
                let (pomodoro, short, long, sessions) = settingsTuple
                self?.saveSettings(pomodoro: pomodoro, short: short, long: long, sessions: sessions, isContinuous: isContinuous)
            }
        settingsPublisher.store(in: &cancellables)
    }
    
    /// Observa notificaciones del sistema para manejar los estados de la app (background/foreground).
    private func setupLifecycleObserver() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).sink { [weak self] _ in self?.appWillResignActive() }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification).sink { [weak self] _ in self?.appWillEnterForeground() }.store(in: &cancellables)
    }

    // MARK: - Control Principal del Temporizador
    
    /// Inicia o pausa el temporizador. Es el punto de entrada principal del usuario.
    func startPauseTimer() {
        // Feedback háptico para una sensación premium.
        playHapticFeedback(style: .medium)
        
        if isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }
    
    /// Inicia el temporizador y las actualizaciones.
    private func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        
        // Inicia o reanuda la Live Activity con el estado correcto.
        if currentActivity == nil {
            startLiveActivity()
        } else {
            updateLiveActivityState(isPaused: false)
        }
        
        let endDate = Date().addingTimeInterval(timeLeft)
        scheduleLocalNotification(at: endDate)
        updateSharedWidgetData()

        // Inicia el contador de un segundo.
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self else { return }
            
            if self.timeLeft > 1 {
                self.timeLeft -= 1
            } else {
                self.timeLeft = 0
                self.sessionDidFinish()
            }
        }
    }
    
    /// Pausa el temporizador y actualiza el estado de la UI y las extensiones.
    func pauseTimer() {
        guard isRunning else { return }
        isRunning = false
        timer?.cancel()
        
        // Notifica a la Live Activity y al Widget que el estado es "pausado".
        updateLiveActivityState(isPaused: true)
        updateSharedWidgetData()
        cancelLocalNotification()
        
        // Limpiamos el estado guardado ya que la sesión está en pausa, no abandonada.
        UserDefaults.standard.removeObject(forKey: self.lastStateKey)
    }

    /// Reinicia la sesión actual a su duración completa.
    func resetCurrentSession() {
        playHapticFeedback(style: .light)
        pauseTimer()
        timeLeft = currentModeDuration
        updateLiveActivityState(isPaused: true) // Asegura que la Live Activity refleje el reinicio en estado de pausa.
        updateSharedWidgetData()
    }
    
    /// Salta a la siguiente sesión en el ciclo.
    func skipToNextMode() {
        playHapticFeedback(style: .medium)
        AudioServicesPlaySystemSound(1104) // Sonido de sistema para "skip".
        
        pauseTimer()
        
        if currentMode == .pomodoro {
            // Si estábamos en Pomodoro, avanzamos al siguiente descanso.
            let nextSessionCount = pomodoroSessionCount + 1
            currentMode = (nextSessionCount % sessionsBeforeLongBreak == 0) ? .longBreak : .shortBreak
        } else {
            // Si estábamos en un descanso, volvemos a Pomodoro.
            currentMode = .pomodoro
        }
        
        // Reinicia la sesión con el nuevo modo y duración.
        resetCurrentSession()
    }
    
    /// Lógica que se ejecuta cuando el temporizador llega a cero.
    private func sessionDidFinish() {
        let wasRunning = isRunning
        isRunning = false
        timer?.cancel()
        playHapticFeedback(style: .success)
        AudioServicesPlaySystemSound(1005) // Sonido de finalización de sistema.

        if currentMode == .pomodoro {
            recordPomodoroCompletion(duration: self.pomodoroDuration)
            pomodoroSessionCount += 1
            currentMode = (pomodoroSessionCount % sessionsBeforeLongBreak == 0) ? .longBreak : .shortBreak
        } else {
            totalBreaksTaken += 1
            if pomodoroSessionCount >= sessionsBeforeLongBreak {
                pomodoroSessionCount = 0 // Reinicia el ciclo de pomodoros.
                showCongratulationsView()
            }
            currentMode = .pomodoro
        }
        
        timeLeft = currentModeDuration
        updateSharedWidgetData()
        
        // Si el modo continuo está activado, la siguiente sesión empieza automáticamente.
        if isContinuousModeEnabled && wasRunning {
            updateLiveActivityState(isPaused: false) // Actualiza el modo en la Live Activity
            startTimer()
        } else {
            // Si no, la Live Activity termina.
            endLiveActivity()
        }
    }
    
    /// Muestra una vista de felicitación y la oculta tras unos segundos.
    private func showCongratulationsView() {
        showCongratulations = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.showCongratulations = false
        }
    }
    
    /// Cambia entre el reloj digital y analógico.
    func toggleClockView() {
        playHapticFeedback(style: .light)
        clockViewType = (clockViewType == .digital) ? .analog : .digital
    }
    
    // MARK: - Gestión de Live Activities (CORREGIDO)
    
    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, currentActivity == nil else { return }
        
        let attributes = PomusActivityAttributes()
        let endDate = Date().addingTimeInterval(timeLeft)
        
        let state = PomusActivityAttributes.ContentState(
            timerRange: Date()...endDate,
            modeName: currentMode.modeName,
            modeColorName: currentMode.color.description, // Enviamos el nombre del color
            sessionCount: self.pomodoroSessionCount,
            totalSessions: self.sessionsBeforeLongBreak,
            sessionState: .running // Estado explícito: corriendo
        )
        
        do {
            let activity = try Activity<PomusActivityAttributes>.request(attributes: attributes, content: .init(state: state, staleDate: endDate))
            self.currentActivity = activity
        } catch {
            print("Error al solicitar Live Activity: \(error.localizedDescription)")
        }
    }
    
    /// Actualiza el estado de una Live Activity existente (ej: al pausar/reanudar).
    func updateLiveActivityState(isPaused: Bool) {
        Task {
            let newEndDate = Date().addingTimeInterval(timeLeft)
            let newState = PomusActivityAttributes.ContentState(
                timerRange: Date()...newEndDate,
                modeName: currentMode.modeName,
                modeColorName: currentMode.color.description,
                sessionCount: self.pomodoroSessionCount,
                totalSessions: self.sessionsBeforeLongBreak,
                sessionState: isPaused ? .paused : .running // El estado clave que se envía
            )
            await currentActivity?.update(using: newState)
        }
    }
    
    /// Termina la Live Activity de forma inmediata.
    func endLiveActivity() {
        Task {
            await currentActivity?.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
        }
    }

    // MARK: - Gestión de Tareas
    
    func addTask(text: String) {
        pendingTasks.append(PomodoroTask(text: text))
    }
    
    func updateTask(task: PomodoroTask, newText: String) {
        if let index = pendingTasks.firstIndex(where: { $0.id == task.id }) {
            pendingTasks[index].text = newText
        } else if let index = completedTasks.firstIndex(where: { $0.id == task.id }) {
            completedTasks[index].text = newText
        }
    }
    
    func toggleTaskCompletion(task: PomodoroTask) {
        playHapticFeedback(style: .light)
        if let index = pendingTasks.firstIndex(where: { $0.id == task.id }) {
            var taskToMove = pendingTasks.remove(at: index)
            taskToMove.isCompleted = true
            completedTasks.insert(taskToMove, at: 0)
            totalTasksCompleted += 1
        } else if let index = completedTasks.firstIndex(where: { $0.id == task.id }) {
            var taskToMove = completedTasks.remove(at: index)
            taskToMove.isCompleted = false
            pendingTasks.append(taskToMove)
            if totalTasksCompleted > 0 { totalTasksCompleted -= 1 }
        }
    }
    
    func deleteTask(at offsets: IndexSet, in_completedList: Bool) {
        if in_completedList {
            completedTasks.remove(atOffsets: offsets)
        } else {
            pendingTasks.remove(atOffsets: offsets)
        }
    }
    
    func movePendingTask(from source: IndexSet, to destination: Int) {
        pendingTasks.move(fromOffsets: source, toOffset: destination)
    }
    
    func clearCompletedTasks() {
        playHapticFeedback(style: .heavy)
        completedTasks.removeAll()
    }

    // MARK: - Gestión de Ajustes
    
    func restoreDefaultSettings() {
        playHapticFeedback(style: .heavy)
        pomodoroDuration = 25 * 60
        shortBreakDuration = 5 * 60
        longBreakDuration = 15 * 60
        sessionsBeforeLongBreak = 4
        isContinuousModeEnabled = false
        if !isRunning { timeLeft = currentModeDuration }
    }
    
    func resetPomodoroCycle() {
        playHapticFeedback(style: .medium)
        pomodoroSessionCount = 0
    }
    
    // MARK: - Gestión de Estadísticas
    
    private func recordPomodoroCompletion(duration: TimeInterval) {
        let key = Date.keyFormatter.string(from: Date())
        focusTimeByDay[key, default: 0] += duration
        totalPomodorosCompleted += 1
    }
    
    var weeklyFocusStats: [FocusStat] {
        let calendar = Calendar.current
        let today = Date()
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = Date.keyFormatter.string(from: date)
            let dayAbbrev = Date.dayFormatter.string(from: date).capitalized
            let duration = focusTimeByDay[key] ?? 0
            return FocusStat(day: dayAbbrev, duration: duration)
        }
    }
    
    var totalFocusTimeFormatted: String {
        let totalSeconds = focusTimeByDay.values.reduce(0, +)
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    // MARK: - Sonidos de Ambiente (Premium Feature)
    
    func playSound(name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Bucle infinito
            audioPlayer?.play()
        } catch {
            print("Error al reproducir el sonido: \(error.localizedDescription)")
        }
    }
    
    func stopSound() {
        audioPlayer?.stop()
    }
    
    // MARK: - Feedback Háptico (Premium Feature)
    
    private func playHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    // MARK: - Background Handling & Notificaciones
    
    private func appWillResignActive() {
        // Si la app va a segundo plano y el temporizador está corriendo, guardamos el estado.
        if isRunning { saveLastState() } else { UserDefaults.standard.removeObject(forKey: lastStateKey) }
    }
    
    private func appWillEnterForeground() {
        recalculateTimeLeftOnLaunch()
    }
    
    private func recalculateTimeLeftOnLaunch() {
        guard let lastState = loadLastState(), lastState.isRunning else { return }
        
        let timePassed = Date().timeIntervalSince(lastState.timestamp)
        let newTimeLeft = lastState.timeLeft - timePassed
        
        if newTimeLeft > 0 {
            self.timeLeft = newTimeLeft
            self.currentMode = lastState.mode
            startTimer() // Reanuda el temporizador
        } else {
            // Si el tiempo ya se acabó mientras la app estaba cerrada.
            self.timeLeft = 0
            self.currentMode = lastState.mode
            sessionDidFinish()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func scheduleLocalNotification(at date: Date) {
        cancelLocalNotification()
        let content = UNMutableNotificationContent()
        content.title = "Time's up!"
        content.body = currentMode == .pomodoro ? "Great work! Time for a well-deserved break." : "Break is over. Time to focus!"
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date), repeats: false)
        let request = UNNotificationRequest(identifier: "pomodoroEnd", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func cancelLocalNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pomodoroEnd"])
    }
    
    // MARK: - Sincronización con Widget (CORREGIDO)
    
    private func updateSharedWidgetData() {
        // Usamos el App Group ID definido.
        if let sharedDefaults = UserDefaults(suiteName: "group.com.marioquezada.Pomus") {
            let startDate = Date()
            let endDate = startDate.addingTimeInterval(timeLeft)
            
            sharedDefaults.set(startDate.timeIntervalSince1970, forKey: "startTS")
            sharedDefaults.set(endDate.timeIntervalSince1970, forKey: "endTS")
            sharedDefaults.set(isRunning, forKey: "isRunning") // El estado clave para el widget
            sharedDefaults.set(currentMode.modeName, forKey: "mode")
            sharedDefaults.set(currentMode.color.description, forKey: "modeColorName")
            sharedDefaults.set(pomodoroSessionCount, forKey: "sessionCount")
            sharedDefaults.set(sessionsBeforeLongBreak, forKey: "totalSessions")
            sharedDefaults.set(currentModeDuration, forKey: "modeDuration")
        }
    }

    // MARK: - Persistencia de Datos (UserDefaults)
    
    private func saveTasks() {
        let allTasks = pendingTasks + completedTasks
        if let data = try? JSONEncoder().encode(allTasks) {
            UserDefaults.standard.set(data, forKey: tasksKey)
        }
    }
    
    private func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: tasksKey),
              let allTasks = try? JSONDecoder().decode([PomodoroTask].self, from: data) else { return }
        pendingTasks = allTasks.filter { !$0.isCompleted }
        completedTasks = allTasks.filter { $0.isCompleted }
    }
    
    private func saveStats(timeByDay: [String: TimeInterval], totalPomodoros: Int, totalTasks: Int, totalBreaks: Int) {
        let stats: [String: Any] = ["focusTimeByDay": timeByDay, "totalPomodoros": totalPomodoros, "totalTasks": totalTasks, "totalBreaks": totalBreaks]
        if let data = try? JSONSerialization.data(withJSONObject: stats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }
    
    private func loadStats() {
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        focusTimeByDay = json["focusTimeByDay"] as? [String: TimeInterval] ?? [:]
        totalPomodorosCompleted = json["totalPomodoros"] as? Int ?? 0
        totalTasksCompleted = json["totalTasks"] as? Int ?? 0
        totalBreaksTaken = json["totalBreaks"] as? Int ?? 0
    }
    
    private func saveSettings(pomodoro: TimeInterval, short: TimeInterval, long: TimeInterval, sessions: Int, isContinuous: Bool) {
        let settings: [String: Any] = [
            "pomodoroDuration": pomodoro, "shortBreakDuration": short, "longBreakDuration": long,
            "sessionsBeforeLongBreak": sessions, "isContinuousModeEnabled": isContinuous
        ]
        UserDefaults.standard.set(settings, forKey: settingsKey)
    }
    
    private func loadSettings() {
        let settings = UserDefaults.standard.dictionary(forKey: settingsKey)
        pomodoroDuration = settings?["pomodoroDuration"] as? TimeInterval ?? 25 * 60
        shortBreakDuration = settings?["shortBreakDuration"] as? TimeInterval ?? 5 * 60
        longBreakDuration = settings?["longBreakDuration"] as? TimeInterval ?? 15 * 60
        sessionsBeforeLongBreak = settings?["sessionsBeforeLongBreak"] as? Int ?? 4
        isContinuousModeEnabled = settings?["isContinuousModeEnabled"] as? Bool ?? false
        
        // Si no hay un temporizador corriendo, actualiza timeLeft a la duración del modo actual.
        if !isRunning {
            timeLeft = currentModeDuration
        }
    }
    
    private func saveLastState() {
        let state = LastAppState(isRunning: isRunning, timeLeft: timeLeft, mode: currentMode, timestamp: Date())
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: lastStateKey)
        }
    }
    
    private func loadLastState() -> LastAppState? {
        guard let data = UserDefaults.standard.data(forKey: lastStateKey),
              let state = try? JSONDecoder().decode(LastAppState.self, from: data) else { return nil }
        return state
    }
    
    /// Estructura para guardar el estado de la app al ir a segundo plano.
    struct LastAppState: Codable {
        let isRunning: Bool
        let timeLeft: TimeInterval
        let mode: Mode
        let timestamp: Date
    }
}

// MARK: - Estructuras de Datos Auxiliares

/// Representa un punto de datos para el gráfico de estadísticas.
struct FocusStat: Identifiable {
    let id = UUID()
    let day: String
    let duration: TimeInterval
}

// MARK: - Extensiones de Utilidad

extension Date {
    static let keyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    
    static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "E"
        return df
    }()
}
