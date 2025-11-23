//
//  RootView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI
import SwiftData

// MARK: - Root View (Actualizado para Firebase)

struct RootView: View {
    
    // MARK: - Environment
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    
    // MARK: - State
    @State private var isInitialized = false
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if !isInitialized {
                // Splash screen mientras inicializa
                splashScreen
            } else if appState.isLoadingUser {
                // Loading mientras carga usuario de Firestore
                loadingScreen
            } else if appState.isAuthenticated, let user = appState.currentUser {
                // Usuario autenticado → MainTabView
                MainTabViewFS(currentUser: user)
            } else {
                // No autenticado → LoginView
                LoginView()
            }
        }
        .task {
            await initialize()
        }
    }
    
    // MARK: - Splash Screen
    
    private var splashScreen: some View {
        VStack(spacing: 24) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
            
            Text("AmbuKit")
                .font(.largeTitle.bold())
            
            ProgressView()
                .tint(.blue)
        }
    }
    
    // MARK: - Loading Screen
    
    private var loadingScreen: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.blue)
            
            Text("Cargando información...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Initialization
    
    private func initialize() async {
        // Ejecutar seed data de SwiftData (temporal)
        try? SeedDataLoader.runIfNeeded(context: context)
        
        // Pequeño delay para mostrar splash
        try? await Task.sleep(for: .milliseconds(500))
        
        isInitialized = true
    }
}

// MARK: - MainTabView Wrapper (Bridge entre SwiftData y Firebase)

/// Versión temporal de MainTabView que convierte UserFS → User
/// Esto permite que las vistas existentes sigan funcionando
/// TODO: Eliminar cuando todas las vistas usen UserFS
struct MainTabViewFS: View {
    let currentUser: UserFS
    @Environment(\.modelContext) private var context
    @State private var swiftDataUser: User?
    
    var body: some View {
        Group {
            if let sdUser = swiftDataUser {
                // Usar MainTabView existente con User de SwiftData
                MainTabView(currentUser: sdUser)
            } else {
                // Loading mientras busca usuario en SwiftData
                ProgressView("Cargando perfil...")
            }
        }
        .task {
            await loadSwiftDataUser()
        }
    }
    
    private func loadSwiftDataUser() async {
        // Buscar usuario en SwiftData por username
        let usernameToFind = currentUser.username
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.username == usernameToFind }
            )
        
        swiftDataUser = try? context.fetch(descriptor).first
        
        // Si no existe, podemos crear uno temporal
        if swiftDataUser == nil {
            print("⚠️ Usuario no encontrado en SwiftData, usando datos de Firebase")
            // TODO: Aquí podrías crear un User temporal o mostrar error
        }
    }
}

// MARK: - Preview

#Preview("Root - Not Authenticated") {
    RootView()
        .environmentObject(AppState.shared)
        .modelContainer(PreviewSupport.container)
}







