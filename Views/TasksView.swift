import SwiftUI

struct TasksView: View {
    @ObservedObject var viewModel: PomodoroViewModel

    @State private var taskToEdit: PomodoroTask?
    @State private var newTaskText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    TextField("Agregar tarea…", text: $newTaskText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addTask)

                    Button(action: addTask) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 40, height: 40)
                            .background(Color.accentColor, in: Circle())
                            .foregroundStyle(.white)
                    }
                    .disabled(newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                List {
                    if !viewModel.pendingTasks.isEmpty {
                        Section("Pendientes") {
                            ForEach(viewModel.pendingTasks) { task in
                                taskRow(task)
                            }
                            .onDelete { viewModel.deleteTask(at: $0, in_completedList: false) }
                            .onMove(perform: viewModel.movePendingTask)
                        }
                    }

                    if !viewModel.completedTasks.isEmpty {
                        Section("Completadas") {
                            ForEach(viewModel.completedTasks) { task in
                                taskRow(task)
                            }
                            .onDelete { viewModel.deleteTask(at: $0, in_completedList: true) }
                        }
                    }
                }
                .overlay {
                    if viewModel.pendingTasks.isEmpty && viewModel.completedTasks.isEmpty {
                        ContentUnavailableView("Sin tareas", systemImage: "checklist", description: Text("Empieza con una tarea simple y mantenla visible."))
                    }
                }
                .listStyle(.insetGrouped)
            }
            .padding(.horizontal)
            .navigationTitle("Tareas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.completedTasks.isEmpty {
                        Button("Limpiar", role: .destructive, action: viewModel.clearCompletedTasks)
                    }
                }
            }
            .sheet(item: $taskToEdit) { task in
                EditTaskView(viewModel: viewModel, task: task)
            }
        }
    }

    private func taskRow(_ task: PomodoroTask) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation { viewModel.toggleTaskCompletion(task: task) }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(task.text)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)

            Spacer()

            Button {
                taskToEdit = task
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func addTask() {
        let cleanText = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        viewModel.addTask(text: cleanText)
        newTaskText = ""
    }
}
