//
//  StatisticsView.swift
//  AmbuKit
//
//  Created by Adolfo on 26/12/25.
//  TAREA 16.7: Vista de estadísticas - 100% Firebase
//
//  Características:
//  - Dashboard con métricas del sistema
//  - Alertas activas (stock bajo, caducidades)
//  - Distribución por tipo de vehículo
//  - Pull-to-refresh
//  TAREA 16.9: Stats con navegación a listados
//

import SwiftUI

// MARK: - StatisticsView

struct StatisticsView: View {
    
    // MARK: - Properties
    
    let currentUser: UserFS
    
    // MARK: - State
    
    @State private var isLoading = true
    @State private var lastUpdated = Date()
    
    // Stats
    @State private var kitStats: KitStatistics?
    @State private var vehicleStats: VehicleStatistics?
    @State private var baseStats: BaseStatistics?
    @State private var userCount: Int = 0
    
    // Data para navegación
    @State private var allKits: [KitFS] = []
    @State private var allVehicles: [VehicleFS] = []
    @State private var allBases: [BaseFS] = []
    @State private var allUsers: [UserFS] = []
    
    // Alerts
    @State private var lowStockItems: [KitItemFS] = []
    @State private var expiringItems: [KitItemFS] = []
    @State private var expiredItems: [KitItemFS] = []
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    loadingView
                } else {
                    VStack(spacing: 20) {
                        lastUpdatedHeader
                        overviewSection
                        alertsSection
                        vehicleDistributionSection
                        kitsStatusSection
                        basesSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Estadísticas")
            .refreshable {
                await loadAllStatistics()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadAllStatistics() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await loadAllStatistics()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Cargando estadísticas...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - Last Updated Header
    
    private var lastUpdatedHeader: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
            Text("Actualizado: \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Overview Section (NAVEGABLE)
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatSectionHeader(title: "Resumen General", icon: "chart.bar.fill", color: .blue)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Kits - Navegable
                NavigationLink {
                    StatsKitsListView(kits: allKits, currentUser: currentUser)
                } label: {
                    StatCardView(
                        title: "Kits",
                        value: "\(kitStats?.totalKits ?? 0)",
                        subtitle: "\(kitStats?.assignedKits ?? 0) asignados",
                        icon: "cross.case.fill",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)
                
                // Vehículos - Navegable
                NavigationLink {
                    StatsVehiclesListView(vehicles: allVehicles, bases: allBases, currentUser: currentUser)
                } label: {
                    StatCardView(
                        title: "Vehículos",
                        value: "\(vehicleStats?.total ?? 0)",
                        subtitle: "\(vehicleStats?.withBase ?? 0) con base",
                        icon: "car.fill",
                        color: .green
                    )
                }
                .buttonStyle(.plain)
                
                // Bases - Navegable
                NavigationLink {
                    StatsBasesListView(bases: allBases, vehicles: allVehicles, currentUser: currentUser)
                } label: {
                    StatCardView(
                        title: "Bases",
                        value: "\(baseStats?.total ?? 0)",
                        subtitle: "\(baseStats?.active ?? 0) activas",
                        icon: "building.2.fill",
                        color: .teal
                    )
                }
                .buttonStyle(.plain)
                
                // Usuarios - Navegable
                NavigationLink {
                    StatsUsersListView(users: allUsers, currentUser: currentUser)
                } label: {
                    StatCardView(
                        title: "Usuarios",
                        value: "\(userCount)",
                        subtitle: "registrados",
                        icon: "person.2.fill",
                        color: .purple
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Alerts Section
    
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatSectionHeader(title: "Alertas Activas", icon: "exclamationmark.triangle.fill", color: .orange)
            
            VStack(spacing: 8) {
                StatAlertRow(
                    title: "Stock Bajo",
                    count: lowStockItems.count,
                    icon: "arrow.down.circle.fill",
                    color: .red,
                    severity: lowStockItems.isEmpty ? .none : .high
                )
                
                StatAlertRow(
                    title: "Próximos a Caducar",
                    count: expiringItems.count,
                    icon: "clock.badge.exclamationmark.fill",
                    color: .orange,
                    severity: expiringItems.isEmpty ? .none : .medium
                )
                
                StatAlertRow(
                    title: "Caducados",
                    count: expiredItems.count,
                    icon: "xmark.circle.fill",
                    color: .red,
                    severity: expiredItems.isEmpty ? .none : .critical
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Vehicle Distribution Section
    
    private var vehicleDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatSectionHeader(title: "Distribución de Vehículos", icon: "car.2.fill", color: .green)
            
            VStack(spacing: 8) {
                if let stats = vehicleStats {
                    StatDistributionRow(label: "Con Base", value: stats.withBase, total: stats.total, color: .green)
                    StatDistributionRow(label: "Sin Base", value: stats.withoutBase, total: stats.total, color: .orange)
                    StatDistributionRow(label: "Con Kits", value: stats.withKits, total: stats.total, color: .purple)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Kits Status Section
    
    private var kitsStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatSectionHeader(title: "Estado de Kits", icon: "cross.case.fill", color: .blue)
            
            VStack(spacing: 8) {
                if let stats = kitStats {
                    StatDistributionRow(label: "Asignados", value: stats.assignedKits, total: stats.totalKits, color: .green)
                    StatDistributionRow(label: "Sin Asignar", value: stats.unassignedKits, total: stats.totalKits, color: .orange)
                    
                    Divider()
                    
                    HStack {
                        Text("Total Items en Kits")
                            .font(.subheadline)
                        Spacer()
                        Text("\(stats.totalItems)")
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Bases Section
    
    private var basesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatSectionHeader(title: "Estado de Bases", icon: "building.2.fill", color: .teal)
            
            VStack(spacing: 8) {
                if let stats = baseStats {
                    StatDistributionRow(label: "Activas", value: stats.active, total: stats.total, color: .green)
                    StatDistributionRow(label: "Con Vehículos", value: stats.withVehicles, total: stats.total, color: .blue)
                    StatDistributionRow(label: "Sin Vehículos", value: stats.withoutVehicles, total: stats.total, color: .orange)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Load Statistics
    
    private func loadAllStatistics() async {
        isLoading = true
        
        // Cargar datos
        async let kitsTask = KitService.shared.getAllKits()
        async let vehiclesTask = VehicleService.shared.getAllVehicles()
        async let basesTask = BaseService.shared.getAllBases()
        async let usersTask = UserService.shared.getAllUsers()
        async let lowStockTask = KitService.shared.getLowStockItems()
        async let expiringTask = KitService.shared.getExpiringItems()
        async let expiredTask = KitService.shared.getExpiredItems()
        
        allKits = await kitsTask
        allVehicles = await vehiclesTask
        allBases = await basesTask
        allUsers = await usersTask
        lowStockItems = await lowStockTask
        expiringItems = await expiringTask
        expiredItems = await expiredTask
        
        // Cargar roles para usuarios
        for i in allUsers.indices {
            if let roleId = allUsers[i].roleId {
                allUsers[i].role = await PolicyService.shared.getRole(id: roleId)
            }
        }
        
        // Calcular estadísticas
        kitStats = await loadKitStatistics()
        
        let vStats = await VehicleService.shared.getStatistics()
        vehicleStats = VehicleStatistics(
            total: vStats.total,
            withBase: vStats.withBase,
            withoutBase: vStats.withoutBase,
            withKits: vStats.withKits
        )
        
        let bStats = await BaseService.shared.getStatistics()
        baseStats = BaseStatistics(
            total: bStats.total,
            active: bStats.active,
            withVehicles: bStats.withVehicles,
            withoutVehicles: bStats.withoutVehicles
        )
        
        userCount = allUsers.count
        
        lastUpdated = Date()
        isLoading = false
    }
    
    private func loadKitStatistics() async -> KitStatistics {
        let stats = await KitService.shared.getGlobalStatistics()
        return KitStatistics(
            totalKits: stats.totalKits,
            assignedKits: stats.assignedKits,
            unassignedKits: stats.unassignedKits,
            totalItems: stats.totalItems,
            lowStockItems: stats.lowStockItems,
            expiringItems: stats.expiringItems,
            expiredItems: stats.expiredItems
        )
    }
}

// MARK: - Statistics Models

private struct KitStatistics {
    let totalKits, assignedKits, unassignedKits, totalItems: Int
    let lowStockItems, expiringItems, expiredItems: Int
}

private struct VehicleStatistics {
    let total, withBase, withoutBase, withKits: Int
}

private struct BaseStatistics {
    let total, active, withVehicles, withoutVehicles: Int
}

// MARK: - Stats Kits List View

struct StatsKitsListView: View {
    let kits: [KitFS]
    let currentUser: UserFS
    
    var body: some View {
        List(kits) { kit in
            NavigationLink {
                KitDetailView(kit: kit, currentUser: currentUser)
            } label: {
                HStack {
                    Image(systemName: "cross.case.fill")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text(kit.name).font(.headline)
                        Text(kit.code).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if kit.isAssigned {
                        Text("Asignado")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .navigationTitle("Kits (\(kits.count))")
    }
}

// MARK: - Stats Vehicles List View

struct StatsVehiclesListView: View {
    let vehicles: [VehicleFS]
    let bases: [BaseFS]
    let currentUser: UserFS
    
    var body: some View {
        List(vehicles) { vehicle in
            NavigationLink {
                VehicleDetailScreen(vehicle: vehicle, currentUser: currentUser, bases: bases)
            } label: {
                HStack {
                    Image(systemName: "car.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text(vehicle.code).font(.headline)
                        Text(vehicle.type).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if vehicle.hasBase {
                        Text("Con base")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .navigationTitle("Vehículos (\(vehicles.count))")
    }
}

// MARK: - Stats Bases List View

struct StatsBasesListView: View {
    let bases: [BaseFS]
    let vehicles: [VehicleFS]
    let currentUser: UserFS
    
    var body: some View {
        List(bases) { base in
            NavigationLink {
                BaseDetailView(base: base, vehicles: vehiclesForBase(base), currentUser: currentUser)
            } label: {
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(.teal)
                    VStack(alignment: .leading) {
                        Text(base.name).font(.headline)
                        Text(base.code).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    let count = vehiclesForBase(base).count
                    if count > 0 {
                        Text("\(count) vehículos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Bases (\(bases.count))")
    }
    
    private func vehiclesForBase(_ base: BaseFS) -> [VehicleFS] {
        vehicles.filter { $0.baseId == base.id }
    }
}

// MARK: - Base Detail View

struct BaseDetailView: View {
    let base: BaseFS
    let vehicles: [VehicleFS]
    let currentUser: UserFS
    
    var body: some View {
        List {
            Section("Información") {
                LabeledContent("Código", value: base.code)
                LabeledContent("Nombre", value: base.name)
                if !base.address.isEmpty {
                    LabeledContent("Dirección", value: base.address)
                }
                LabeledContent("Activa", value: base.active ? "Sí" : "No")
            }
            
            Section("Vehículos Asignados (\(vehicles.count))") {
                if vehicles.isEmpty {
                    Text("No hay vehículos asignados")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vehicles) { vehicle in
                        HStack {
                            Image(systemName: "car.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text(vehicle.code).font(.headline)
                                Text(vehicle.type).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(base.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Stats Users List View

struct StatsUsersListView: View {
    @State private var users: [UserFS]
    let currentUser: UserFS
    
    @State private var showingCreateUser = false
    @State private var showingDeleteAlert = false
    @State private var userToDelete: UserFS?
    
    init(users: [UserFS], currentUser: UserFS) {
        self._users = State(initialValue: users)
        self.currentUser = currentUser
    }
    
    private var canManageUsers: Bool {
        currentUser.role?.kind == .programmer
    }
    
    var body: some View {
        List {
            ForEach(users) { user in
                NavigationLink {
                    UserDetailView(user: user, currentUser: currentUser, onUpdate: { updatedUser in
                        if let index = users.firstIndex(where: { $0.id == updatedUser.id }) {
                            users[index] = updatedUser
                        }
                    })
                } label: {
                    UserRowView(user: user)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if canManageUsers && user.id != currentUser.id {
                        Button(role: .destructive) {
                            userToDelete = user
                            showingDeleteAlert = true
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Usuarios (\(users.count))")
        .toolbar {
            if canManageUsers {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateUser = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateUser) {
            CreateUserView(currentUser: currentUser) { newUser in
                users.append(newUser)
            }
        }
        .alert("Eliminar Usuario", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                if let user = userToDelete {
                    Task {
                        await deleteUser(user)
                    }
                }
            }
        } message: {
            if let user = userToDelete {
                Text("¿Estás seguro de eliminar a \(user.fullName)?")
            }
        }
    }
    
    private func deleteUser(_ user: UserFS) async {
        guard let userId = user.id else { return }
        do {
            try await UserService.shared.delete(userId: userId, actor: currentUser)
            users.removeAll { $0.id == userId }
        } catch {
            print("❌ Error eliminando usuario: \(error)")
        }
    }
}

// MARK: - User Row View

struct UserRowView: View {
    let user: UserFS
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(user.fullName.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundStyle(roleColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName).font(.headline)
                Text("@\(user.username)").font(.caption).foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let role = user.role {
                Text(role.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(roleColor.opacity(0.15))
                    .foregroundStyle(roleColor)
                    .clipShape(Capsule())
            }
        }
    }
    
    private var roleColor: Color {
        guard let role = user.role else { return .gray }
        switch role.kind {
        case .programmer: return .blue
        case .logistics: return .orange
        case .sanitary: return .green
        }
    }
}

// MARK: - User Detail View

struct UserDetailView: View {
    let user: UserFS
    let currentUser: UserFS
    let onUpdate: (UserFS) -> Void
    
    @State private var roles: [RoleFS] = []
    @State private var bases: [BaseFS] = []
    
    private var canEdit: Bool {
        currentUser.role?.kind == .programmer
    }
    
    var body: some View {
        List {
            Section("Información Personal") {
                LabeledContent("Nombre", value: user.fullName)
                LabeledContent("Username", value: "@\(user.username)")
                LabeledContent("Email", value: user.email)
            }
            
            Section("Rol y Permisos") {
                LabeledContent("Rol", value: user.role?.displayName ?? "Sin rol")
                
                // Mostrar permisos
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permisos:").font(.caption).foregroundStyle(.secondary)
                    permissionBadges
                }
            }
            
            Section("Base Asignada") {
                if let baseId = user.baseId, let base = bases.first(where: { $0.id == baseId }) {
                    LabeledContent("Base", value: base.name)
                } else {
                    LabeledContent("Base", value: "Sin asignar")
                }
            }
            
            Section("Estado") {
                HStack {
                    Text("Activo")
                    Spacer()
                    Image(systemName: user.active ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(user.active ? .green : .red)
                }
            }
        }
        .navigationTitle(user.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }
    
    private var permissionBadges: some View {
        let roleKind = user.role?.kind ?? .sanitary
        
        return HStack(spacing: 4) {
            if roleKind == .programmer {
                PermissionBadge(text: "Admin", color: .blue)
                PermissionBadge(text: "Usuarios", color: .purple)
            } else if roleKind == .logistics {
                PermissionBadge(text: "Umbrales", color: .orange)
                PermissionBadge(text: "Stock", color: .blue)
            } else {
                PermissionBadge(text: "Lectura", color: .gray)
            }
        }
    }
    
    private func loadData() async {
        roles = await PolicyService.shared.getAllRoles()
        bases = await BaseService.shared.getAllBases()
    }
}

// MARK: - Permission Badge

struct PermissionBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Create User View

struct CreateUserView: View {
    let currentUser: UserFS
    let onCreate: (UserFS) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = ""
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRoleKind: RoleKind = .sanitary
    @State private var selectedBaseId: String?
    
    @State private var roles: [RoleFS] = []
    @State private var bases: [BaseFS] = []
    
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Datos de Acceso") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Contraseña", text: $password)
                }
                
                Section("Información Personal") {
                    TextField("Nombre Completo", text: $fullName)
                }
                
                Section("Rol y Asignación") {
                    Picker("Rol", selection: $selectedRoleKind) {
                        Text("Programador").tag(RoleKind.programmer)
                        Text("Logística").tag(RoleKind.logistics)
                        Text("Sanitario").tag(RoleKind.sanitary)
                    }
                    
                    Picker("Base", selection: $selectedBaseId) {
                        Text("Sin base").tag(nil as String?)
                        ForEach(bases) { base in
                            Text(base.name).tag(base.id as String?)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Nuevo Usuario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task { await createUser() }
                    }
                    .disabled(!isValidForm || isCreating)
                }
            }
            .task {
                await loadData()
            }
        }
    }
    
    private var isValidForm: Bool {
        !username.isEmpty && !fullName.isEmpty && !email.isEmpty && password.count >= 6
    }
    
    private func loadData() async {
        roles = await PolicyService.shared.getAllRoles()
        bases = await BaseService.shared.getAllBases()
    }
    
    private func createUser() async {
        isCreating = true
        errorMessage = nil
        
        // Buscar rol por kind
        guard let role = roles.first(where: { $0.kind == selectedRoleKind }),
              let roleId = role.id else {
            errorMessage = "No se encontró el rol seleccionado"
            isCreating = false
            return
        }
        
        do {
            let newUser = try await UserService.shared.create(
                email: email,
                password: password,
                username: username,
                fullName: fullName,
                roleId: roleId,
                baseId: selectedBaseId,
                actor: currentUser
            )
            
            var userWithRole = newUser
            userWithRole.role = role
            
            onCreate(userWithRole)
            dismiss()
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
        }
        
        isCreating = false
    }
}

// MARK: - Helper Components

private struct StatSectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
}

private struct StatCardView: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Text(value)
                .font(.title.bold())
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct StatAlertRow: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let severity: AlertSeverity
    
    enum AlertSeverity {
        case none, medium, high, critical
        
        var backgroundColor: Color {
            switch self {
            case .none: return .clear
            case .medium: return .orange.opacity(0.1)
            case .high: return .red.opacity(0.1)
            case .critical: return .red.opacity(0.2)
            }
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(count > 0 ? color : .gray)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text("\(count)")
                .font(.headline.bold())
                .foregroundStyle(count > 0 ? color : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(severity.backgroundColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

private struct StatDistributionRow: View {
    let label: String
    let value: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(value) / \(total)")
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray4))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    let user = UserFS(
        id: "1", uid: "uid1", username: "admin",
        fullName: "Admin", email: "admin@test.com",
        active: true, roleId: "role_programmer", baseId: nil
    )
    return StatisticsView(currentUser: user)
}








