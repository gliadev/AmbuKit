//
//  ProfileView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

struct ProfileView: View {
    
    // MARK: - Properties
    
    let currentUser: UserFS
    
    // MARK: - Environment
    
    @EnvironmentObject private var appState: AppState
    
    // MARK: - State
    
    @State private var showingLogoutConfirmation = false
    @State private var isLoggingOut = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: User Info Section
                userInfoSection
                
                // MARK: Details Section
                detailsSection
                
                // MARK: Permissions Section
                if let role = currentUser.role {
                    permissionsSection(role: role)
                }
                
                // MARK: Actions Section
                actionsSection
            }
            .navigationTitle("Perfil")
            .confirmationDialog(
                "¿Cerrar sesión?",
                isPresented: $showingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cerrar Sesión", role: .destructive) {
                    Task { await handleLogout() }
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Se cerrará tu sesión y volverás a la pantalla de inicio")
            }
        }
    }
    
    // MARK: - User Info Section
    
    private var userInfoSection: some View {
        Section {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(roleColor.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Text(currentUser.fullName.prefix(1).uppercased())
                        .font(.title.bold())
                        .foregroundStyle(roleColor)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentUser.fullName)
                        .font(.headline)
                    
                    Text("@\(currentUser.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let role = currentUser.role {
                        Text(role.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(roleColor.opacity(0.15))
                            .foregroundStyle(roleColor)
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        } header: {
            Text("Información del usuario")
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        Section {
            // Email
            HStack {
                Label("Email", systemImage: "envelope.fill")
                Spacer()
                Text(currentUser.email)
                    .foregroundStyle(.secondary)
            }
            
            // Base
            HStack {
                Label("Base", systemImage: "building.fill")
                Spacer()
                if let base = currentUser.base {
                    Text(base.name)
                        .foregroundStyle(.green)
                } else {
                    Text("Sin asignar")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Estado
            HStack {
                Label("Estado", systemImage: "circle.fill")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(currentUser.active ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(currentUser.active ? "Activo" : "Inactivo")
                        .foregroundStyle(currentUser.active ? .green : .red)
                }
            }
        } header: {
            Text("Detalles")
        }
    }
    
    // MARK: - Permissions Section
    
    private func permissionsSection(role: RoleFS) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                if role.kind == .programmer {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        Text("Acceso total a todas las funciones")
                            .font(.subheadline)
                    }
                } else if role.kind == .logistics {
                    VStack(alignment: .leading, spacing: 8) {
                        PermissionRow(icon: "checkmark.circle.fill", text: "Crear kits y vehículos", color: .green)
                        PermissionRow(icon: "checkmark.circle.fill", text: "Editar umbrales", color: .green)
                        PermissionRow(icon: "checkmark.circle.fill", text: "Actualizar stock", color: .green)
                        PermissionRow(icon: "xmark.circle.fill", text: "Gestionar usuarios", color: .red)
                    }
                } else if role.kind == .sanitary {
                    VStack(alignment: .leading, spacing: 8) {
                        PermissionRow(icon: "checkmark.circle.fill", text: "Ver inventario", color: .green)
                        PermissionRow(icon: "checkmark.circle.fill", text: "Actualizar stock", color: .green)
                        PermissionRow(icon: "xmark.circle.fill", text: "Crear kits/vehículos", color: .red)
                        PermissionRow(icon: "xmark.circle.fill", text: "Editar umbrales", color: .red)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Permisos del rol")
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Section {
            Button(role: .destructive) {
                showingLogoutConfirmation = true
            } label: {
                HStack {
                    if isLoggingOut {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .disabled(isLoggingOut)
        }
    }
    
    // MARK: - Helpers
    
    private var roleColor: Color {
        guard let role = currentUser.role else { return .blue }
        switch role.kind {
        case .programmer: return .blue
        case .logistics: return .orange
        case .sanitary: return .green
        }
    }
    
    // MARK: - Actions
    
    private func handleLogout() async {
        isLoggingOut = true
        await appState.signOut()
        isLoggingOut = false
    }
}

// MARK: - Permission Row Component

private struct PermissionRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview

#Preview("Profile - Programmer") {
    var user = UserFS(
        id: "1", uid: "uid1", username: "admin",
        fullName: "Admin User", email: "admin@ambukit.com",
        active: true, roleId: "role_programmer", baseId: nil
    )
    user.role = RoleFS(id: "role_programmer", kind: .programmer, displayName: "Programador")
    
    return ProfileView(currentUser: user)
        .environmentObject(AppState.shared)
}

#Preview("Profile - Logistics") {
    var user = UserFS(
        id: "2", uid: "uid2", username: "logistica",
        fullName: "Logística User", email: "log@ambukit.com",
        active: true, roleId: "role_logistics", baseId: nil
    )
    user.role = RoleFS(id: "role_logistics", kind: .logistics, displayName: "Logística")
    
    return ProfileView(currentUser: user)
        .environmentObject(AppState.shared)
}

#Preview("Profile - Sanitary") {
    var user = UserFS(
        id: "3", uid: "uid3", username: "sanitario",
        fullName: "Sanitario User", email: "san@ambukit.com",
        active: true, roleId: "role_sanitary", baseId: nil
    )
    user.role = RoleFS(id: "role_sanitary", kind: .sanitary, displayName: "Sanitario")
    
    return ProfileView(currentUser: user)
        .environmentObject(AppState.shared)
}
