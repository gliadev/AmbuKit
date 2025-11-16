//
//  AmbuKitApp.swift
//  AmbuKit
//
//  Created by Adolfo on 10/11/25.
//  Updated by Claude on 16/11/25 - TAREA 2: Autenticación
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct AmbuKitApp: App {
    
    // MARK: - App State
    
    @StateObject private var appState = AppState.shared
    
    // MARK: - SwiftData (Temporal - se eliminará después)
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Entities actuales de SwiftData
            User.self,
            Role.self,
            Policy.self,
            Base.self,
            Vehicle.self,
            Kit.self,
            KitItem.self,
            CatalogItem.self,
            Category.self,
            UnitOfMeasure.self,
            AuditLog.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    // MARK: - Initialization
    
    init() {
        // Configurar Firebase
        FirebaseApp.configure()
        
        print("✅ Firebase configurado correctamente")
        print("🔥 Firestore habilitado")
        print("🔐 Firebase Auth habilitado")
        print("📱 AmbuKit iniciado")
        
        #if DEBUG
        print("⚠️ Modo DEBUG activado")
        #endif
    }

    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .modelContainer(sharedModelContainer) // Temporal - hasta migración completa
        }
    }
}

// MARK: - App Delegate (Opcional - para notificaciones futuras)

#if canImport(UIKit)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Configuraciones adicionales aquí
        return true
    }
}
#endif
