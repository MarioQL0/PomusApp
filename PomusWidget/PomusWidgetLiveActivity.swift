//
//  PomusWidgetLiveActivity.swift
//  PomusWidget
//
//  Created by Luis Mario Quezada Elizondo on 07/08/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PomusWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomusActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ExpandedIslandView(context: context)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundColor(Color(context.state.modeColorName))
            } compactTrailing: {
                Text(timerInterval: context.state.timerRange, countsDown: true).monospacedDigit().frame(width: 50)
            } minimal: {
                Image(systemName: "timer").foregroundColor(Color(context.state.modeColorName))
            }
        }
    }
}

// MARK: - Vistas de Componentes

private struct LockScreenView: View {
    let context: ActivityViewContext<PomusActivityAttributes>
    var body: some View {
        VStack {
            if context.state.sessionState == .finished {
                finishedView
            } else {
                runningView
            }
        }
        .padding(16)
        .activityBackgroundTint(Color("LiveActivityBackground"))
    }
    
    private var runningView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(context.state.modeName)
                    .font(.headline.weight(.bold))
                    .foregroundColor(Color(context.state.modeColorName))
                Spacer()
                CycleIndicatorView(sessionCount: context.state.sessionCount, totalSessions: context.state.totalSessions, color: .secondary)
            }
            HStack {
                Label("Remaining", systemImage: "timer")
                    .font(.caption.weight(.semibold)).foregroundColor(.secondary)
                Spacer()
                Text(timerInterval: context.state.timerRange, countsDown: true)
                    .font(.title2.weight(.semibold).monospacedDigit()).contentTransition(.numericText()).foregroundColor(.primary)
            }
            GradientProgressBar(timerRange: context.state.timerRange,
                                color: Color(context.state.modeColorName),
                                isPaused: context.state.sessionState != .running)
        }
    }
    
    private var finishedView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").font(.title).foregroundColor(.green)
            Text(context.state.modeName).font(.headline.weight(.bold)).foregroundColor(.primary)
            Spacer()
        }
    }
}

private struct ExpandedIslandView: View {
    let context: ActivityViewContext<PomusActivityAttributes>
    var body: some View {
        VStack {
            HStack {
                Label { Text(context.state.modeName).font(.headline) } icon: { Image(systemName: "timer") }
                Spacer()
                Text(timerInterval: context.state.timerRange, countsDown: true).font(.subheadline.weight(.semibold).monospacedDigit()).contentTransition(.numericText())
            }
            GradientProgressBar(timerRange: context.state.timerRange,
                                color: Color(context.state.modeColorName),
                                isPaused: context.state.sessionState != .running)
        }
        .foregroundColor(Color(context.state.modeColorName))
    }
}

private struct CycleIndicatorView: View {
    let sessionCount: Int; let totalSessions: Int; var color: Color = .primary
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<totalSessions, id: \.self) { index in
                Circle().fill(index < sessionCount ? color : color.opacity(0.3)).frame(width: 8, height: 8)
            }
        }
    }
}

private struct GradientProgressBar: View {
    let timerRange: ClosedRange<Date>
    let color: Color
    var isPaused: Bool = false

    var body: some View {
        TimelineView(.animation(paused: isPaused)) { context in
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
        .frame(height: 8).clipShape(Capsule())
    }
    
    private func progress(for date: Date) -> Double {
        let totalDuration = timerRange.upperBound.timeIntervalSince(timerRange.lowerBound)
        guard totalDuration > 0 else { return 0 }
        let timeElapsed = date.timeIntervalSince(timerRange.lowerBound)
        return min(max(timeElapsed / totalDuration, 0), 1)
    }
}
