//
//  EditTaskView.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 11/07/25.
//

import SwiftUI

/// A view presented as a 'sheet' to edit an existing task.
struct EditTaskView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: PomodoroViewModel
    /// The task being edited, received from the previous view.
    let task: PomodoroTask
    
    @Environment(\.dismiss) private var dismiss
    
    /// @State to store the edited text. It's initialized with the task's current text.
    @State private var editedText: String
    /// Controls whether the task has a due date.
    @State private var hasDueDate: Bool
    /// The selected due date.
    @State private var dueDate: Date
    
    /// Custom initializer to pre-fill the text field.
    init(viewModel: PomodoroViewModel, task: PomodoroTask) {
        self.viewModel = viewModel
        self.task = task
        // _editedText is how you access the State wrapper for initialization.
        _editedText = State(initialValue: task.text)
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Date())
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Task Text")) {
                    TextField("Task text", text: $editedText, axis: .vertical)
                        .lineLimit(3...)
                }

                Section {
                    Toggle("Set Due Date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let date = hasDueDate ? dueDate : nil
                        viewModel.updateTask(task: task, newText: editedText, newDueDate: date)
                        dismiss()
                    }
                    .disabled(editedText.isEmpty)
                }
            }
        }
    }
}
