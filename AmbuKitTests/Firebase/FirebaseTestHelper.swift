//
//  FirebaseTestHelper.swift
//  AmbuKitTests
//
//  Created by Adolfo on 22/12/25.
//

import Foundation
import FirebaseCore

/// Helper para tests con Firebase REAL
/// Firebase ya se configura en AmbuKitApp.init()
enum FirebaseTestHelper {
    
    nonisolated(unsafe) private static var isConfigured = false
    
    /// Verifica que Firebase está configurado (ya lo hace AmbuKitApp)
    @MainActor
    static func configureIfNeeded() {
        guard !isConfigured else { return }
        
        // Firebase ya está configurado por AmbuKitApp
        // Solo verificamos y marcamos como listo
        if FirebaseApp.app() != nil {
            print("🧪 Firebase ya configurado - tests listos")
            isConfigured = true
        } else {
            print("⚠️ Firebase no configurado - esto no debería pasar")
        }
    }
}

