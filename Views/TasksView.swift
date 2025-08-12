//
//  TasksView.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 11/07/25.
//


import SwiftUI

/// Main view for managing the task list.
struct TasksView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: PomodoroViewModel
    
    @State private var useFakeDataForScreenshots = false // ⚠️ Pon en 'true' para screenshots
    @State private var taskToEdit: PomodoroTask?
    @State private var isAddingTask = false
    @State private var newTaskText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingCleanAlert = false

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Layer 1: The main content.
                Group {
                    let isContentEmpty = viewModel.pendingTasks.isEmpty && viewModel.completedTasks.isEmpty
                    if isContentEmpty && !useFakeDataForScreenshots && !isAddingTask {
                        ContentUnavailableView {
                            Label("No Tasks", systemImage: "checklist")
                        } description: {
                            Text("Add your first task using the + button.")
                        }
                    } else {
                        List {
                            pendingTasksSection
                            completedTasksSection
                        }
                        .background(
                            Color.clear.contentShape(Rectangle())
                                .onTapGesture {
                                    isTextFieldFocused = false
                                }
                        )
                    }
                }
                
                // Layer 2: The conditional bottom UI.
                VStack {
                    Spacer()
                    if isAddingTask {
                        addTaskBar
                    } else {
                        floatingActionButton
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isAddingTask)
            }
            .navigationTitle("Tasks")
            .toolbar {
                // Botón "Clean"
                ToolbarItem(placement: .navigationBarLeading) {
                    if useFakeDataForScreenshots || !viewModel.completedTasks.isEmpty {
                        Button("Clean", role: .destructive) {
                            showingCleanAlert = true
                        }
                        .disabled(useFakeDataForScreenshots)
                    }
                }
                
                // Botón "Edit" para reordenar
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !useFakeDataForScreenshots {
                        EditButton()
                    }
                }
            }
            .alert("Clear Completed Tasks?", isPresented: $showingCleanAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    withAnimation {
                        viewModel.clearCompletedTasks()
                    }
                }
            } message: {
                Text("This will permanently delete all completed tasks. This action cannot be undone.")
            }
            .sheet(item: $taskToEdit) { task in
                EditTaskView(viewModel: viewModel, task: task)
            }
        }
    }
    
    // MARK: - Subviews
    private var addTaskBar: some View {
        HStack {
            TextField("New task...", text: $newTaskText)
                .focused($isTextFieldFocused)
                .onSubmit(submitNewTask)

            Button {
                withAnimation {
                    isAddingTask = false
                    newTaskText = ""
                }
            } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }
            
            Button(action: submitNewTask) { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                .disabled(newTaskText.isEmpty)
        }
        .padding().background(.bar).cornerRadius(10).padding(.horizontal).padding(.bottom, 8)
        .transition(.offset(y: 100).combined(with: .opacity))
    }
    
    private var floatingActionButton: some View {
        HStack {
            Spacer()
            Button(action: {
                isAddingTask = true
                isTextFieldFocused = true
            }) {
                Image(systemName: "plus")
                    .font(.system(.title, weight: .semibold)).foregroundColor(.white)
                    .frame(width: 60, height: 60).background(Color.blue).clipShape(Circle())
                    .shadow(radius: 5, x: 0, y: 4)
            }
            .padding()
        }
        .transition(.offset(y: 100).combined(with: .opacity))
    }

    // MARK: - Helper Functions
    private func submitNewTask() {
        if !newTaskText.isEmpty {
            viewModel.addTask(text: newTaskText)
            newTaskText = ""; isTextFieldFocused = false; isAddingTask = false
        }
    }

    private func deletePendingTask(at offsets: IndexSet) {
        guard !useFakeDataForScreenshots else { return }
        viewModel.deleteTask(at: offsets, in_completedList: false)
    }

    private func deleteCompletedTask(at offsets: IndexSet) {
        guard !useFakeDataForScreenshots else { return }
        viewModel.deleteTask(at: offsets, in_completedList: true)
    }
    
    private func movePendingTask(from source: IndexSet, to destination: Int) {
        guard !useFakeDataForScreenshots else { return }
        viewModel.movePendingTask(from: source, to: destination)
    }

    // MARK: - List Sections
    @ViewBuilder
    private var pendingTasksSection: some View {
        let tasksToShow = useFakeDataForScreenshots ? fakePendingTasks : viewModel.pendingTasks
        
        if !tasksToShow.isEmpty {
            Section(header: Text("Pending")) {
                ForEach(tasksToShow) { task in
                    TaskRowView(task: task, viewModel: viewModel, isFake: useFakeDataForScreenshots)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !useFakeDataForScreenshots {
                                Button(role: .destructive) {
                                    if let index = viewModel.pendingTasks.firstIndex(where: { $0.id == task.id }) {
                                        deletePendingTask(at: IndexSet(integer: index))
                                    }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if !useFakeDataForScreenshots {
                                Button { taskToEdit = task } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                            }
                        }
                }
                .onMove(perform: movePendingTask)
            }
        }
    }

    @ViewBuilder
    private var completedTasksSection: some View {
        let tasksToShow = useFakeDataForScreenshots ? fakeCompletedTasks : viewModel.completedTasks

        if !tasksToShow.isEmpty {
            Section(header: Text("Completed")) {
                ForEach(tasksToShow) { task in
                    TaskRowView(task: task, viewModel: viewModel, isFake: useFakeDataForScreenshots)
                }
                .onDelete(perform: deleteCompletedTask)
            }
        }
    }
    
    // --- DATOS DE EJEMPLO PARA LAS CAPTURAS ---
    private var fakePendingTasks: [PomodoroTask] {
        [ PomodoroTask(text: "Design the new app icon"), PomodoroTask(text: "Prepare presentation"), PomodoroTask(text: "Fix layout bug") ]
    }
    
    private var fakeCompletedTasks: [PomodoroTask] {
        [ PomodoroTask(text: "Buy coffee", isCompleted: true), PomodoroTask(text: "Send weekly report", isCompleted: true) ]
    }
}

// MARK: - Task Row View
struct TaskRowView: View {
    let task: PomodoroTask
    @ObservedObject var viewModel: PomodoroViewModel
    var isFake: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .gray)
                .font(.title2)
                .onTapGesture {
                    if !isFake {
                        withAnimation {
                            viewModel.toggleTaskCompletion(task: task)
                        }
                    }
                }
            
            Text(task.text)
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .gray : .primary)
        }
    }
}
