//
//  MainView.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 11/07/25.
//

import SwiftUI

/// The main view of the application, with fully adaptive layouts.
struct MainView: View {
    // MARK: - Properties
    @StateObject private var viewModel = PomodoroViewModel()
    
    // Onboarding State
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false
    
    // State for other modal sheets
    @State private var showTasks = false
    @State private var showStats = false
    @State private var showSettings = false
    @State private var isControlPanelVisible = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    // MARK: - Body
    var body: some View {
        ZStack {
            viewModel.currentMode.color
                .ignoresSafeArea()
                .animation(.easeInOut, value: viewModel.currentMode)
            
            // Switch between layouts based on the vertical size class.
            if verticalSizeClass == .compact {
                // Use GeometryReader for landscape to get available size
                GeometryReader { geometry in
                    landscapeLayout(geometry: geometry)
                }
            } else {
                portraitLayout
            }
        }
        .sheet(isPresented: $showTasks) { TasksView(viewModel: viewModel) }
        .sheet(isPresented: $showStats) { StatsView(viewModel: viewModel) }
        .sheet(isPresented: $showSettings) { SettingsView(viewModel: viewModel) }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView {
                hasCompletedOnboarding = true
                showingOnboarding = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            if !hasCompletedOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingOnboarding = true
                }
            }
        }
    }
    
    // MARK: - Layouts

    /// The layout for vertical orientation (portrait on iPhone, and both on iPad).
    private var portraitLayout: some View {
        VStack {
            // Top bar with Stats and Settings buttons.
            HStack {
                Button(action: { showStats.toggle() }) { Image(systemName: "chart.bar.xaxis") }
                Spacer()
                Text("Pomus").font(.headline.weight(.semibold))
                Spacer()
                Button(action: { showSettings.toggle() }) { Image(systemName: "gearshape.fill") }
            }
            .font(.title2)
            .padding([.horizontal, .top])
            
            Spacer()
            
            // Clock in the center.
            ClockView(viewModel: viewModel, diameter: horizontalSizeClass == .regular ? 420 : 280)
                .onTapGesture(count: 2) { viewModel.skipToNextMode() }
                .onLongPressGesture { viewModel.toggleClockView() }
            
            CycleIndicatorView(viewModel: viewModel)
                .padding(.top)
            
            Spacer()
            
            // Bottom control bar with the three main action buttons.
            HStack(spacing: 25) {
                Button(action: viewModel.resetCurrentSession) {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 60, height: 60)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                
                Button(action: { viewModel.startPauseTimer() }) {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 40))
                        .frame(width: 80, height: 80)
                        .background(Color.white.opacity(0.3))
                        .clipShape(Circle())
                }
                
                Button(action: { showTasks.toggle() }) {
                    Image(systemName: "list.bullet")
                        .frame(width: 60, height: 60)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .font(.title2)
            .padding(.bottom)
        }
        .foregroundColor(.white)
    }
    
    /// The layout for horizontal orientation, which now uses GeometryProxy.
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        // Calculate the clock diameter based on the available height.
        let clockDiameter = geometry.size.height * 0.7
        
        return ZStack {
            VStack {
                // Pass the dynamically calculated diameter to the ClockView.
                ClockView(viewModel: viewModel, diameter: clockDiameter)
                    .onTapGesture(count: 2) { viewModel.skipToNextMode() }
                    .onLongPressGesture { viewModel.toggleClockView() }
                
                CycleIndicatorView(viewModel: viewModel)
                    .padding(.top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isControlPanelVisible.toggle()
                }
            }
            
            VStack {
                Spacer()
                if isControlPanelVisible {
                    controlPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    /// The toggleable control panel for landscape mode.
    private var controlPanel: some View {
        HStack {
            Spacer()
            Button(action: { showStats.toggle() }) { Image(systemName: "chart.bar.xaxis") }.frame(maxWidth: .infinity)
            Button(action: viewModel.resetCurrentSession) { Image(systemName: "arrow.counterclockwise") }.frame(maxWidth: .infinity)

            Button(action: { viewModel.startPauseTimer() }) {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 32, weight: .bold))
                    .frame(width: 70, height: 70)
                    .background(Color.white.opacity(0.3))
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity)
            
            Button(action: { showTasks.toggle() }) { Image(systemName: "list.bullet") }.frame(maxWidth: .infinity)
            Button(action: { showSettings.toggle() }) { Image(systemName: "gearshape.fill") }.frame(maxWidth: .infinity)
            Spacer()
        }
        .font(.title2)
        .foregroundColor(.white)
        .padding(.vertical, 10)
        .background(.black.opacity(0.25))
        .clipShape(Capsule())
        .padding(.horizontal)
        .padding(.bottom, 20)
        .onTapGesture {}
    }
}


// MARK: - Cycle Indicator Component
private struct CycleIndicatorView: View {
    @ObservedObject var viewModel: PomodoroViewModel

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<viewModel.sessionsBeforeLongBreak, id: \.self) { index in
                Circle()
                    .fill(index < viewModel.pomodoroSessionCount ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
        }
        .animation(.spring, value: viewModel.pomodoroSessionCount)
    }
}
