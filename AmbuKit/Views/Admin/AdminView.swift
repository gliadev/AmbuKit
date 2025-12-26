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
    @State private var canEditThresholds = false
    @State private var canManageUsers = false
    @State private var isLoading = true
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else {
                    adminContent
                }
            }
            .navigationTitle("Gestión")
        }
        .task {
            await loadPermissions()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Cargando permisos...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Admin Content
    
    private var adminContent: some View {
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
                    let count = [canCreateKits, canCreateVehicles, canEditThresholds, canManageUsers].filter { $0 }.count
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
        } header: {
            Label("Kits", systemImage: "shippingbox.fill")
        }
    }
    
    // MARK: - Create Vehicle Section
    
    private var createVehicleSection: some View {
        Section {
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
        } header: {
            Label("Vehículos", systemImage: "car.2.fill")
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
                UsersListScreen(currentUser: currentUser)
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
    
    // MARK: - Helpers
    
    private var roleColor: Color {
        guard let role = currentUser.role else { return .blue }
        switch role.kind {
        case .programmer: return .blue
        case .logistics: return .orange
        case .sanitary: return .green
        }
    }
    
    // MARK: - Load Permissions
    
    private func loadPermissions() async {
        isLoading = true
        
        async let kits = AuthorizationServiceFS.canCreateKits(currentUser)
        async let vehicles = AuthorizationServiceFS.canCreateVehicles(currentUser)
        async let thresholds = AuthorizationServiceFS.canEditThresholds(currentUser)
        async let users = AuthorizationServiceFS.canManageUsers(currentUser)
        
        canCreateKits = await kits
        canCreateVehicles = await vehicles
        canEditThresholds = await thresholds
        canManageUsers = await users
        
        isLoading = false
    }
}

// MARK: - Create Kit Screen

struct CreateKitScreen: View {
    let currentUser: UserFS
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var code = ""
    @State private var name = ""
    @State private var selectedType: KitType = .SVB
    @State private var vehicles: [VehicleFS] = []
    @State private var selectedVehicleId: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    var body: some View {
        Form {
            Section {
                TextField("Código (ej: KIT-SVA-001)", text: $code)
                    .textInputAutocapitalization(.characters)
                
                TextField("Nombre del kit", text: $name)
                
                Picker("Tipo de kit", selection: $selectedType) {
                    ForEach(KitType.allCases) { type in
                        Label(type.rawValue, systemImage: iconFor(type))
                            .tag(type)
                    }
                }
                
                Picker("Vehículo", selection: $selectedVehicleId) {
                    Text("— Sin asignar —").tag(String?.none)
                    ForEach(vehicles) { v in
                        Text("\(v.code) - \(v.plate ?? "Sin matrícula")")
                            .tag(Optional(v.id))
                    }
                }
            } header: {
                Text("Datos del Kit")
            }
            
            Section {
                Button {
                    Task { await createKit() }
                } label: {
                    HStack {
                        Spacer()
                        if isProcessing {
                            ProgressView()
                        } else {
                            Label("Crear Kit", systemImage: "plus.circle.fill")
                        }
                        Spacer()
                    }
                }
                .disabled(code.isEmpty || name.isEmpty || isProcessing)
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Nuevo Kit")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vehicles = await VehicleService.shared.getAllVehicles()
        }
        .alert("Kit Creado", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("El kit '\(name)' se ha creado correctamente.")
        }
    }
    
    private func createKit() async {
        isProcessing = true
        errorMessage = nil
        
        do {
            _ = try await KitService.shared.createKit(
                code: code,
                name: name,
                type: selectedType,
                vehicleId: selectedVehicleId,
                actor: currentUser
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    /// Icono para cada tipo de kit (solo los que existen en KitType)
    private func iconFor(_ type: KitType) -> String {
        switch type {
        case .SVA: return "cross.case.fill"
        case .SVAe: return "cross.case.fill"
        case .SVB: return "shippingbox.fill"
        case .custom: return "star.fill"
        }
    }
}

// MARK: - Create Vehicle Screen

struct CreateVehicleScreen: View {
    let currentUser: UserFS
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var code = ""
    @State private var plate = ""
    @State private var selectedType: VehicleFS.VehicleType = .svb
    @State private var bases: [BaseFS] = []
    @State private var selectedBaseId: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    var body: some View {
        Form {
            Section {
                TextField("Código (ej: AMB-001)", text: $code)
                    .textInputAutocapitalization(.characters)
                
                TextField("Matrícula", text: $plate)
                    .textInputAutocapitalization(.characters)
                
                Picker("Tipo", selection: $selectedType) {
                    ForEach(VehicleFS.VehicleType.allCases, id: \.self) { type in
                        Text(type.shortName).tag(type)
                    }
                }
                
                Picker("Base", selection: $selectedBaseId) {
                    Text("— Sin asignar —").tag(String?.none)
                    ForEach(bases) { base in
                        Text(base.name).tag(Optional(base.id))
                    }
                }
            } header: {
                Text("Datos del Vehículo")
            }
            
            Section {
                Button {
                    Task { await createVehicle() }
                } label: {
                    HStack {
                        Spacer()
                        if isProcessing {
                            ProgressView()
                        } else {
                            Label("Crear Vehículo", systemImage: "plus.circle.fill")
                        }
                        Spacer()
                    }
                }
                .disabled(code.isEmpty || isProcessing)
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Nuevo Vehículo")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            bases = await BaseService.shared.getAllBases()
        }
        .alert("Vehículo Creado", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("El vehículo '\(code)' se ha creado correctamente.")
        }
    }
    
    private func createVehicle() async {
        isProcessing = true
        errorMessage = nil
        
        do {
            // Usar VehicleService.create() - NO createVehicle()
            _ = try await VehicleService.shared.create(
                code: code,
                plate: plate.isEmpty ? nil : plate,
                type: selectedType.rawValue,
                baseId: selectedBaseId,
                actor: currentUser
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
}

// MARK: - Thresholds List Screen

struct ThresholdsListScreen: View {
    let currentUser: UserFS
    
    @State private var kits: [KitFS] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Cargando kits...")
            } else if kits.isEmpty {
                ContentUnavailableView(
                    "Sin kits",
                    systemImage: "shippingbox",
                    description: Text("No hay kits para configurar.")
                )
            } else {
                List(kits) { kit in
                    NavigationLink {
                        ThresholdEditorScreen(kit: kit, currentUser: currentUser)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kit.name)
                                    .font(.headline)
                                Text(kit.code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Editar Umbrales")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            kits = await KitService.shared.getAllKits()
            isLoading = false
        }
    }
}

// MARK: - Users List Screen (Placeholder)

struct UsersListScreen: View {
    let currentUser: UserFS
    
    @State private var users: [UserFS] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Cargando usuarios...")
            } else if users.isEmpty {
                ContentUnavailableView(
                    "Sin usuarios",
                    systemImage: "person.2",
                    description: Text("No hay usuarios registrados.")
                )
            } else {
                List(users) { user in
                    HStack(spacing: 12) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Text(user.fullName.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundStyle(.purple)
                        }
                        
                        // Info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.fullName)
                                .font(.headline)
                            
                            Text("@\(user.username)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Status
                        Circle()
                            .fill(user.active ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .navigationTitle("Usuarios")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // TODO: Crear usuario
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            users = await UserService.shared.getAllUsers()
            isLoading = false
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
