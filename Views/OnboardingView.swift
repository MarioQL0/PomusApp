//
//  OnboardingView.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 12/07/25.
//

import SwiftUI

/// A reusable view for a single page in the onboarding flow.
struct OnboardingPageView: View {
    let imageName: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: imageName)
                .font(.system(size: 100, weight: .light))
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.title).bold()
            
            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 40)
    }
}


/// The main onboarding view that contains multiple swipeable pages.
struct OnboardingView: View {
    // This action will be passed from the parent view to dismiss the sheet.
    var onComplete: () -> Void

    var body: some View {
        VStack {
            Spacer()
            
            // TabView with PageTabViewStyle creates the swipeable interface.
            TabView {
                OnboardingPageView(
                    imageName: "hand.tap",
                    title: "Skip a Session",
                    description: "Double-tap the clock to skip the current session and move to the next one."
                )
                
                OnboardingPageView(
                    imageName: "hand.draw",
                    title: "Change Clock Style",
                    description: "Long-press the clock to switch between the modern digital and classic analog views."
                )
                
                OnboardingPageView(
                    imageName: "hand.point.left.and.right",
                    title: "Manage Your Tasks",
                    description: "In the task list, swipe a task to the right to Edit, or to the left to Delete."
                )
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            Spacer()
            
            // Button to finish the onboarding.
            Button("Get Started") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 50)
        }
    }
}


// MARK: - Preview
#Preview {
    // We pass an empty action for the preview.
    OnboardingView(onComplete: {})
}
