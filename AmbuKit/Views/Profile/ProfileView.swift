//
//  ProfileView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//



import SwiftUI
import SwiftData

struct ProfileView: View {
    
    // MARK: - Properties
    let currentUser: User
    
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
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(currentUser.fullName)
                                .font(.headline)
                            
                            Text("@\(currentUser.username)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            if let role = currentUser.role {
                                RoleBadgeView(role: role.kind)
                                    .padding(.top, 4)
                            }
                        }
                        
                        Spacer()
                        
                        // Avatar placeholder
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.blue)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Información del usuario")
                }
                
                // MARK: Details Section
                Section {
                    if let base = currentUser.base {
                        LabeledContent("Base", value: base.name)
                    }
                    
                    LabeledContent("Estado") {
                        HStack {
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
                
                // MARK: Permissions Section (Optional)
                if let role = currentUser.role {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Permisos según rol: \(role.displayName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            if role.kind == .programmer {
                                PermissionRow(
                                    icon: "checkmark.circle.fill",
                                    text: "Acceso total a todas las funciones",
                                    color: .green
                                )
                            } else {
                                ForEach(role.policies, id: \.entity) { policy in
                                    PermissionRow(
                                        icon: policy.canUpdate ? "checkmark.circle.fill" : "xmark.circle.fill",
                                        text: policy.entity.rawValue.capitalized,
                                        color: policy.canUpdate ? .green : .red
                                    )
                                }
                            }
                        }
                    } header: {
                        Text("Permisos")
                    }
                }
                
                // MARK: Actions Section
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
    NavigationStack {
        ProfileView(currentUser: PreviewSupport.user("programmer"))
            .environmentObject(AppState.shared)
    }
    .modelContainer(PreviewSupport.container)
}

#Preview("Profile - Logistics") {
    NavigationStack {
        ProfileView(currentUser: PreviewSupport.user("logistics"))
            .environmentObject(AppState.shared)
    }
    .modelContainer(PreviewSupport.container)
}
