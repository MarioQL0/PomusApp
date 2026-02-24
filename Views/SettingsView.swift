import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    @State private var showingResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Duraciones") {
                    durationStepper(title: "Enfoque", value: $viewModel.pomodoroDuration, range: 5*60...4*60*60, step: 5*60)
                    durationStepper(title: "Descanso corto", value: $viewModel.shortBreakDuration, range: 60...30*60, step: 60)
                    durationStepper(title: "Descanso largo", value: $viewModel.longBreakDuration, range: 10*60...45*60, step: 5*60)
                }

                Section("Ciclo") {
                    Stepper("Sesiones antes de largo: \(viewModel.sessionsBeforeLongBreak)", value: $viewModel.sessionsBeforeLongBreak, in: 2...8)
                    Toggle("Modo continuo", isOn: $viewModel.isContinuousModeEnabled)
                    Button("Reiniciar ciclo actual", action: viewModel.resetPomodoroCycle)
                }

                Section {
                    Button("Restaurar ajustes", role: .destructive) {
                        showingResetAlert = true
                    }
                }
            }
            .navigationTitle("Ajustes")
            .alert("¿Restaurar valores por defecto?", isPresented: $showingResetAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Restaurar", role: .destructive, action: viewModel.restoreDefaultSettings)
            }
        }
    }

    private func durationStepper(title: String, value: Binding<TimeInterval>, range: ClosedRange<TimeInterval>, step: TimeInterval) -> some View {
        Stepper(value: value, in: range, step: step) {
            Text("\(title): \(Int(value.wrappedValue / 60)) min")
        }
    }
}
