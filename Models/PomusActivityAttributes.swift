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
    
    // ContentState ahora contiene TODOS los datos que pueden cambiar.
    public struct ContentState: Codable, Hashable {
        public var timerRange: ClosedRange<Date>
        public var modeName: String
        public var modeColorName: String
        public var sessionCount: Int
        public var totalSessions: Int
        public var sessionState: SessionState
    }

    // Ya no hay datos estáticos aquí, solo es el tipo.
    
    public enum SessionState: String, Codable, Hashable {
        case running
        case finished
    }
}
