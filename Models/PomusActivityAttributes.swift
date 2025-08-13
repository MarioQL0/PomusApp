//
//  PomusActivityAttributes.swift
//  Pomus
//
//  Created by Luis Mario Quezada Elizondo on 07/08/25.
//
//  Actualizado para soportar estados dinámicos como 'pausado' y 'corriendo'.
//

import Foundation
import ActivityKit
import SwiftUI

/// Define los datos necesarios para que la Live Activity de Pomus funcione.
public struct PomusActivityAttributes: ActivityAttributes {

    /// `ContentState` contiene todos los datos que pueden cambiar mientras la Live Activity está activa.
    /// Es la única fuente de verdad para la vista de la actividad.
    public struct ContentState: Codable, Hashable {
        /// El rango de tiempo que usa el temporizador para mostrar la cuenta regresiva.
        /// Se actualiza al pausar y reanudar para mantener la sincronización.
        public var timerRange: ClosedRange<Date>
        
        /// El nombre del modo actual (ej: "Focus", "Break").
        public var modeName: String
        
        /// El nombre del color para el modo actual (ej: "FocusColor").
        /// Se usa para colorear los elementos de la UI en la actividad.
        public var modeColorName: String
        
        /// El número de sesiones completadas en el ciclo actual.
        public var sessionCount: Int
        
        /// El número total de sesiones antes de un descanso largo.
        public var totalSessions: Int
        
        /// **El estado clave para la sincronización**: Indica si el temporizador
        /// está corriendo, pausado o ha finalizado.
        public var sessionState: SessionState
    }

    /// `SessionState` define los posibles estados del temporizador.
    /// Este enum es crucial para que la Live Activity sepa cómo dibujarse.
    public enum SessionState: String, Codable, Hashable {
        /// El temporizador está activo y contando hacia atrás.
        case running
        
        /// El temporizador se ha detenido temporalmente. La UI debe reflejar esto.
        case paused
        
        /// La sesión ha terminado (aunque generalmente la actividad se cierra antes de este estado).
        case finished
    }
    
    // Ya no se necesitan atributos estáticos (los que no cambian),
    // porque toda la información necesaria es dinámica y está en `ContentState`.
}
