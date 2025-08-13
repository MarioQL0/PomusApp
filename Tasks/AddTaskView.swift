//
//  AddTaskView.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 11/07/25.
//

import SwiftUI

/// A view presented as a 'sheet' for the user to add a new task.
struct AddTaskView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: PomodoroViewModel
    
    /// @Environment reads a value from the environment. 'dismiss' is an action to close the current view.
    @Environment(\.dismiss) private var dismiss
    
    /// @State to store the text the user is typing.
    @State private var newTaskText: String = ""
    /// Controls whether the user wants to set a due date.
    @State private var hasDueDate: Bool = false
    /// The selected due date for the task.
    @State private var dueDate: Date = Date()
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Detail")) {
                    // A TextField that allows for multiple lines.
                    TextField("e.g., Finish the sales report...", text: $newTaskText, axis: .vertical)
                        .lineLimit(3...)
                }

                Section {
                    Toggle("Set Due Date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Button to cancel and close the sheet.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                // Button to save the new task.
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !newTaskText.isEmpty {
                            let date = hasDueDate ? dueDate : nil
                            viewModel.addTask(text: newTaskText, dueDate: date)
                            dismiss()
                        }
                    }
                    // The button is disabled if the text field is empty.
                    .disabled(newTaskText.isEmpty)
                }
            }
        }
    }
}
