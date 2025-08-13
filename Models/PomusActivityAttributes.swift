//
//  PomusActivityAttributes.swift
//  Pomus
//
//  Created by Luis Mario Quezada Elizondo on 07/08/25.
//

import Foundation
import ActivityKit
import SwiftUI

/// ActivityKit attributes shared between the app and the widget extension.
/// Default access level (`internal`) is sufficient because this file is
/// included in both targets.
struct PomusActivityAttributes: ActivityAttributes {

    /// Dynamic content delivered to the live activity. It wraps the same
    /// `PomusTimerState` model used by the main app and the widget so all three
    /// surfaces remain synchronized.
    struct ContentState: Codable, Hashable {
        var timer: PomusTimerState
    }
}
