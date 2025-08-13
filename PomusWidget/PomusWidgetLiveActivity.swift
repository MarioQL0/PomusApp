//
//  PomusWidgetLiveActivity.swift
//  PomusWidget
//
//  Created by Luis Mario Quezada Elizondo on 07/08/25.
//
//  Versión definitiva. Se corrige el error de "priority" y se estabiliza
//  la declaración de la Dynamic Island para evitar crashes del compilador.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PomusWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomusActivityAttributes.self) { context in
            // MARK: Vista para la Pantalla de Bloqueo (Lock Screen)
            LockScreenView(context: context)
            
        } dynamicIsland: { context in
            // MARK: Vistas para la Isla Dinámica (Dynamic Island)
            DynamicIsland {
                // --- VISTA EXPANDIDA ---
                // Esta es la sección corregida.
                
                // Región Izquierda: Muestra el nombre del modo y un ícono.
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.modeName)
                            .font(.headline)
                    } icon: {
                        Image(systemName: context.state.sessionState == .running ? "timer" : "pause.fill")
                    }
                    .foregroundColor(Color(context.state.modeColorName))
                }
                
                // Región Derecha: Muestra el tiempo restante.
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.timerRange, countsDown: true)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .contentTransition(.numericText)
                        .foregroundColor(Color(context.state.modeColorName))
                }
                
                // Región Inferior: Muestra la barra de progreso y los ciclos.
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        GradientProgressBar(
                            timerRange: context.state.timerRange,
                            color: Color(context.state.modeColorName),
                            isPaused: context.state.sessionState == .paused
                        )
                        CycleIndicatorView(
                            sessionCount: context.state.sessionCount,
                            totalSessions: context.state.totalSessions,
                            color: .secondary
                        )
                    }
                    .padding(.top, 4)
                }
                
            } compactLeading: {
                // --- VISTAS COMPACTAS ---
                Image(systemName: context.state.sessionState == .running ? "timer" : "pause.fill")
                    .foregroundColor(Color(context.state.modeColorName))
                
            } compactTrailing: {
                Text(timerInterval: context.state.timerRange, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 50)
                    .contentTransition(.numericText)
                
            } minimal: {
                // --- VISTA MÍNIMA ---
                Image(systemName: "timer")
                    .foregroundColor(Color(context.state.modeColorName))
            }
            // Eliminamos la llamada a una vista intermedia que causaba la ambigüedad.
            // La estructura ahora es la estándar y más estable.
        }
    }
}

// MARK: - Vistas de Componentes (sin cambios)

private struct LockScreenView: View {
    let context: ActivityViewContext<PomusActivityAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(context.state.modeName)
                    .font(.headline.weight(.bold))
                    .foregroundColor(Color(context.state.modeColorName))
                Spacer()
                CycleIndicatorView(sessionCount: context.state.sessionCount, totalSessions: context.state.totalSessions, color: .secondary)
            }
            if context.state.sessionState == .running {
                runningView
            } else {
                pausedView
            }
            GradientProgressBar(timerRange: context.state.timerRange, color: Color(context.state.modeColorName), isPaused: context.state.sessionState == .paused)
        }
        .padding(16)
        .activityBackgroundTint(Color.black.opacity(0.2))
    }
    
    private var runningView: some View {
        HStack {
            Label("Remaining", systemImage: "timer").font(.caption.weight(.semibold)).foregroundColor(.secondary)
            Spacer()
            Text(timerInterval: context.state.timerRange, countsDown: true)
                .font(.largeTitle.weight(.semibold).monospacedDigit()).contentTransition(.numericText()).foregroundColor(.primary)
        }
    }
    
    private var pausedView: some View {
        HStack {
            Label("Paused", systemImage: "pause.fill").font(.caption.weight(.semibold)).foregroundColor(.gray)
            Spacer()
            Text(timerInterval: context.state.timerRange, countsDown: false)
                .font(.largeTitle.weight(.semibold).monospacedDigit()).foregroundColor(.gray)
        }
    }
}

private struct CycleIndicatorView: View {
    let sessionCount: Int; let totalSessions: Int; var color: Color
    var body: some View {
        HStack(spacing: 5) { ForEach(0..<totalSessions, id: \.self) { index in Circle().fill(index < sessionCount ? color : color.opacity(0.3)).frame(width: 8, height: 8) } }
    }
}

private struct GradientProgressBar: View {
    let timerRange: ClosedRange<Date>; let color: Color; let isPaused: Bool
    
    var body: some View {
        TimelineView(.periodic(from: timerRange.lowerBound, by: 1.0)) { context in
            let progress = progress(for: context.date)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.3))
                    Capsule().fill(color).frame(width: geometry.size.width * progress)
                        .animation(isPaused ? .none : .linear, value: progress)
                }
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }
    
    private func progress(for date: Date) -> Double {
        let totalDuration = timerRange.upperBound.timeIntervalSinceReferenceDate - timerRange.lowerBound.timeIntervalSinceReferenceDate
        guard totalDuration > 0 else { return isPaused ? 1 : 0 }
        
        if isPaused {
            let timeRemaining = timerRange.upperBound.timeIntervalSince(timerRange.lowerBound)
            return 1.0 - (timeRemaining / totalDuration)
        } else {
            let timeElapsed = date.timeIntervalSince(timerRange.lowerBound)
            return min(max(timeElapsed / totalDuration, 0), 1)
        }
    }
}
