//
//  PomusWidget.swift
//  PomusWidget
//
//  Created by Luis Mario Quezada Elizondo on 07/08/25.
//
//  Corregido para eliminar la redeclaración de PomusWidgetBundle
//  y manejar correctamente el estado de pausa.
//

import WidgetKit
import SwiftUI

private let appGroupID = "group.com.marioquezada.Pomus"

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
    
    var body: some View {
        ZStack {
            CircularProgressView(
                timerRange: entry.timerRange,
                color: Color(entry.modeColorName),
                isRunning: entry.isRunning,
                modeDuration: entry.modeDuration
            )
            .padding(6)

            VStack(spacing: 2) {
                Text(entry.mode)
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color(entry.modeColorName))
                
                Text(timerInterval: entry.timerRange, countsDown: true)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .contentTransition(.numericText())
                
                CycleIndicatorView(
                    sessionCount: entry.sessionCount,
                    totalSessions: entry.totalSessions,
                    color: .secondary
                )
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Configuration
// Se define el Widget individual aquí. El 'WidgetBundle' se encarga de agruparlo.
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
    let modeDuration: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: timerRange.lowerBound, by: 1.0)) { context in
            let progress = progress(for: context.date)
            
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: progress)
            }
        }
    }
    
    private func progress(for date: Date) -> Double {
        guard modeDuration > 0 else { return 0 }

        if isRunning {
            let timeElapsed = date.timeIntervalSince(timerRange.lowerBound)
            return min(max(timeElapsed / modeDuration, 0), 1)
        } else {
            let timeLeft = timerRange.upperBound.timeIntervalSince(timerRange.lowerBound)
            return 1.0 - (timeLeft / modeDuration)
        }
    }
}
