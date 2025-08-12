//
//  StatsView.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 11/07/25.
//

import SwiftUI
import Charts

/// Displays the user's productivity statistics.
struct StatsView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    
    // ⚠️ IMPORTANTE: Cambia esto a 'false' antes de subir la app a la tienda.
    @State private var useFakeDataForScreenshot = false
    
    var body: some View {
        NavigationView {
            Group {
                // The empty state is only shown if we are NOT using fake data.
                if viewModel.totalPomodorosCompleted == 0 && !useFakeDataForScreenshot {
                    ContentUnavailableView {
                        Label("No Statistics", systemImage: "chart.bar.xaxis")
                    } description: {
                        Text("Complete your first pomodoro to see your progress here!")
                    }
                } else {
                    statsContent
                }
            }
            .navigationTitle("Statistics")
        }
    }
    
    /// The main content of the statistics view.
    private var statsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: Weekly Chart
                VStack(alignment: .leading, spacing: 5) {
                    Text("Weekly Activity")
                        .font(.headline)
                    Text("Focus time per day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                
                // Use fake data for screenshots if enabled.
                Chart(useFakeDataForScreenshot ? fakeWeeklyStats : viewModel.weeklyFocusStats) { stat in
                    BarMark(
                        x: .value("Day", stat.day),
                        y: .value("Minutes", stat.duration / 60)
                    )
                    .foregroundStyle(by: .value("Type", "Focus"))
                    .annotation(position: .top) {
                        if stat.duration > 0 {
                            Text(formatDuration(stat.duration))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .chartForegroundStyleScale(["Focus": Color.red.opacity(0.8)])
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // MARK: Summary Cards
                Text("General Summary")
                    .font(.title2)
                    .bold()
                    .padding(.horizontal)
                
                // Use fake data for screenshots if enabled.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                    StatCard(title: "Total Pomodoros", value: useFakeDataForScreenshot ? "123" : "\(viewModel.totalPomodorosCompleted)", icon: "timer", color: .red)
                    StatCard(title: "Focus Hours", value: useFakeDataForScreenshot ? "41h 15m" : viewModel.totalFocusTimeFormatted, icon: "brain.head.profile", color: .blue)
                    StatCard(title: "Tasks Completed", value: useFakeDataForScreenshot ? "89" : "\(viewModel.totalTasksCompleted)", icon: "checkmark.seal.fill", color: .green)
                    StatCard(title: "Breaks Taken", value: useFakeDataForScreenshot ? "98" : "\(viewModel.totalBreaksTaken)", icon: "cup.and.saucer.fill", color: .orange)
                }
                .padding(.horizontal)
                
            }.padding(.vertical)
        }
    }
    
    /// Formats a duration in seconds to an "Xh Ym" or "Ym" string.
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// A computed property that returns a set of fake stats for the chart.
    private var fakeWeeklyStats: [FocusStat] {
        return [
            FocusStat(day: "Mon", duration: 3600),
            FocusStat(day: "Tue", duration: 5400),
            FocusStat(day: "Wed", duration: 2700),
            FocusStat(day: "Thu", duration: 7200),
            FocusStat(day: "Fri", duration: 4500),
            FocusStat(day: "Sat", duration: 1800),
            FocusStat(day: "Sun", duration: 6300)
        ]
    }
}

/// A reusable view to display a single statistic in a card.
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title).bold().minimumScaleFactor(0.7)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
