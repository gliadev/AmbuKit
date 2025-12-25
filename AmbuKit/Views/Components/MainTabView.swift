//
//  MainTabView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//


import SwiftUI

/// Vista principal con tabs para usuarios autenticados
///
/// **Estado de Migración (TAREA 14 completada):**
/// - ✅ InventoryView: Usa UserFS (Firebase)
/// - ✅ AdminView: Usa UserFS (Firebase)
/// - ✅ ProfileView: Usa UserFS (Firebase)
struct MainTabView: View {
    
    // MARK: - Properties
    
    let currentUser: UserFS  // ✅ Firebase (NO User SwiftData)
    
    // MARK: - Environment
    
    @EnvironmentObject private var appState: AppState
    
    // MARK: - State
    
    /// Usuario enriquecido con datos relacionados (role, base)
    @State private var enrichedUser: UserFS?
    
    /// Mostrar tab de administración
    @State private var showAdminTab = false
    
    /// Estado de carga de permisos
    @State private var isLoadingPermissions = true
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoadingPermissions {
                loadingView
            } else {
                mainTabContent
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
    
    // MARK: - Main Tab Content
    
    @ViewBuilder
    private var mainTabContent: some View {
        let user = enrichedUser ?? currentUser
        
        TabView {
            // Tab: Inventario - ✅ UserFS
            InventoryView(currentUser: user)
                .tabItem {
                    Label("Inventario", systemImage: "shippingbox")
                }
            
            // Tab: Gestión - ✅ UserFS
            if showAdminTab {
                AdminView(currentUser: user)
                    .tabItem {
                        Label("Gestión", systemImage: "gearshape")
                    }
            }
            
            // Tab: Perfil - ✅ UserFS (TAREA 14)
            ProfileView(currentUser: user)
                .tabItem {
                    Label("Perfil", systemImage: "person")
                }
        }
    }
    
    // MARK: - Setup
    
    private func setup() async {
        isLoadingPermissions = true
        
        // 1. Cargar datos relacionados (role, base)
        await loadRelatedData()
        
        // 2. Calcular permisos
        await loadPermissions()
        
        isLoadingPermissions = false
    }
    
    // MARK: - Load Related Data
    
    private func loadRelatedData() async {
        var user = currentUser
        
        // Cargar Role si tiene roleId
        if let roleId = currentUser.roleId {
            if let role = await PolicyService.shared.getRole(id: roleId) {
                user.role = role
                #if DEBUG
                print("📋 Role cargado: \(role.displayName)")
                #endif
            }
        }
        
        // Cargar Base si tiene baseId
        if let baseId = currentUser.baseId {
            if let base = await BaseService.shared.getBase(id: baseId) {
                user.base = base
                #if DEBUG
                print("🏥 Base cargada: \(base.name)")
                #endif
            }
        }
        
        enrichedUser = user
    }
    
    // MARK: - Load Permissions
    
    private func loadPermissions() async {
        let user = enrichedUser ?? currentUser
        
        // Verificar permisos de administración
        let canCreateKits = await AuthorizationServiceFS.allowed(.create, on: .kit, for: user)
        let canManageUsers = await AuthorizationServiceFS.allowed(.create, on: .user, for: user)
        let canUpdateUsers = await AuthorizationServiceFS.allowed(.update, on: .user, for: user)
        let canDeleteUsers = await AuthorizationServiceFS.allowed(.delete, on: .user, for: user)
        let canEditThresholds = await AuthorizationServiceFS.canEditThresholds(user)
        
        // Mostrar tab de admin si tiene algún permiso de gestión
        showAdminTab = canCreateKits || canEditThresholds || canManageUsers || canUpdateUsers || canDeleteUsers
        
        #if DEBUG
        print("📋 Permisos para @\(user.username):")
        print("   - showAdminTab: \(showAdminTab)")
        #endif
    }
}

// MARK: - Preview

#Preview("MainTabView - Programmer") {
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
    
    return MainTabView(currentUser: testUser)
        .environmentObject(AppState.shared)
}

#Preview("MainTabView - Logistics") {
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
    
    return MainTabView(currentUser: testUser)
        .environmentObject(AppState.shared)
}

#Preview("MainTabView - Sanitary") {
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
    
    return MainTabView(currentUser: testUser)
        .environmentObject(AppState.shared)
}
