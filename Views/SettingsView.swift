//
//  Settings.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 11/07/25.
//


import SwiftUI

/// Settings view for the application.
struct SettingsView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Stepper(value: $viewModel.pomodoroDuration, in: 5*60...4*60*60, step: 5*60) {
                        Label("Focus: \(Int(viewModel.pomodoroDuration / 60)) min", systemImage: "brain.head.profile")
                    }
                    
                    Stepper(value: $viewModel.shortBreakDuration, in: 1*60...30*60, step: 1*60) {
                        Label("Short Break: \(Int(viewModel.shortBreakDuration / 60)) min", systemImage: "cup.and.saucer")
                    }
                    
                    Stepper(value: $viewModel.longBreakDuration, in: 10*60...45*60, step: 5*60) {
                        Label("Long Break: \(Int(viewModel.longBreakDuration / 60)) min", systemImage: "bed.double")
                    }
                    
                } header: { Text("Timer Durations") }
                  footer: { Text("Adjust the duration in minutes for each session type. Changes will apply to new sessions.") }

                Section {
                    Stepper(value: $viewModel.sessionsBeforeLongBreak, in: 2...8) {
                        Label("Sessions before long break: \(viewModel.sessionsBeforeLongBreak)", systemImage: "repeat.circle")
                    }
                    
                    Button(role: .destructive) {
                        viewModel.resetPomodoroCycle()
                    } label: {
                        Label("Reset Current Cycle", systemImage: "clear")
                    }
                    
                } header: { Text("Pomodoro Cycle") }
                  footer: { Text("Define how many focus sessions you need to complete before taking a long break. 'Reset Current Cycle' will restart the session count to zero.") }
                
                Section {
                    Toggle("Continuous Mode", isOn: $viewModel.isContinuousModeEnabled)
                    
                } header: { Text("Automation") }
                  footer: { Text("When enabled, the timer will automatically start the next session (focus or break) without stopping.") }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Restore Defaults", role: .destructive) {
                        showingResetAlert = true
                    }
                }
            }
            .alert("Restore Default Settings?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Restore", role: .destructive) {
                    viewModel.restoreDefaultSettings()
                }
            } message: {
                Text("Are you sure you want to restore all settings to their original values?")
            }
        }
    }
}
