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
                AdminLoadingView()
            } else {
                AdminContentView(
                    currentUser: currentUser,
                    canCreateKits: canCreateKits,
                    canCreateVehicles: canCreateVehicles,
                    canCreateBases: canCreateBases,
                    canEditThresholds: canEditThresholds,
                    canManageUsers: canManageUsers
                )
            }
        }
        .navigationTitle("Gestión")
        .task {
            await loadPermissions()
        }
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
            AdminUserInfoHeader(
                currentUser: currentUser,
                permissionCount: [
                    canCreateKits,
                    canCreateVehicles,
                    canCreateBases,
                    canEditThresholds,
                    canManageUsers
                ].count(where: { $0 })
            )

            if canCreateKits {
                AdminCreateKitSection(currentUser: currentUser)
            }

            if canCreateVehicles {
                AdminCreateVehicleSection(currentUser: currentUser)
            }

            if canCreateBases {
                AdminCreateBaseSection(currentUser: currentUser)
            }

            if canEditThresholds {
                AdminThresholdsSection(currentUser: currentUser)
            }

            if canManageUsers {
                AdminUsersSection(currentUser: currentUser)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - AdminUserInfoHeader

private struct AdminUserInfoHeader: View {
    let currentUser: UserFS
    let permissionCount: Int

    private var roleColor: Color {
        currentUser.role?.kind.color ?? .gray
    }

    var body: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(roleColor.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Text(currentUser.fullName.prefix(1).uppercased())
                        .font(.title2.bold())
                        .foregroundStyle(roleColor)
                }

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

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(permissionCount)")
                        .font(.title2.bold())
                        .foregroundStyle(roleColor)
                    Text("permisos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - AdminMenuRow

private struct AdminMenuRow<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let trailingIcon: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if trailingIcon == "chevron.right" {
                    Image(systemName: trailingIcon)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: trailingIcon)
                        .foregroundStyle(color)
                }
            }
        }
    }
}

// MARK: - AdminCreateKitSection

private struct AdminCreateKitSection: View {
    let currentUser: UserFS

    var body: some View {
        Section {
            AdminMenuRow(
                title: "Crear Kit",
                subtitle: "Añadir nuevo kit al sistema",
                icon: "cross.case.fill",
                color: .blue,
                trailingIcon: "plus.circle.fill"
            ) {
                CreateKitScreen(currentUser: currentUser)
            }

            AdminMenuRow(
                title: "Editar Kits",
                subtitle: "Modificar o eliminar kits",
                icon: "pencil.circle.fill",
                color: .blue,
                trailingIcon: "chevron.right"
            ) {
                KitManagementView(currentUser: currentUser)
            }
        } header: {
            Label("Kits", systemImage: "shippingbox.fill")
        }
    }
}

// MARK: - AdminCreateVehicleSection

private struct AdminCreateVehicleSection: View {
    let currentUser: UserFS

    var body: some View {
        Section {
            AdminMenuRow(
                title: "Crear Vehículo",
                subtitle: "Registrar nueva ambulancia",
                icon: "car.fill",
                color: .green,
                trailingIcon: "plus.circle.fill"
            ) {
                CreateVehicleScreen(currentUser: currentUser)
            }

            AdminMenuRow(
                title: "Editar Vehículos",
                subtitle: "Modificar o eliminar vehículos",
                icon: "pencil.circle.fill",
                color: .green,
                trailingIcon: "chevron.right"
            ) {
                VehicleManagementView(currentUser: currentUser)
            }
        } header: {
            Label("Vehículos", systemImage: "car.2.fill")
        }
    }
}

// MARK: - AdminCreateBaseSection

private struct AdminCreateBaseSection: View {
    let currentUser: UserFS

    var body: some View {
        Section {
            AdminMenuRow(
                title: "Crear Base",
                subtitle: "Añadir nueva estación/sede",
                icon: "building.2.fill",
                color: .teal,
                trailingIcon: "plus.circle.fill"
            ) {
                CreateBaseScreen(currentUser: currentUser)
            }

            AdminMenuRow(
                title: "Editar Bases",
                subtitle: "Modificar o eliminar bases",
                icon: "pencil.circle.fill",
                color: .teal,
                trailingIcon: "chevron.right"
            ) {
                BaseManagementView(currentUser: currentUser)
            }
        } header: {
            Label("Bases", systemImage: "building.fill")
        }
    }
}

// MARK: - AdminThresholdsSection

private struct AdminThresholdsSection: View {
    let currentUser: UserFS

    var body: some View {
        Section {
            AdminMenuRow(
                title: "Editar Umbrales",
                subtitle: "Configurar mín/máx de items",
                icon: "slider.horizontal.3",
                color: .orange,
                trailingIcon: "chevron.right"
            ) {
                ThresholdsListScreen(currentUser: currentUser)
            }
        } header: {
            Label("Configuración", systemImage: "gearshape.fill")
        }
    }
}

// MARK: - AdminUsersSection

private struct AdminUsersSection: View {
    let currentUser: UserFS

    var body: some View {
        Section {
            AdminMenuRow(
                title: "Gestión de Usuarios",
                subtitle: "Crear, editar y eliminar usuarios",
                icon: "person.2.fill",
                color: .purple,
                trailingIcon: "chevron.right"
            ) {
                UserManagementView(currentUser: currentUser)
            }
        } header: {
            Label("Usuarios", systemImage: "person.fill")
        } footer: {
            Text("Solo disponible para Programadores")
                .font(.caption)
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
