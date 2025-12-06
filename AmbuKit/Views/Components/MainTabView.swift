//
//  MainTabView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI
import SwiftData 
// MARK: - MainTabView

/// Vista principal con tabs - Versión Firebase
///
/// Recibe UserFS de Firebase, verifica permisos async con AuthorizationServiceFS,
/// y pasa User (SwiftData) a las vistas hijas hasta que se migren en TAREAS 12-14.
struct MainTabView: View {
    
    // MARK: - Properties
    
    /// Usuario actual de Firebase
    let currentUser: UserFS
    
    // MARK: - State
    
    /// Cache de permisos para tabs
    @State private var canAccessAdmin = false
    
    /// RoleKind del usuario (para colores)
    @State private var roleKind: RoleKind? = nil
    
    /// Estado de carga de permisos
    @State private var isLoadingPermissions = true
    
    /// Usuario de SwiftData (puente temporal)
    @State private var bridgedUser: User? = nil
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoadingPermissions {
                loadingView
            } else if let user = bridgedUser {
                mainTabView(user: user)
            } else {
                userNotFoundView
            }
        }
        .task {
            await loadInitialData()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Cargando permisos...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Main Tab View
    
    @ViewBuilder
    private func mainTabView(user: User) -> some View {
        TabView {
            // Tab 1: Inventario (todos los roles)
            InventoryView(currentUser: user)
                .tabItem {
                    Label("Inventario", systemImage: "shippingbox")
                }
            
            // Tab 2: Gestión (solo Programador y Logística)
            if canAccessAdmin {
                AdminView(currentUser: user)
                    .tabItem {
                        Label("Gestión", systemImage: "gearshape")
                    }
            }
            
            // Tab 3: Perfil (todos los roles)
            ProfileView(currentUser: user)
                .tabItem {
                    Label("Perfil", systemImage: "person")
                }
        }
        .tint(accentColor)
    }
    
    // MARK: - User Not Found View
    
    private var userNotFoundView: some View {
        ContentUnavailableView {
            Label("Usuario no sincronizado",
                  systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
            Text("No se encontró el usuario '\(currentUser.username)' en la base de datos local. Esto puede ocurrir si los datos no están sincronizados.")
        } actions: {
            Button("Reintentar") {
                Task {
                    await loadInitialData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Accent Color
    
    private var accentColor: Color {
        switch roleKind {
        case .programmer: return .blue
        case .logistics: return .orange
        case .sanitary: return .green
        case .none: return .blue
        }
    }
    
    // MARK: - Load Initial Data
    
    private func loadInitialData() async {
        isLoadingPermissions = true
        
        // Ejecutar todas las cargas en paralelo
        async let permissionsTask: Void = loadPermissions()
        async let userTask: Void = loadSwiftDataUser()
        
        // Esperar ambas tareas
        _ = await (permissionsTask, userTask)
        
        isLoadingPermissions = false
    }
    
    // MARK: - Load Permissions
    
    private func loadPermissions() async {
        // Cargar permisos en paralelo
        async let adminCheck = checkAdminAccess()
        async let roleCheck = PolicyService.shared.getRoleKind(for: currentUser)
        
        canAccessAdmin = await adminCheck
        roleKind = await roleCheck
    }
    
    /// Verifica si el usuario puede acceder al tab Admin
    private func checkAdminAccess() async -> Bool {
        // Admin accesible para Programador y Logística
        let isProgrammer = await AuthorizationServiceFS.isProgrammer(currentUser)
        if isProgrammer { return true }
        
        let isLogistics = await AuthorizationServiceFS.isLogistics(currentUser)
        return isLogistics
    }
    
    // MARK: - Load SwiftData User (Puente Temporal)
    
    /// Busca el usuario equivalente en SwiftData
    /// TODO: Eliminar cuando las vistas hijas migren a Firebase (TAREAS 12-14)
    // Busca el usuario equivalente en SwiftData
    /// TODO: Eliminar cuando las vistas hijas migren a Firebase (TAREAS 12-14)
    private func loadSwiftDataUser() async {
        // Buscar por username (única propiedad compartida entre User y UserFS)
        let username = currentUser.username
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.username == username }
        )
        
        do {
            let users = try modelContext.fetch(descriptor)
            bridgedUser = users.first
            
            if bridgedUser == nil {
                print("⚠️ Usuario '\(username)' no encontrado en SwiftData")
            }
        } catch {
            print("❌ Error buscando usuario en SwiftData: \(error)")
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("MainTab - Firebase User") {
    let firebaseUser = UserFS(
        id: "preview-id",
        uid: "preview-uid",
        username: "programmer",
        fullName: "Admin User",
        email: "admin@ambukit.com",
        roleId: "role-programmer"
    )
    
    return MainTabView(currentUser: firebaseUser)
        .modelContainer(PreviewSupport.container)
        .environmentObject(AppState.shared)
}
#endif
