//
//  viewModel.weeklyStats.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 10/07/25.
//

import Foundation

@MainActor
extension PomodoroViewModel {

    // MARK: - Estadísticas
    /// Almacena el conteo de sesiones completadas por día (formato "MM/dd/yy").
    @Published private(set) var sessionsByDay: [String: Int] = [:]

    /// Devuelve un array de PomodoroStat para los últimos 7 días.
    var weeklyStats: [PomodoroStat] {
        let calendar = Calendar.current
        let today = Date()
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "MM/dd/yy"
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "es")
        dayFormatter.dateFormat = "E"

        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = keyFormatter.string(from: date)
            let dayAbbrev = dayFormatter.string(from: date).capitalized
            let count = sessionsByDay[key] ?? 0
            return PomodoroStat(day: dayAbbrev, count: count)
        }
    }

    /// Registra una sesión Pomodoro completada en el día actual.
    func recordPomodoroSession() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        let key = formatter.string(from: Date())
        sessionsByDay[key, default: 0] += 1
    }
}
