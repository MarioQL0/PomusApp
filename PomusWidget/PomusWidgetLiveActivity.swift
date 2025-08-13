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
                Image(systemName: "timer").foregroundColor(Color(context.state.timer.modeColorName))
            } compactTrailing: {
                if let start = context.state.timer.startDate, let end = context.state.timer.endDate {
                    Text(timerInterval: start...end, countsDown: true).monospacedDigit().frame(width: 50)
                }
            } minimal: {
                Image(systemName: "timer").foregroundColor(Color(context.state.timer.modeColorName))
            }
        }
    }
}

// MARK: - Vistas de Componentes

private struct LockScreenView: View {
    let context: ActivityViewContext<PomusActivityAttributes>
    var body: some View {
        VStack {
            if context.state.timer.status == .idle {
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
                Text(context.state.timer.modeName)
                    .font(.headline.weight(.bold))
                    .foregroundColor(Color(context.state.timer.modeColorName))
                Spacer()
                CycleIndicatorView(sessionCount: context.state.timer.sessionCount, totalSessions: context.state.timer.totalSessions, color: .secondary)
            }
            HStack {
                Label("Remaining", systemImage: "timer")
                    .font(.caption.weight(.semibold)).foregroundColor(.secondary)
                Spacer()
                if let start = context.state.timer.startDate, let end = context.state.timer.endDate {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.title2.weight(.semibold).monospacedDigit()).contentTransition(.numericText()).foregroundColor(.primary)
                }
            }
            GradientProgressBar(timer: context.state.timer,
                                color: Color(context.state.timer.modeColorName))
        }
    }

    private var finishedView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").font(.title).foregroundColor(.green)
            Text(context.state.timer.modeName).font(.headline.weight(.bold)).foregroundColor(.primary)
            Spacer()
        }
    }
}

private struct ExpandedIslandView: View {
    let context: ActivityViewContext<PomusActivityAttributes>
    var body: some View {
        VStack {
            HStack {
                Label { Text(context.state.timer.modeName).font(.headline) } icon: { Image(systemName: "timer") }
                Spacer()
                if let start = context.state.timer.startDate, let end = context.state.timer.endDate {
                    Text(timerInterval: start...end, countsDown: true).font(.subheadline.weight(.semibold).monospacedDigit()).contentTransition(.numericText())
                }
            }
            GradientProgressBar(timer: context.state.timer,
                                color: Color(context.state.timer.modeColorName))
        }
        .foregroundColor(Color(context.state.timer.modeColorName))
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
        .frame(height: 8).clipShape(Capsule())
    }
}
