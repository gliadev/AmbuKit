//
//  AmbuKitApp.swift
//  AmbuKit
//
//  Created by Adolfo on 10/11/25.
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
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
        print("📱 AmbuKit iniciado🤪")
    }

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .modelContainer(sharedModelContainer) // Temporal
        }
    }
}
