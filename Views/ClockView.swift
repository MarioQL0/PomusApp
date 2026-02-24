import SwiftUI

struct ClockView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    let diameter: CGFloat

    private var progress: Double {
        let duration = viewModel.currentModeDuration
        guard duration > 0 else { return 0 }
        return 1 - (viewModel.timeLeft / duration)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.08))
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [.white.opacity(0.9), .white.opacity(0.3)], center: .center),
                    style: StrokeStyle(lineWidth: diameter * 0.06, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(diameter * 0.06)
                .animation(.linear(duration: 0.5), value: viewModel.timeLeft)

            Group {
                if viewModel.clockViewType == .digital {
                    VStack(spacing: 8) {
                        Text(formatTime(viewModel.timeLeft))
                            .font(.system(size: diameter * 0.2, weight: .bold, design: .rounded))
                        Text(modeText)
                            .font(.system(size: diameter * 0.06, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                } else {
                    AnalogClockView(timeLeft: viewModel.timeLeft, duration: viewModel.currentModeDuration, diameter: diameter)
                }
            }
            .transition(.opacity)
        }
        .frame(width: diameter, height: diameter)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var modeText: String {
        switch viewModel.currentMode {
        case .pomodoro: return "ENFOQUE"
        case .shortBreak: return "DESCANSO"
        case .longBreak: return "DESCANSO LARGO"
        }
    }
}

struct AnalogClockView: View {
    let timeLeft: TimeInterval
    let duration: TimeInterval
    let diameter: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { tick in
                Capsule()
                    .fill(.white.opacity(0.35))
                    .frame(width: 2, height: 10)
                    .offset(y: -(diameter * 0.36))
                    .rotationEffect(.degrees(Double(tick) * 30))
            }

            Capsule()
                .fill(.white)
                .frame(width: 4, height: diameter * 0.22)
                .offset(y: -(diameter * 0.11))
                .rotationEffect(.degrees(progressDegrees))

            Circle()
                .fill(.white)
                .frame(width: 12, height: 12)
        }
    }

    private var progressDegrees: Double {
        let progress = duration > 0 ? 1 - (timeLeft / duration) : 0
        return progress * 360
    }
}
