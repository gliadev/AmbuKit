//
//  AmbuKitApp.swift
//  AmbuKit
//
//  Created by Adolfo on 10/11/25.
//  
//


import SwiftUI
import SwiftData
import FirebaseCore

@main
struct AmbuKitApp: App {
    
    // MARK: - App State (Firebase)
    
    @StateObject private var appState = AppState.shared
    
    // MARK: - SwiftData Container (Temporal - se elimina en TAREA 17)
    
    /// ModelContainer para compatibilidad con vistas existentes
    /// TODO: Eliminar cuando todas las vistas usen Firebase
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
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
                .modelContainer(sharedModelContainer) // Temporal para bridge
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
        return true
    }
}
#endif
