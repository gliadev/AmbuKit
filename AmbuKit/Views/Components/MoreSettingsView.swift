//
//  MoreMenuView.swift
//  AmbuKit
//
//  Created by Adolfo on 26/12/25.
//
//  TAREA 16.9: Menú "Más" con opciones de gestión
//  
//
//

import SwiftUI

// MARK: - More Menu View

struct MoreSettingsView: View {
    let currentUser: UserFS
    
    // Permisos (calculados en onAppear)
    @State private var canManageKits = false
    @State private var canManageBases = false
    @State private var canManageUsers = false
    @State private var canManageVehicles = false
    @State private var permissionsLoaded = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header del usuario
                    userHeader
                    
                    // Sección de Gestión (solo para usuarios con permisos)
                    if permissionsLoaded && (canManageKits || canManageBases || canManageUsers || canManageVehicles) {
                        managementSection
                    }
                    
                    // Sección de Usuario
                    userSection
                    
                    // Sección de App
                    appSection
                    
                    // Footer
                    appFooter
                }
                .padding()
            }
            .navigationTitle("Más")
            .task {
                await loadPermissions()
            }
        }
    }
    
    // MARK: - User Header
    
    private var userHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                Text(currentUser.fullName.prefix(1).uppercased())
                    .font(.title.bold())
                    .foregroundStyle(roleColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(currentUser.fullName)
                    .font(.title3.bold())
                Text("@\(currentUser.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let role = currentUser.role {
                    Text(role.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(roleColor.opacity(0.15))
                        .foregroundStyle(roleColor)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Management Section
    
    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gestión")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Gestión de Kits
                if canManageKits {
                    NavigationLink {
                        KitManagementView(currentUser: currentUser)
                    } label: {
                        MoreMenuCardView(
                            title: "Kits",
                            subtitle: "Crear, editar, umbrales",
                            icon: "cross.case.fill",
                            color: .blue
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Gestión de Bases
                if canManageBases {
                    NavigationLink {
                        BaseManagementView(currentUser: currentUser)
                    } label: {
                        MoreMenuCardView(
                            title: "Bases",
                            subtitle: "Crear, editar, eliminar",
                            icon: "building.2.fill",
                            color: .teal
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Gestión de Vehículos
                if canManageVehicles {
                    NavigationLink {
                        VehicleManagementView(currentUser: currentUser)
                    } label: {
                        MoreMenuCardView(
                            title: "Vehículos",
                            subtitle: "Crear, editar, asignar",
                            icon: "car.fill",
                            color: .green
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Gestión de Usuarios
                if canManageUsers {
                    NavigationLink {
                        UserManagementView(currentUser: currentUser)  // ✅ CORREGIDO
                    } label: {
                        MoreMenuCardView(
                            title: "Usuarios",
                            subtitle: "Crear, editar, roles",
                            icon: "person.2.fill",
                            color: .purple
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - User Section
    
    private var userSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mi Cuenta")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                NavigationLink {
                    ProfileView(currentUser: currentUser)
                } label: {
                    MoreMenuCardView(
                        title: "Mi Perfil",
                        subtitle: "Ver mis datos",
                        icon: "person.fill",
                        color: .indigo
                    )
                }
                .buttonStyle(.plain)
                
                // Ajustes (placeholder)
                MoreMenuCardDisabledView(
                    title: "Ajustes",
                    subtitle: "Próximamente",
                    icon: "gearshape.fill"
                )
            }
        }
    }
    
    // MARK: - App Section
    
    private var appSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aplicación")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Ayuda (placeholder)
                MoreMenuCardDisabledView(
                    title: "Ayuda",
                    subtitle: "Próximamente",
                    icon: "questionmark.circle.fill"
                )
                
                // Acerca de (placeholder)
                MoreMenuCardDisabledView(
                    title: "Acerca de",
                    subtitle: "Información",
                    icon: "info.circle.fill"
                )
            }
        }
    }
    
    // MARK: - App Footer
    
    private var appFooter: some View {
        VStack(spacing: 4) {
            Text("AmbuKit v1.0.0")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("TFG 2025 - Desarrollado por Adolfo")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Helpers
    
    private var roleColor: Color {
        guard let role = currentUser.role else { return .gray }
        switch role.kind {
        case .programmer: return .blue
        case .logistics: return .orange
        case .sanitary: return .green
        }
    }
    
    private func loadPermissions() async {
        // Cargar permisos del usuario
        let canCreateKits = await AuthorizationServiceFS.allowed(.create, on: .kit, for: currentUser)
        let canUpdateKits = await AuthorizationServiceFS.allowed(.update, on: .kit, for: currentUser)
        canManageKits = canCreateKits || canUpdateKits
        
        let canCreateBases = await AuthorizationServiceFS.allowed(.create, on: .base, for: currentUser)
        let canUpdateBases = await AuthorizationServiceFS.allowed(.update, on: .base, for: currentUser)
        canManageBases = canCreateBases || canUpdateBases
        
        canManageUsers = await AuthorizationServiceFS.allowed(.create, on: .user, for: currentUser)
        
        let canCreateVehicles = await AuthorizationServiceFS.allowed(.create, on: .vehicle, for: currentUser)
        let canUpdateVehicles = await AuthorizationServiceFS.allowed(.update, on: .vehicle, for: currentUser)
        canManageVehicles = canCreateVehicles || canUpdateVehicles
        
        permissionsLoaded = true
    }
}

// MARK: - More Menu Card View (nombre único para evitar conflictos)

struct MoreMenuCardView: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - More Menu Card Disabled View

struct MoreMenuCardDisabledView: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.gray)
            }
            
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(0.6)
    }
}

// MARK: - Preview

#Preview {
    let user = UserFS(
        id: "1", uid: "uid1", username: "admin",
        fullName: "Administrador", email: "admin@test.com",
        active: true, roleId: "role_programmer", baseId: nil
    )
    MoreSettingsView(currentUser: user)
}














































































