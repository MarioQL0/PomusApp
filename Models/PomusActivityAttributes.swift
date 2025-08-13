//
//  PomusActivityAttributes.swift
//  Pomus
//
//  Created by Luis Mario Quezada Elizondo on 07/08/25.
//

import Foundation
import ActivityKit
import SwiftUI

public struct PomusActivityAttributes: ActivityAttributes {

    /// The dynamic content delivered to the live activity. It wraps the same
    /// `PomusTimerState` model used by the main app and the widget so all three
    /// surfaces remain synchronized.
    public struct ContentState: Codable, Hashable {
        public var timer: PomusTimerState
    }
}
