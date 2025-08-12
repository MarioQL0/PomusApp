//
//  ClockView.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 11/07/25.
//

import SwiftUI

/// A view that renders the main clock, now receiving its size from the parent.
struct ClockView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: PomodoroViewModel
    
    /// The diameter of the clock, provided by the parent view.
    let diameter: CGFloat

    // MARK: - Dynamic Sizing Properties
    // These properties now calculate sizes relative to the provided diameter.
    
    private var lineWidth: CGFloat {
        return diameter * 0.055 // 5.5% of the diameter
    }
    
    private var timeFontSize: CGFloat {
        return diameter * 0.22 // 22% of the diameter
    }
    
    private var modeFont: Font {
        // Use a system font size that scales with the clock's diameter.
        return .system(size: diameter * 0.06, weight: .regular, design: .default)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Layer 1: Static background circle.
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: lineWidth)

            // Layer 2: Dynamic progress circle.
            Circle()
                .trim(from: 0, to: 1 - (viewModel.timeLeft / viewModel.currentModeDuration))
                .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: viewModel.timeLeft)
                .accessibilityHidden(true)

            // Layer 3: Clock content (digital or analog).
            if viewModel.clockViewType == .digital {
                VStack {
                    Text(formatTime(viewModel.timeLeft))
                        .font(.system(size: timeFontSize, weight: .bold, design: .rounded))
                    Text(modeText)
                        .font(modeFont)
                        .textCase(.uppercase)
                        .kerning(2)
                }
                .transition(.opacity.animation(.easeInOut))
            } else {
                AnalogClockView(
                    timeLeft: viewModel.timeLeft,
                    duration: viewModel.currentModeDuration,
                    diameter: diameter
                )
                .transition(.opacity.animation(.easeInOut))
            }
        }
        .frame(width: diameter, height: diameter)
        .foregroundColor(.white)
        .contentShape(Circle())
    }
    
    // MARK: - Helper Functions
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var modeText: String {
        switch viewModel.currentMode {
        case .pomodoro: return "FOCUS"
        case .shortBreak: return "BREAK"
        case .longBreak: return "LONG BREAK"
        }
    }
}

// MARK: - Analog Clock
/// A separate view for the analog clock, also scaled by diameter.
struct AnalogClockView: View {
    let timeLeft: TimeInterval
    let duration: TimeInterval
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.white)
                .frame(width: diameter * 0.015, height: diameter * 0.28)
                .offset(y: -(diameter * 0.14))
                .rotationEffect(.degrees(progressDegrees))

            Capsule()
                .fill(Color.red)
                .frame(width: diameter * 0.007, height: diameter * 0.35)
                .offset(y: -(diameter * 0.175))
                .rotationEffect(.degrees(secondsDegrees))

            Circle()
                .fill(Color.white)
                .frame(width: diameter * 0.05, height: diameter * 0.05)
        }
    }
    
    private var progressDegrees: Double {
        let progress = duration > 0 ? 1 - (timeLeft / duration) : 0
        return progress * 360
    }
    
    private var secondsDegrees: Double {
        let seconds = timeLeft.truncatingRemainder(dividingBy: 60)
        return (60 - seconds) * 6
    }
}


// MARK: - Preview
#Preview("Clock View") {
    ZStack {
        Color.blue.ignoresSafeArea()
        ClockView(viewModel: PomodoroViewModel(), diameter: 300)
    }
}
