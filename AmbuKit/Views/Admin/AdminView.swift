//
//  AdminView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//  TAREA 16.5: Vista de administración - 100% Firebase
//
//  Secciones:
//  - Crear Kit (Programador + Logística)
//  - Crear Vehículo (Programador + Logística)
//  - Editar Umbrales (Programador + Logística)
//  - Gestión Usuarios (Solo Programador)
//  - Editar Umbrales (Programador + Logística)
//  - Gestión Usuarios (Solo Programador)
//

import SwiftUI

// MARK: - AdminView

/// Vista de administración - 100% Firebase
struct AdminView: View {

    // MARK: - Properties

    let currentUser: UserFS

    // MARK: - State

    @State private var canCreateKits = false
    @State private var canCreateVehicles = false
    @State private var canCreateBases = false
    @State private var canEditThresholds = false
    @State private var canManageUsers = false
    @State private var isLoading = true

    // MARK: - Body

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else {
                adminContent
            }
        }
        .navigationTitle("Gestión")
        .task {
            await loadPermissions()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        AdminLoadingView()
    }

    private var adminContent: some View {
        AdminContentView(
            currentUser: currentUser,
            canCreateKits: canCreateKits,
            canCreateVehicles: canCreateVehicles,
            canCreateBases: canCreateBases,
            canEditThresholds: canEditThresholds,
            canManageUsers: canManageUsers
        )
    }

    // MARK: - Load Permissions

    private func loadPermissions() async {
        // Cargar todos los permisos en paralelo
        async let kitsPermission = AuthorizationServiceFS.allowed(.create, on: .kit, for: currentUser)
        async let vehiclesPermission = AuthorizationServiceFS.allowed(.create, on: .vehicle, for: currentUser)
        async let basesPermission = AuthorizationServiceFS.allowed(.create, on: .base, for: currentUser)
        async let thresholdsPermission = AuthorizationServiceFS.allowed(.update, on: .kitItem, for: currentUser)
        async let usersPermission = AuthorizationServiceFS.allowed(.create, on: .user, for: currentUser)

        canCreateKits = await kitsPermission
        canCreateVehicles = await vehiclesPermission
        canCreateBases = await basesPermission
        canEditThresholds = await thresholdsPermission
        canManageUsers = await usersPermission

        isLoading = false
    }
}

// MARK: - AdminLoadingView

private struct AdminLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Cargando permisos...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AdminContentView

private struct AdminContentView: View {

    let currentUser: UserFS
    let canCreateKits: Bool
    let canCreateVehicles: Bool
    let canCreateBases: Bool
    let canEditThresholds: Bool
    let canManageUsers: Bool

    var body: some View {
        List {
            // Header con info del usuario
            userInfoHeader

            // Sección: Crear Kit
            if canCreateKits {
                createKitSection
            }

            // Sección: Crear Vehículo
            if canCreateVehicles {
                createVehicleSection
            }

            // Sección: Crear Base
            if canCreateBases {
                createBaseSection
            }

            // Sección: Editar Umbrales
            if canEditThresholds {
                thresholdsSection
            }

            // Sección: Gestión de Usuarios
            if canManageUsers {
                usersSection
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Role Color

    private var roleColor: Color {
        currentUser.role?.kind.color ?? .gray
    }

    // MARK: - User Info Header

    private var userInfoHeader: some View {
        Section {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(roleColor.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Text(currentUser.fullName.prefix(1).uppercased())
                        .font(.title2.bold())
                        .foregroundStyle(roleColor)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentUser.fullName)
                        .font(.headline)

                    Text("@\(currentUser.username)")
                        .font(.caption)
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

                // Permisos badge
                VStack(alignment: .trailing, spacing: 2) {
                    let count = [canCreateKits, canCreateVehicles, canCreateBases, canEditThresholds, canManageUsers].count(where: { $0 })
                    Text("\(count)")
                        .font(.title2.bold())
                        .foregroundStyle(roleColor)
                    Text("permisos")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Create Kit Section

    private var createKitSection: some View {
        Section {
            // Crear Kit
            NavigationLink {
                CreateKitScreen(currentUser: currentUser)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "cross.case.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Crear Kit")
                            .font(.headline)
                        Text("Añadir nuevo kit al sistema")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
            }

            // ✅ NUEVO: Editar Kits
            NavigationLink {
                KitManagementView(currentUser: currentUser)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Editar Kits")
                            .font(.headline)
                        Text("Modificar o eliminar kits")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Label("Kits", systemImage: "shippingbox.fill")
        }
    }

    // MARK: - Create Vehicle Section

    private var createVehicleSection: some View {
        Section {
            // Crear Vehículo
            NavigationLink {
                CreateVehicleScreen(currentUser: currentUser)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "car.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Crear Vehículo")
                            .font(.headline)
                        Text("Registrar nueva ambulancia")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            // ✅ NUEVO: Editar Vehículos
            NavigationLink {
                VehicleManagementView(currentUser: currentUser)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Editar Vehículos")
                            .font(.headline)
                        Text("Modificar o eliminar vehículos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Label("Vehículos", systemImage: "car.2.fill")
        }
    }

    // MARK: - Create Base Section

    private var createBaseSection: some View {
        Section {
            // Crear Base
            NavigationLink {
                CreateBaseScreen(currentUser: currentUser)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.teal.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "building.2.fill")
                            .font(.title3)
                            .foregroundStyle(.teal)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Crear Base")
                            .font(.headline)
                        Text("Añadir nueva estación/sede")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.teal)
                }
            }

            // ✅ NUEVO: Editar Bases
            NavigationLink {
                BaseManagementView(currentUser: currentUser)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.teal.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.teal)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Editar Bases")
                            .font(.headline)
                        Text("Modificar o eliminar bases")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Label("Bases", systemImage: "building.fill")
        }
    }

    // MARK: - Thresholds Section

    private var thresholdsSection: some View {
        Section {
            NavigationLink {
                ThresholdsListScreen(currentUser: currentUser)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Editar Umbrales")
                            .font(.headline)
                        Text("Configurar mín/máx de items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Configuración", systemImage: "gearshape.fill")
        }
    }

    // MARK: - Users Section

    private var usersSection: some View {
        Section {
            NavigationLink {
                UserManagementView(currentUser: currentUser)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "person.2.fill")
                            .font(.title3)
                            .foregroundStyle(.purple)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gestión de Usuarios")
                            .font(.headline)
                        Text("Crear, editar y eliminar usuarios")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Usuarios", systemImage: "person.fill")
        } footer: {
            Text("Solo disponible para Programadores")
                .font(.caption2)
        }
    }
}

// MARK: - Preview

#Preview("Programmer") {
    var user = UserFS(
        id: "1", uid: "uid1", username: "admin",
        fullName: "Admin User", email: "admin@test.com",
        active: true, roleId: "role_programmer", baseId: nil
    )
    user.role = RoleFS(id: "role_programmer", kind: .programmer, displayName: "Programador")

    return AdminView(currentUser: user)
}

#Preview("Logistics") {
    var user = UserFS(
        id: "2", uid: "uid2", username: "logistica",
        fullName: "Logística User", email: "log@test.com",
        active: true, roleId: "role_logistics", baseId: nil
    )
    user.role = RoleFS(id: "role_logistics", kind: .logistics, displayName: "Logística")

    return AdminView(currentUser: user)
}
