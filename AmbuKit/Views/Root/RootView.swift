//
//  RootView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

// MARK: - Root View (100% Firebase)

/// Vista raíz que maneja el flujo de autenticación
/// - Loading: Muestra splash mientras inicializa
/// - No autenticado: Muestra LoginView
/// - Autenticado: Muestra MainTabScreen con UserFS
struct RootView: View {
    
    // MARK: - Environment
    
    @EnvironmentObject private var appState: AppState
    
    // MARK: - State
    
    @State private var isInitialized = false
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if !isInitialized {
                // Estado 1: Splash mientras inicializa
                splashScreen
            } else if appState.isLoadingUser {
                // Estado 2: Cargando usuario de Firestore
                loadingScreen
            } else if appState.isAuthenticated, let user = appState.currentUser {
                // Estado 3: Autenticado → MainTabScreen (Firebase)
                MainTabScreen(currentUser: user)
            } else {
                // Estado 4: No autenticado → Login
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isInitialized)
        .animation(.easeInOut(duration: 0.3), value: appState.isAuthenticated)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Initialization
    
    private func initialize() async {
        // Pequeño delay para mostrar splash (mejor UX)
        try? await Task.sleep(for: .milliseconds(800))
        
        withAnimation {
            isInitialized = true
        }
    }
}

// MARK: - Preview

#Preview("Root - Loading") {
    RootView()
        .environmentObject(AppState.shared)
}

#Preview("Root - Login") {
    let state = AppState.shared
    return RootView()
        .environmentObject(state)
}
