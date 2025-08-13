//
//  PomusWidget.swift
//  PomusWidget
//
//  Created by Luis Mario Quezada Elizondo on 07/08/25.
//

import WidgetKit
import SwiftUI
import OSLog

private let appGroupID = "group.com.marioquezada.Pomus" // Shared App Group
private let logger = Logger(subsystem: "com.marioquezada.Pomus", category: "Widget")

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
        let policy: TimelineReloadPolicy
        if entry.timer.status == .paused || entry.timer.status == .idle {
            policy = .never
        } else if let end = entry.timer.endDate {
            policy = .after(end)
        } else {
            policy = .never
        }
        let timeline = Timeline(entries: [entry], policy: policy)
        logger.debug("Timeline generated with policy \(String(describing: policy))")
        completion(timeline)
    }

    private func readCurrentEntry() -> PomusEntry {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID),
              let data = sharedDefaults.data(forKey: "timerState"),
              let state = try? JSONDecoder().decode(PomusTimerState.self, from: data) else {
            return PomusEntry.placeholder
        }

        let entryDate: Date
        if state.status == .paused, let pause = state.pauseDate {
            entryDate = pause
        } else {
            entryDate = Date()
        }

        return PomusEntry(date: entryDate, timer: state)
    }
}

// MARK: - Entry (El "Molde" de Datos para el Widget)
struct PomusEntry: TimelineEntry {
    let date: Date
    let timer: PomusTimerState

    static var placeholder: PomusEntry {
        let state = PomusTimerState(status: .focus,
                                    startDate: Date(),
                                    endDate: Date().addingTimeInterval(25*60),
                                    pauseDate: nil,
                                    accumulatedPause: 0,
                                    sessionCount: 0,
                                    totalSessions: 4,
                                    modeName: "Focus",
                                    modeColorName: "FocusColor")
        return PomusEntry(date: .now, timer: state)
    }
}

// MARK: - View (El Diseño Premium del Widget)
struct PomusWidgetEntryView : View {
    var entry: PomusEntry
    let color: Color
    @Environment(\.widgetFamily) private var family

    init(entry: PomusEntry) {
        self.entry = entry
        self.color = Color(entry.timer.modeColorName)
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
            CircularProgressView(timer: entry.timer, color: color)
                .frame(width: 120, height: 120)

            VStack(spacing: 4) {
                Text(entry.timer.modeName)
                    .font(.caption.weight(.bold))
                    .foregroundColor(color)

                if let start = entry.timer.startDate, let end = entry.timer.endDate {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .contentTransition(.numericText())
                }

                CycleIndicatorView(sessionCount: entry.timer.sessionCount,
                                   totalSessions: entry.timer.totalSessions,
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
            CircularProgressView(timer: entry.timer, color: color)
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.timer.modeName)
                    .font(.headline.weight(.bold))
                    .foregroundColor(color)

                if let start = entry.timer.startDate, let end = entry.timer.endDate {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .contentTransition(.numericText())
                }

                GradientProgressBar(timer: entry.timer, color: color)
                    .frame(height: 8)

                CycleIndicatorView(sessionCount: entry.timer.sessionCount,
                                   totalSessions: entry.timer.totalSessions,
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
                Text(entry.timer.modeName)
                    .font(.title2.weight(.bold))
                    .foregroundColor(color)
                Spacer()
                CycleIndicatorView(sessionCount: entry.timer.sessionCount,
                                   totalSessions: entry.timer.totalSessions,
                                   color: .secondary)
            }

            if let start = entry.timer.startDate, let end = entry.timer.endDate {
                Text(timerInterval: start...end, countsDown: true)
                    .font(.system(size: 44, weight: .semibold, design: .monospaced))
                    .contentTransition(.numericText())
                    .foregroundColor(.primary)
            }

            GradientProgressBar(timer: entry.timer, color: color)
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
    let timer: PomusTimerState
    let color: Color

    var body: some View {
        TimelineView(.animation(paused: timer.status == .paused || !timer.isRunning)) { context in
            let progress = timer.fractionCompleted(at: context.date)

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
}

// Linear gradient progress bar used in medium and large widgets
private struct GradientProgressBar: View {
    let timer: PomusTimerState
    let color: Color

    var body: some View {
        TimelineView(.animation(paused: timer.status == .paused || !timer.isRunning)) { context in
            let progress = timer.fractionCompleted(at: context.date)
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
}
