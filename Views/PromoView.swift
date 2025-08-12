//
//  PromoView.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 13/07/25.
//

import SwiftUI
import Combine

// ViewModel simplificado y autocontenido solo para esta vista.
@MainActor
class PromoViewModel: ObservableObject {
    @Published var timeLeftString = "25:00"
    @Published var progress = 0.0
    @Published var currentModeName = "FOCUS"
    @Published var currentModeColor = Color(red: 214/255, green: 72/255, blue: 62/255)
    @Published var pomodoroSessionCount = 0
    @Published var isRunning = false

    private var cancellable: AnyCancellable?

    func startFullCycleTimelapse() {
        guard !isRunning else { return }
        isRunning = true
        
        // Inicia el ciclo con la sesión de enfoque
        runSession(duration: 25 * 60, inRealSeconds: 5.0, modeName: "FOCUS", color: Color(red: 214/255, green: 72/255, blue: 62/255)) {
            // Al completar el enfoque...
            self.pomodoroSessionCount = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Inicia la sesión de descanso
                self.runSession(duration: 5 * 60, inRealSeconds: 3.0, modeName: "BREAK", color: .green) {
                    // Al completar el descanso, resetea todo
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.reset()
                    }
                }
            }
        }
    }
    
    // Lógica de temporizador usando un método más clásico de Combine
    private func runSession(duration: TimeInterval, inRealSeconds: TimeInterval, color: Color, modeName: String, completion: @escaping () -> Void) {
        self.currentModeName = modeName
        self.currentModeColor = color
        self.timeLeftString = formatTime(duration)
        self.progress = 0.0
        
        let updatesPerSecond = 30.0
        let interval = 1.0 / updatesPerSecond
        let totalUpdates = Int(inRealSeconds * updatesPerSecond)
        var updatesDone = 0

        cancellable = Timer.publish(every: interval, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self = self, updatesDone < totalUpdates else {
                    self?.cancellable?.cancel()
                    completion()
                    return
                }
                
                updatesDone += 1
                
                let totalProgress = Double(updatesDone) / Double(totalUpdates)
                let newTimeLeft = duration * (1.0 - totalProgress)
                
                self.progress = totalProgress
                self.timeLeftString = self.formatTime(newTimeLeft)
                
                if updatesDone == totalUpdates {
                    self.timeLeftString = "00:00"
                    self.cancellable?.cancel()
                    completion()
                }
            }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func reset() {
        isRunning = false
        pomodoroSessionCount = 0
        progress = 0.0
        currentModeName = "FOCUS"
        timeLeftString = "25:00"
        currentModeColor = Color(red: 214/255, green: 72/255, blue: 62/255)
    }
}

// MARK: - Vista de Promo
struct PromoView: View {
    @StateObject private var viewModel = PromoViewModel()
    
    var body: some View {
        ZStack {
            viewModel.currentModeColor
                .ignoresSafeArea()
                .animation(.easeInOut, value: viewModel.currentModeColor)
            
            VStack {
                Spacer()
                
                // Reloj (Clon visual de ClockView)
                ZStack {
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 15)
                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: viewModel.progress)
                    VStack {
                        Text(viewModel.timeLeftString)
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                        Text(viewModel.currentModeName)
                            .font(.headline).textCase(.uppercase).kerning(2)
                    }
                }
                .frame(width: 280, height: 280)
                .foregroundColor(.white)
                
                // Indicador de Ciclo (Clon visual)
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < viewModel.pomodoroSessionCount ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
                .animation(.spring(), value: viewModel.pomodoroSessionCount)
                .padding(.top)

                Spacer()
                
                // Botón de Play para iniciar la simulación
                Button(action: {
                    viewModel.startFullCycleTimelapse()
                }) {
                    Image(systemName: viewModel.isRunning ? "timelapse" : "play.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.white.opacity(0.3))
                        .clipShape(Circle())
                }
                .disabled(viewModel.isRunning)
                .opacity(viewModel.isRunning ? 0.5 : 1.0)
                .padding(.bottom, 50)
            }
        }
    }
}


#Preview {
    PromoView()
}
