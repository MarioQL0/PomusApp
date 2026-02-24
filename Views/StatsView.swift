import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var viewModel: PomodoroViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    chartCard
                    metricsGrid
                }
                .padding()
            }
            .navigationTitle("Estadísticas")
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actividad semanal")
                .font(.headline)

            Chart(viewModel.weeklyFocusStats) { stat in
                BarMark(
                    x: .value("Día", stat.day),
                    y: .value("Min", stat.duration / 60)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(4)
            }
            .frame(height: 190)

            Text("Tiempo total enfocado esta semana: \(weekMinutes)m")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatMetricCard(title: "Pomodoros", value: "\(viewModel.totalPomodorosCompleted)", icon: "timer")
            StatMetricCard(title: "Horas enfoque", value: viewModel.totalFocusTimeFormatted, icon: "brain.head.profile")
            StatMetricCard(title: "Tareas", value: "\(viewModel.totalTasksCompleted)", icon: "checkmark.circle")
            StatMetricCard(title: "Descansos", value: "\(viewModel.totalBreaksTaken)", icon: "cup.and.saucer")
        }
    }

    private var weekMinutes: Int {
        Int(viewModel.weeklyFocusStats.reduce(0) { $0 + $1.duration } / 60)
    }
}

private struct StatMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.accent)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
