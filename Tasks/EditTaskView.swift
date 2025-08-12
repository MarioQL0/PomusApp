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
    
    /// Custom initializer to pre-fill the text field.
    init(viewModel: PomodoroViewModel, task: PomodoroTask) {
        self.viewModel = viewModel
        self.task = task
        // _editedText is how you access the State wrapper for initialization.
        _editedText = State(initialValue: task.text)
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Task Text")) {
                    TextField("Task text", text: $editedText, axis: .vertical)
                        .lineLimit(3...)
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
                        viewModel.updateTask(task: task, newText: editedText)
                        dismiss()
                    }
                    .disabled(editedText.isEmpty)
                }
            }
        }
    }
}
