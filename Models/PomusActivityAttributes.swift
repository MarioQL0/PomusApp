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
    
    public struct ContentState: Codable, Hashable {
        public var timerRange: ClosedRange<Date>
        public var modeName: String
        public var modeColorName: String
        public var sessionCount: Int
        public var totalSessions: Int
        public var sessionState: SessionState
    }

    // No hay atributos estáticos.
    
    // --- CORRECCIÓN ---
    // Añadimos los estados que faltaban.
    public enum SessionState: String, Codable, Hashable {
        case running
        case finished
        case paused
        case transitioning // Un estado muy breve para los cambios de modo
    }
}
