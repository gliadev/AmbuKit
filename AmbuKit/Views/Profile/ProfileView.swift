//
//  ProfileView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

struct ProfileView: View {
    
    // MARK: - Properties
    
    let currentUser: UserFS  // ← Firebase (antes: User SwiftData)
    
    // MARK: - Environment
    
    @EnvironmentObject private var appState: AppState
    
    // MARK: - State - Datos relacionados
    
    @State private var role: RoleFS?
    @State private var base: BaseFS?
    @State private var policies: [PolicyFS] = []
    
    // MARK: - State - UI
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingLogoutConfirmation = false
    @State private var isLoggingOut = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(message: error)
                } else {
                    profileContent
                }
            }
            .navigationTitle("Perfil")
            .task {
                await loadData()
            }
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
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Cargando perfil...")
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
                Task { await loadData() }
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Profile Content
    
    private var profileContent: some View {
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
                        
                        if let role = role {
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
            Section("Detalles") {
                LabeledContent("Email", value: currentUser.email)
                
                if let base = base {
                    LabeledContent("Base", value: base.name)
                } else {
                    LabeledContent("Base", value: "Sin asignar")
                }
                
                LabeledContent("Estado") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(currentUser.active ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(currentUser.active ? "Activo" : "Inactivo")
                            .foregroundStyle(currentUser.active ? .green : .red)
                    }
                }
            }
            
            // MARK: Role Section
            if let role = role {
                Section("Rol") {
                    LabeledContent("Rol", value: role.displayName)
                }
            }
            
            // MARK: Permissions Section
            if let role = role {
                Section("Permisos") {
                    if role.kind == .programmer {
                        PermissionRow(
                            icon: "checkmark.circle.fill",
                            text: "Acceso total a todas las funciones",
                            color: .green
                        )
                    } else if policies.isEmpty {
                        Text("Sin permisos específicos configurados")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(policies) { policy in
                            PermissionRow(
                                icon: policy.canUpdate ? "checkmark.circle.fill" : "xmark.circle.fill",
                                text: policy.entity.rawValue.capitalized,
                                color: policy.canUpdate ? .green : .red
                            )
                        }
                    }
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
                            Text("Cerrando sesión...")
                        } else {
                            Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                .disabled(isLoggingOut)
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        // Cargar rol y base en paralelo
        async let roleTask = PolicyService.shared.getRole(id: currentUser.roleId)
        async let baseTask: BaseFS? = await loadBase()
        
        role = await roleTask
        base = await baseTask
        
        // Cargar políticas si el rol existe y NO es Programador
        // (Programador tiene acceso total, no necesita políticas específicas)
        if let loadedRole = role, loadedRole.kind != .programmer {
            policies = await PolicyService.shared.getPolicies(roleId: loadedRole.id ?? "")
        }
        
        // Verificar si hubo error crítico (sin rol)
        if role == nil && currentUser.roleId != nil {
            errorMessage = "No se pudo cargar la información del rol"
        }
        
        isLoading = false
    }
    
    /// Carga la base del usuario si tiene baseId asignado
    private func loadBase() async -> BaseFS? {
        guard let baseId = currentUser.baseId else { return nil }
        return await BaseService.shared.getBase(id: baseId)
    }
    
    // MARK: - Actions
    
    private func handleLogout() async {
        isLoggingOut = true
        
        // Usar AppState.signOut() - NO FirebaseAuthService directamente
        // AppState gestiona el estado y RootView detectará el cambio automáticamente
        await appState.signOut()
        
        // Si hay error, AppState lo maneja internamente vía @Published currentError
        // No necesitamos hacer nada más aquí
        
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
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Programador") {
    let testUser = UserFS(
        id: "user_prog",
        uid: "firebase_uid_prog",
        username: "admin",
        fullName: "Juan Programador",
        email: "admin@ambukit.com",
        active: true,
        roleId: "role_programmer",
        baseId: "base_bilbao"
    )
    
    return NavigationStack {
        ProfileView(currentUser: testUser)
            .environmentObject(AppState.shared)
    }
}

#Preview("Logística") {
    let testUser = UserFS(
        id: "user_log",
        uid: "firebase_uid_log",
        username: "logistica",
        fullName: "María Logística",
        email: "logistica@ambukit.com",
        active: true,
        roleId: "role_logistics",
        baseId: "base_bilbao"
    )
    
    return NavigationStack {
        ProfileView(currentUser: testUser)
            .environmentObject(AppState.shared)
    }
}

#Preview("Sanitario sin base") {
    let testUser = UserFS(
        id: "user_san",
        uid: "firebase_uid_san",
        username: "sanitario",
        fullName: "Pedro Sanitario",
        email: "sanitario@ambukit.com",
        active: true,
        roleId: "role_sanitary",
        baseId: nil  // Sin base asignada
    )
    
    return NavigationStack {
        ProfileView(currentUser: testUser)
            .environmentObject(AppState.shared)
    }
}
#endif
