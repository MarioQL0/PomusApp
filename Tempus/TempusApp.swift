//
//  TempusApp.swift
//  Tempus
//
//  Created by Luis Mario Quezada Elizondo on 11/07/25.
//

import SwiftUI

// The @main attribute identifies the app's main entry point.
// This is where the application begins its execution.
@main
struct Tempus: App {
    // The 'body' property of an App defines the app's primary scene.
    var body: some Scene {
        // WindowGroup is the standard scene for a single-window app.
        WindowGroup {
            // MainView() is the first view that will be displayed when the app launches.
            MainView()
        }
    }
}
