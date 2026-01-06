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
import FirebaseFirestore
import FirebaseAuth

@main
struct AmbuKitApp: App {
    
    // MARK: - App State (Firebase)
    
    @StateObject private var appState = AppState.shared
    
    // MARK: - SwiftData Container (Temporal - se elimina en TAREA 17)
    
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
        // Configurar Firebase (solo una vez)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        if Self.isRunningTests {
            print("🧪 Tests detectados - usando Firebase REAL")
        } else {
            print("✅ Firebase configurado correctamente")
            print("🔥 Firestore habilitado")
            print("🔐 Firebase Auth habilitado")
            print("📱 AmbuKit iniciado")
        }
        
        #if DEBUG
        print("⚠️ Modo DEBUG activado")
        #endif
    }

    // MARK: - Test Detection

    private static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }
    

    private static func configureEmulators() {
        let db = Firestore.firestore()
        let settings = db.settings
        settings.host = "localhost:8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        db.settings = settings
        
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .modelContainer(sharedModelContainer)
        }
    }
}
