//
//  PomusWidget.swift
//  PomusWidget
//
//  Created by Luis Mario Quezada Elizondo on 07/08/25.
//

import WidgetKit
import SwiftUI

private let appGroupID = "group.com.marioquezada.Pomus" // El mismo ID

// MARK: - Provider (Lógica de Datos del Widget)
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PomusEntry {
        PomusEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (PomusEntry) -> ()) {
        completion(readCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PomusEntry>) -> ()) {
        let entry = readCurrentEntry()
        let timeline = Timeline(entries: [entry], policy: .after(entry.timerRange.upperBound))
        completion(timeline)
    }

    private func readCurrentEntry() -> PomusEntry {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return PomusEntry.placeholder
        }
        
        let startDate = Date(timeIntervalSince1970: sharedDefaults.double(forKey: "startTS"))
        let endDate = Date(timeIntervalSince1970: sharedDefaults.double(forKey: "endTS"))
        let modeDuration = sharedDefaults.double(forKey: "modeDuration") > 0 ? sharedDefaults.double(forKey: "modeDuration") : 25 * 60

        
        return PomusEntry(
            date: Date(),
            timerRange: startDate...endDate,
            isRunning: sharedDefaults.bool(forKey: "isRunning"),
            mode: sharedDefaults.string(forKey: "mode") ?? "Focus",
            modeColorName: sharedDefaults.string(forKey: "modeColorName") ?? "FocusColor",
            sessionCount: sharedDefaults.integer(forKey: "sessionCount"),
            totalSessions: sharedDefaults.integer(forKey: "totalSessions"),
            modeDuration: modeDuration

        )
    }
}

// MARK: - Entry (El "Molde" de Datos para el Widget)
struct PomusEntry: TimelineEntry {
    let date: Date
    let timerRange: ClosedRange<Date>
    let isRunning: Bool
    let mode: String
    let modeColorName: String
    let sessionCount: Int
    let totalSessions: Int
    let modeDuration: TimeInterval

    
    static var placeholder: PomusEntry {
        PomusEntry(
            date: .now,
            timerRange: .now...Date().addingTimeInterval(25*60),
            isRunning: false,
            mode: "Focus",
            modeColorName: "FocusColor",
            sessionCount: 0,
            totalSessions: 4,
            modeDuration: 25 * 60
        )
    }
}

// MARK: - View (El Diseño Premium del Widget)
struct PomusWidgetEntryView : View {
    var entry: PomusEntry
    
    // Vista principal del widget
    var body: some View {
        ZStack {
            // Fondo: círculo de progreso, comparte el mismo centro que el contenido
            CircularProgressView(
                timerRange: entry.timerRange,
                color: Color(entry.modeColorName),
                isRunning: entry.isRunning,
                modeDuration: entry.modeDuration
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(6)

            // Contenido del widget
            VStack(spacing: 0) {
                // El texto del modo (Focus, Break)
                VStack {
                    Text(entry.mode)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Color(entry.modeColorName))
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // El tiempo restante
                Text(timerInterval: entry.timerRange, countsDown: true)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .contentTransition(.numericText())
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .center)

                // El indicador de ciclos completados
                CycleIndicatorView(
                    sessionCount: entry.sessionCount,
                    totalSessions: entry.totalSessions,
                    color: .secondary
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        // Mantén el fondo del widget por defecto del sistema
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Configuration
struct PomusWidget: Widget {
    let kind: String = "PomusWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PomusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pomus Timer")
        .description("Track your current session on your Home Screen.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Componentes de Vista Locales
private struct CycleIndicatorView: View {
    let sessionCount: Int
    let totalSessions: Int
    var color: Color
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSessions, id: \.self) { index in
                Circle().fill(color.opacity(index < sessionCount ? 1.0 : 0.25)).frame(width: 6, height: 6)
            }
        }
    }
}

private struct CircularProgressView: View {
    let timerRange: ClosedRange<Date>
    let color: Color
    let isRunning: Bool
    let modeDuration: TimeInterval // <-- Recibe la duración total

    var body: some View {
        TimelineView(.periodic(from: timerRange.lowerBound, by: 1.0)) { context in
            // Usa la nueva función `progress` que ahora siempre funciona
            let progress = progress(for: context.date)
            
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(6)
    }
    
    // Función de cálculo corregida
    private func progress(for date: Date) -> Double {
        // Si está corriendo, calcula el progreso basado en el tiempo transcurrido
        if isRunning {
            let timeElapsed = date.timeIntervalSince(timerRange.lowerBound)
            guard modeDuration > 0 else { return 0 }
            return min(max(timeElapsed / modeDuration, 0), 1)
        } else {
            // Si está en pausa, calcula el progreso basado en el tiempo restante
            let timeLeft = timerRange.upperBound.timeIntervalSince(timerRange.lowerBound)
            guard modeDuration > 0 else { return 0 }
            return 1.0 - (timeLeft / modeDuration)
        }
    }
}
