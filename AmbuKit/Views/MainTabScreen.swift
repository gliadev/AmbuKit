//
//  MainTabScreen.swift
//  AmbuKit
//
//  Created by Adolfo on 3/12/25.
//


import SwiftUI

/// Vista principal con tabs para usuarios autenticados (Firebase)
///
/// **Responsabilidades:**
/// - Recibir UserFS de Firebase
/// - Cargar datos relacionados (Role, Base)
/// - Calcular permisos usando AuthorizationServiceFS
/// - Mostrar tabs según permisos del usuario
///
/// **Estado de Migración (TAREA 14 completada):**
/// - ✅ InventoryView: Usa UserFS (Firebase) - TAREA 12
/// - ✅ AdminView: Usa UserFS (Firebase) - TAREA 13
/// - ✅ ProfileView: Usa UserFS (Firebase) - TAREA 14
struct MainTabScreen: View {
    
    // MARK: - Properties
    
    let currentUser: UserFS
    
    // MARK: - Environment
    
    @EnvironmentObject private var appState: AppState
    
    // MARK: - State
    
    /// Usuario enriquecido con datos relacionados cargados
    @State private var enrichedUser: UserFS?
    
    /// Estado de carga
    @State private var isLoading = true
    
    /// Error de carga
    @State private var loadError: String?
    
    /// Mostrar tab de administración
    @State private var showAdminTab = false
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = loadError {
                errorView(message: error)
            } else {
                mainTabContent(user: enrichedUser ?? currentUser)
            }
        }
        .task {
            await setup()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.blue)
            
            Text("Preparando interfaz...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Reintentar") {
                Task { await setup() }
            }
            .buttonStyle(.bordered)
            
            Button("Cerrar sesión", role: .destructive) {
                Task { await appState.signOut() }
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Main Tab Content
    
    /// Contenido principal de tabs
    ///
    /// **TAREA 14 Completada:**
    /// Todas las vistas ahora usan UserFS (Firebase) directamente.
    /// Ya no hay bridge con SwiftData.
    @ViewBuilder
    private func mainTabContent(user: UserFS) -> some View {
        TabView {
            // Tab: Inventario - ✅ UserFS (Firebase)
            InventoryView(currentUser: user)
                .tabItem {
                    Label("Inventario", systemImage: "shippingbox")
                }
            
            // Tab: Gestión - ✅ UserFS (Firebase)
            if showAdminTab {
                AdminView(currentUser: user)
                    .tabItem {
                        Label("Gestión", systemImage: "gearshape")
                    }
            }
            
            // Tab: Perfil - ✅ UserFS (Firebase) - ACTUALIZADO EN TAREA 14
            ProfileView(currentUser: user)
                .tabItem {
                    Label("Perfil", systemImage: "person")
                }
        }
    }
    
    // MARK: - Setup
    
    /// Configura la vista cargando datos relacionados y calculando permisos
    private func setup() async {
        isLoading = true
        loadError = nil
        
        // 1. Cargar datos relacionados (role, base)
        await loadRelatedData()
        
        // 2. Calcular permisos usando AuthorizationServiceFS
        await calculatePermissions()
        
        print("✅ MainTabScreen configurado correctamente")
        
        isLoading = false
    }
    
    // MARK: - Load Related Data
    
    /// Carga los datos relacionados del usuario (role, base) desde Firestore
    private func loadRelatedData() async {
        var user = currentUser
        
        // Cargar Role si tiene roleId
        if let roleId = currentUser.roleId {
            if let role = await PolicyService.shared.getRole(id: roleId) {
                user.role = role
                print("📋 Role cargado: \(role.displayName) (\(role.kind.rawValue))")
            } else {
                print("⚠️ Role no encontrado: \(roleId)")
            }
        }
        
        // Cargar Base si tiene baseId
        if let baseId = currentUser.baseId {
            if let base = await BaseService.shared.getBase(id: baseId) {
                user.base = base
                print("🏥 Base cargada: \(base.name)")
            } else {
                print("⚠️ Base no encontrada: \(baseId)")
            }
        }
        
        enrichedUser = user
    }
    
    // MARK: - Calculate Permissions
    
    /// Calcula los permisos del usuario usando AuthorizationServiceFS
    private func calculatePermissions() async {
        let user = enrichedUser ?? currentUser
        
        // Verificar permisos de administración
        let canCreateKits = await AuthorizationServiceFS.allowed(.create, on: .kit, for: user)
        let canManageUsers = await AuthorizationServiceFS.allowed(.create, on: .user, for: user)
        let canUpdateUsers = await AuthorizationServiceFS.allowed(.update, on: .user, for: user)
        let canDeleteUsers = await AuthorizationServiceFS.allowed(.delete, on: .user, for: user)
        
        // Verificar si puede editar umbrales (programmer o logistics)
        let canEditThresholds = await AuthorizationServiceFS.canEditThresholds(user)
        
        // Mostrar tab de admin si tiene algún permiso de gestión
        showAdminTab = canCreateKits || canEditThresholds || canManageUsers || canUpdateUsers || canDeleteUsers
        
        #if DEBUG
        print("📋 Permisos calculados para @\(user.username):")
        print("   - Rol: \(user.role?.kind.rawValue ?? "sin rol")")
        print("   - canCreateKits: \(canCreateKits)")
        print("   - canEditThresholds: \(canEditThresholds)")
        print("   - canManageUsers: \(canManageUsers)")
        print("   - showAdminTab: \(showAdminTab)")
        #endif
    }
}

// MARK: - Preview

#Preview("MainTabScreen - Programmer") {
    var testUser = UserFS(
        id: "test_id",
        uid: "test_uid",
        username: "programmer",
        fullName: "Test Programmer",
        email: "programmer@test.com",
        active: true,
        roleId: "role_programmer",
        baseId: nil
    )
    testUser.role = RoleFS(
        id: "role_programmer",
        kind: .programmer,
        displayName: "Programador"
    )
    
    return MainTabScreen(currentUser: testUser)
        .environmentObject(AppState.shared)
}

#Preview("MainTabScreen - Logistics") {
    var testUser = UserFS(
        id: "test_id",
        uid: "test_uid",
        username: "logistica",
        fullName: "Test Logística",
        email: "logistica@test.com",
        active: true,
        roleId: "role_logistics",
        baseId: nil
    )
    testUser.role = RoleFS(
        id: "role_logistics",
        kind: .logistics,
        displayName: "Logística"
    )
    
    return MainTabScreen(currentUser: testUser)
        .environmentObject(AppState.shared)
}

#Preview("MainTabScreen - Sanitary") {
    var testUser = UserFS(
        id: "test_id",
        uid: "test_uid",
        username: "sanitario",
        fullName: "Test Sanitario",
        email: "sanitario@test.com",
        active: true,
        roleId: "role_sanitary",
        baseId: nil
    )
    testUser.role = RoleFS(
        id: "role_sanitary",
        kind: .sanitary,
        displayName: "Sanitario"
    )
    
    return MainTabScreen(currentUser: testUser)
        .environmentObject(AppState.shared)
}
