//
//  Tasks.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 11/07/25.
//

import Foundation

/// Represents a single task in the to-do list.
/// Conforms to 'Identifiable' to be used in SwiftUI Lists.
/// Conforms to 'Codable' to be easily saved to and loaded from UserDefaults.
/// Conforms to 'Hashable' to be used in collections that require hashing.
struct PomodoroTask: Identifiable, Codable, Hashable {
    /// A unique universal identifier for each task.
    var id = UUID()
    /// The text or description of the task.
    var text: String
    /// The optional due date for the task.
    var dueDate: Date? = nil
    /// A boolean indicating whether the task has been completed.
    var isCompleted: Bool = false
}
