//
//  TimelapseView.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 13/07/25.
//

import SwiftUI
import Combine

// MARK: - ViewModel para el Timelapse
// Un ViewModel simplificado que solo existe para esta vista de demostración.
@MainActor
class TimelapseViewModel: ObservableObject {
    @Published var timeLeftString = "25:00"
    @Published var progress = 0.0
    @Published var currentModeName = "FOCUS"
    @Published var currentModeColor = Color(red: 214/255, green: 72/255, blue: 62/255)
    @Published var pomodoroSessionCount = 0
    @Published var isRunning = false

    let sessionsBeforeLongBreak = 4
    
    /// Inicia la simulación completa del ciclo: Foco -> Descanso.
    func startFullCycleTimelapse() {
        guard !isRunning else { return }
        isRunning = true

        Task {
            // --- 1. Sesión de Enfoque ---
            await runSession(
                duration: 25 * 60,
                inRealSeconds: 5.0,
                modeName: "FOCUS",
                color: Color(red: 214/255, green: 72/255, blue: 62/255)
            )
            self.pomodoroSessionCount = 1
            
            // Pausa para que se note la transición en el video
            try? await Task.sleep(for: .seconds(1))

            // --- 2. Sesión de Descanso ---
            await runSession(
                duration: 5 * 60,
                inRealSeconds: 3.0,
                modeName: "BREAK",
                color: .green
            )
            
            // Reseteo final para poder grabar de nuevo si es necesario
            try? await Task.sleep(for: .seconds(1.5))
            self.reset()
        }
    }
    
    /// Corre una sesión individual en modo timelapse.
    private func runSession(duration: TimeInterval, inRealSeconds: TimeInterval, color: Color, modeName: String) async {
        self.currentModeName = modeName
        self.currentModeColor = color
        
        let updatesPerSecond = 30.0 // 30fps para una animación suave
        let totalUpdates = inRealSeconds * updatesPerSecond
        let timeDecrementPerUpdate = duration / totalUpdates
        let progressIncrementPerUpdate = 1.0 / totalUpdates
        let interval = 1.0 / updatesPerSecond
        
        var timeLeft = duration
        self.progress = 0.0
        
        let timerSequence = Timer.publish(every: interval, on: .main, in: .common).autoconnect()
        
        for await _ in timerSequence.values {
            guard timeLeft > 0 else { break }
            
            timeLeft -= timeDecrementPerUpdate
            self.progress += progressIncrementPerUpdate
            
            let minutes = Int(timeLeft) / 60
            let seconds = Int(timeLeft) % 60
            self.timeLeftString = String(format: "%02d:%02d", minutes, seconds)
        }
        
        self.timeLeftString = "00:00"
        self.progress = 1.0
    }
    
    private func reset() {
        self.isRunning = false
        self.pomodoroSessionCount = 0
        self.progress = 0
        self.currentModeName = "FOCUS"
        self.timeLeftString = "25:00"
        self.currentModeColor = Color(red: 214/255, green: 72/255, blue: 62/255)
    }
}


// MARK: - Vista de Timelapse
/// Una vista que imita a MainView, pero usa el TimelapseViewModel para grabar videos.
struct PromoTimelapseView: View {
    @StateObject private var viewModel = TimelapseViewModel()
    
    var body: some View {
        ZStack {
            viewModel.currentModeColor
                .ignoresSafeArea()
                .animation(.easeInOut, value: viewModel.currentModeColor)
            
            VStack {
                // Cabecera Falsa
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                    Spacer()
                    Text("Tempus").font(.headline.weight(.semibold))
                    Spacer()
                    Image(systemName: "gearshape.fill")
                }
                .font(.title2)
                .padding([.horizontal, .top])
                .opacity(0.5)
                
                Spacer()
                
                // Reloj de la demo
                demoClockView
                
                // Indicador de ciclo de la demo
                demoCycleIndicator
                    .padding(.top)
                
                Spacer()
                
                // Botones de control
                HStack(spacing: 25) {
                    // --- CORRECCIÓN ---
                    // Se envuelven las imágenes en botones vacíos para dar consistencia estructural
                    Button(action: {}) {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 60, height: 60)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
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
                    
                    Button(action: {}) {
                        Image(systemName: "list.bullet")
                            .frame(width: 60, height: 60)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    // --- FIN DE LA CORRECCIÓN ---
                }
                .font(.title2)
                .padding(.bottom)
                .opacity(viewModel.isRunning ? 0.5 : 1.0)
            }
            .foregroundColor(.white)
        }
    }
    
    /// Una imitación de ClockView para la demo.
    private var demoClockView: some View {
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
                    .font(.headline)
                    .textCase(.uppercase)
                    .kerning(2)
            }
        }
        .frame(width: 280, height: 280)
        .foregroundColor(.white)
    }
    
    /// Una imitación de CycleIndicatorView para la demo.
    private var demoCycleIndicator: some View {
        HStack(spacing: 12) {
            ForEach(0..<viewModel.sessionsBeforeLongBreak, id: \.self) { index in
                Circle()
                    .fill(index < viewModel.pomodoroSessionCount ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
        }
        .animation(.spring(), value: viewModel.pomodoroSessionCount)
    }
}

#Preview {
    PromoTimelapseView()
}
