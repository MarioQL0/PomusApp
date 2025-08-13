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
        
        return PomusEntry(
            date: Date(),
            timerRange: startDate...endDate,
            isRunning: sharedDefaults.bool(forKey: "isRunning"),
            mode: sharedDefaults.string(forKey: "mode") ?? "Focus",
            modeColorName: sharedDefaults.string(forKey: "modeColorName") ?? "FocusColor",
            sessionCount: sharedDefaults.integer(forKey: "sessionCount"),
            totalSessions: sharedDefaults.integer(forKey: "totalSessions")
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
    
    static var placeholder: PomusEntry {
        PomusEntry(date: .now, timerRange: .now...Date().addingTimeInterval(25*60), isRunning: false, mode: "Focus", modeColorName: "FocusColor", sessionCount: 0, totalSessions: 4)
    }
}

// MARK: - View (El Diseño Premium del Widget)
struct PomusWidgetEntryView : View {
    var entry: PomusEntry
    let color: Color
    @Environment(\.widgetFamily) private var family

    init(entry: PomusEntry) {
        self.entry = entry
        self.color = Color(entry.modeColorName)
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumView
        case .systemLarge: largeView
        default: smallView
        }
    }

    // Small widget layout
    private var smallView: some View {
        ZStack {
            CircularProgressView(timerRange: entry.timerRange, color: color, isRunning: entry.isRunning)

            VStack(spacing: 4) {
                Text(entry.mode)
                    .font(.caption.weight(.bold))
                    .foregroundColor(color)

                Text(timerInterval: entry.timerRange, countsDown: true)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())

                CycleIndicatorView(sessionCount: entry.sessionCount,
                                   totalSessions: entry.totalSessions,
                                   color: .secondary)
            }
            .padding(.bottom, 4)
        }
        .padding(8)
        .containerBackground(for: .widget) {}
    }

    // Medium widget layout
    private var mediumView: some View {
        HStack(spacing: 12) {
            CircularProgressView(timerRange: entry.timerRange, color: color, isRunning: entry.isRunning)
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.mode)
                    .font(.headline.weight(.bold))
                    .foregroundColor(color)

                Text(timerInterval: entry.timerRange, countsDown: true)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())

                GradientProgressBar(timerRange: entry.timerRange, color: color)
                    .frame(height: 8)

                CycleIndicatorView(sessionCount: entry.sessionCount,
                                   totalSessions: entry.totalSessions,
                                   color: .secondary)
            }
        }
        .padding()
        .containerBackground(for: .widget) {}
    }

    // Large widget layout
    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry.mode)
                    .font(.title2.weight(.bold))
                    .foregroundColor(color)
                Spacer()
                CycleIndicatorView(sessionCount: entry.sessionCount,
                                   totalSessions: entry.totalSessions,
                                   color: .secondary)
            }

            Text(timerInterval: entry.timerRange, countsDown: true)
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
                .contentTransition(.numericText())
                .foregroundColor(.primary)

            GradientProgressBar(timerRange: entry.timerRange, color: color)
                .frame(height: 12)
        }
        .padding()
        .containerBackground(for: .widget) {}
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
    
    var body: some View {
        TimelineView(.animation(paused: !isRunning)) { context in
            let progress = progress(for: context.date)
            
            Circle().stroke(color.opacity(0.3), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [color, color.opacity(0.7)], center: .center),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .padding(4)
    }
    
    private func progress(for date: Date) -> Double {
        let totalDuration = timerRange.upperBound.timeIntervalSince(timerRange.lowerBound)
        guard totalDuration > 0 else { return isRunning ? 1 : 0 }
        let timeElapsed = date.timeIntervalSince(timerRange.lowerBound)
        return min(max(timeElapsed / totalDuration, 0), 1)
    }
}

// Linear gradient progress bar used in medium and large widgets
private struct GradientProgressBar: View {
    let timerRange: ClosedRange<Date>
    let color: Color

    var body: some View {
        TimelineView(.animation) { context in
            let progress = progress(for: context.date)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.3))
                    Capsule()
                        .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * progress)
                }
            }
        }
        .clipShape(Capsule())
    }

    private func progress(for date: Date) -> Double {
        let totalDuration = timerRange.upperBound.timeIntervalSince(timerRange.lowerBound)
        guard totalDuration > 0 else { return 0 }
        let timeElapsed = date.timeIntervalSince(timerRange.lowerBound)
        return min(max(timeElapsed / totalDuration, 0), 1)
    }
}
