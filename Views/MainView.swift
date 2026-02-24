import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = PomodoroViewModel()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false

    @State private var showTasks = false
    @State private var showStats = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            AppBackground(mode: viewModel.currentMode)

            VStack(spacing: 20) {
                header
                Spacer(minLength: 8)

                ClockView(viewModel: viewModel, diameter: 300)
                    .onTapGesture(count: 2, perform: viewModel.skipToNextMode)
                    .onLongPressGesture(perform: viewModel.toggleClockView)

                SessionProgressView(viewModel: viewModel)
                quickHints

                Spacer(minLength: 8)
                controls
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
        }
        .sheet(isPresented: $showTasks) { TasksView(viewModel: viewModel) }
        .sheet(isPresented: $showStats) { StatsView(viewModel: viewModel) }
        .sheet(isPresented: $showSettings) { SettingsView(viewModel: viewModel) }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView {
                hasCompletedOnboarding = true
                showingOnboarding = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            if !hasCompletedOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingOnboarding = true
                }
            }
        }
    }

    private var header: some View {
        HStack {
            iconButton(systemName: "chart.line.uptrend.xyaxis", action: { showStats.toggle() })
            Spacer()
            VStack(spacing: 4) {
                Text("Pomus")
                    .font(.title3.weight(.semibold))
                Text(modeTitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            iconButton(systemName: "slider.horizontal.3", action: { showSettings.toggle() })
        }
    }

    private var controls: some View {
        HStack(spacing: 18) {
            iconButton(systemName: "arrow.counterclockwise", size: 56, action: viewModel.resetCurrentSession)

            Button(action: viewModel.startPauseTimer) {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .frame(width: 74, height: 74)
                    .background(.white.opacity(0.2), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            }

            iconButton(systemName: "checklist", size: 56, action: { showTasks.toggle() })
        }
    }

    private var quickHints: some View {
        VStack(spacing: 6) {
            Text("Doble toque para saltar · Mantén presionado para cambiar reloj")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))

            if viewModel.showCongratulations {
                Text("¡Ciclo completo! Excelente trabajo ✨")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.18), in: Capsule())
            }
        }
        .multilineTextAlignment(.center)
        .animation(.easeInOut, value: viewModel.showCongratulations)
    }

    private func iconButton(systemName: String, size: CGFloat = 44, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: size, height: size)
                .background(.white.opacity(0.16), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
        }
    }

    private var modeTitle: String {
        switch viewModel.currentMode {
        case .pomodoro: return "Modo enfoque"
        case .shortBreak: return "Descanso corto"
        case .longBreak: return "Descanso largo"
        }
    }
}

private struct SessionProgressView: View {
    @ObservedObject var viewModel: PomodoroViewModel

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<viewModel.sessionsBeforeLongBreak, id: \.self) { index in
                Capsule()
                    .fill(index < viewModel.pomodoroSessionCount ? .white : .white.opacity(0.3))
                    .frame(width: index == viewModel.pomodoroSessionCount ? 28 : 14, height: 8)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.pomodoroSessionCount)
    }
}

private struct AppBackground: View {
    let mode: PomodoroViewModel.Mode

    var body: some View {
        LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .overlay {
                Circle()
                    .fill(.white.opacity(0.12))
                    .blur(radius: 100)
                    .scaleEffect(1.8)
                    .offset(x: -120, y: -280)
            }
            .animation(.easeInOut(duration: 0.35), value: mode)
    }

    private var palette: [Color] {
        switch mode {
        case .pomodoro: return [Color(red: 0.20, green: 0.25, blue: 0.40), Color(red: 0.12, green: 0.12, blue: 0.20)]
        case .shortBreak: return [Color(red: 0.12, green: 0.36, blue: 0.38), Color(red: 0.08, green: 0.18, blue: 0.22)]
        case .longBreak: return [Color(red: 0.14, green: 0.28, blue: 0.48), Color(red: 0.08, green: 0.15, blue: 0.27)]
        }
    }
}
