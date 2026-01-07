//
//  ManagementViews.swift
//  AmbuKit
//
//  Created by Adolfo on 26/12/25.
//  TAREA 16: Vistas de gestión de Kits y Bases
//  ACTUALIZADO: RealtimeManager integrado - Datos en tiempo real 🎯
//  ⚠️ NOTA: KitDetailEditView y BaseDetailEditView están en ManagementViewsEnhanced.swift

import SwiftUI

// MARK: - Kit Management View

struct KitManagementView: View {
    let currentUser: UserFS?
    
    @State private var kits: [KitFS] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var searchText = ""
    
    @State private var toast: Toast?
    @State private var alertConfig: AlertConfig?
    
    var filteredKits: [KitFS] {
        if searchText.isEmpty {
            return kits
        }
        return kits.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        Group {
            if isLoading && kits.isEmpty {
                ProgressView("Cargando kits...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if kits.isEmpty {
                VStack(spacing: 20) {
                    EmptyStateView("Sin kits", message: "No hay kits registrados", icon: "cross.case")
                    
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("Crear Kit", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    // 🎯 Indicador de tiempo real
                    if RealtimeManager.shared.isListening(ListenerKeys.kitsMain) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(.green)
                                .symbolEffect(.pulse)
                            Text("Sincronización en tiempo real")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.green.opacity(0.1))
                    }
                    
                    ForEach(filteredKits) { kit in
                        NavigationLink(destination: KitDetailEditView(kit: kit, currentUser: currentUser)) {
                            KitMgmtRow(kit: kit)
                        }
                    }
                    .onDelete(perform: confirmDelete)
                }
                .searchable(text: $searchText, prompt: "Buscar kits...")
            }
        }
        .navigationTitle("Gestión de Kits")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateKitSheet(currentUser: currentUser) { newKit in
                // No necesitamos añadir manualmente - el listener lo hará
                toast = .success("Kit '\(newKit.code)' creado")
            }
        }
        // 🎯 REALTIME: Listener en tiempo real
        .task {
            startListening()
        }
        .onDisappear {
            RealtimeManager.shared.stopListening(ListenerKeys.kitsMain)
        }
        .refreshable {
            // Pull to refresh: reiniciar listener
            RealtimeManager.shared.stopListening(ListenerKeys.kitsMain)
            startListening()
        }
        .toast($toast)
        .alert(config: $alertConfig)
    }
    
    // 🎯 Iniciar listener en tiempo real
    private func startListening() {
        isLoading = true
        
        RealtimeManager.shared.listenToCollection(
            "kits",
            listenerKey: ListenerKeys.kitsMain,
            orderBy: "code"
        ) { (receivedKits: [KitFS]) in
            self.kits = receivedKits
            self.isLoading = false
        }
    }
    
    private func confirmDelete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let kit = filteredKits[index]
        
        alertConfig = .delete(kit.name) {
            Task { await deleteKit(kit) }
        }
    }
    
    private func deleteKit(_ kit: KitFS) async {
        guard let kitId = kit.id else { return }
        
        do {
            try await KitService.shared.deleteKit(kitId: kitId, actor: currentUser)
            // No necesitamos eliminar manualmente - el listener lo hará
            toast = .success("Kit '\(kit.name)' eliminado")
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
    }
}

// MARK: - Kit Mgmt Row

struct KitMgmtRow: View {
    let kit: KitFS
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(kit.code)
                    .font(.headline)
                Text(kit.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
            Text(kit.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(kit.type)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch kit.status {
        case .active: return .green
        case .inactive: return .gray
        case .maintenance: return .orange
        case .expired: return .red
        }
    }
}

// MARK: - Create Kit Sheet

struct CreateKitSheet: View {
    let currentUser: UserFS?
    let onCreated: (KitFS) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var code = ""
    @State private var name = ""
    @State private var selectedType: KitType = .SVB
    @State private var isSaving = false
    @State private var toast: Toast?
    
    var isValid: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty &&
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Información del Kit") {
                    TextField("Código", text: $code)
                        .textInputAutocapitalization(.characters)
                    TextField("Nombre", text: $name)
                    Picker("Tipo", selection: $selectedType) {
                        ForEach(KitType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("Nuevo Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task { await createKit() }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .loadingOverlay(isLoading: isSaving, message: "Creando kit...")
            .toast($toast)
        }
    }
    
    private func createKit() async {
        isSaving = true
        
        do {
            let newKit = try await KitService.shared.createKit(
                code: code.trimmingCharacters(in: .whitespaces),
                name: name.trimmingCharacters(in: .whitespaces),
                type: selectedType,
                actor: currentUser
            )
            onCreated(newKit)
            dismiss()
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
        
        isSaving = false
    }
}

// MARK: - Base Management View

struct BaseManagementView: View {
    let currentUser: UserFS?
    
    @State private var bases: [BaseFS] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var searchText = ""
    @State private var toast: Toast?
    @State private var alertConfig: AlertConfig?
    
    var filteredBases: [BaseFS] {
        if searchText.isEmpty {
            return bases
        }
        return bases.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        Group {
            if isLoading && bases.isEmpty {
                ProgressView("Cargando bases...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if bases.isEmpty {
                VStack(spacing: 20) {
                    EmptyStateView("Sin bases", message: "No hay bases registradas", icon: "building.2")
                    
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("Crear Base", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    // 🎯 Indicador de tiempo real
                    if RealtimeManager.shared.isListening(ListenerKeys.basesMain) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(.green)
                                .symbolEffect(.pulse)
                            Text("Sincronización en tiempo real")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.green.opacity(0.1))
                    }
                    
                    ForEach(filteredBases) { base in
                        NavigationLink(destination: BaseDetailEditView(base: base, currentUser: currentUser)) {
                            BaseMgmtRow(base: base)
                        }
                    }
                    .onDelete(perform: confirmDelete)
                }
                .searchable(text: $searchText, prompt: "Buscar bases...")
            }
        }
        .navigationTitle("Gestión de Bases")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateBaseSheet(currentUser: currentUser) { newBase in
                toast = .success("Base '\(newBase.name)' creada")
            }
        }
        // 🎯 REALTIME: Listener en tiempo real
        .task {
            startListening()
        }
        .onDisappear {
            RealtimeManager.shared.stopListening(ListenerKeys.basesMain)
        }
        .refreshable {
            RealtimeManager.shared.stopListening(ListenerKeys.basesMain)
            startListening()
        }
        .toast($toast)
        .alert(config: $alertConfig)
    }
    
    // 🎯 Iniciar listener en tiempo real
    private func startListening() {
        isLoading = true
        
        RealtimeManager.shared.listenToCollection(
            "bases",
            listenerKey: ListenerKeys.basesMain,
            orderBy: "code"
        ) { (receivedBases: [BaseFS]) in
            self.bases = receivedBases
            self.isLoading = false
        }
    }
    
    private func confirmDelete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let base = filteredBases[index]
        
        alertConfig = .delete(base.name) {
            Task { await deleteBase(base) }
        }
    }
    
    private func deleteBase(_ base: BaseFS) async {
        guard let baseId = base.id else { return }
        
        do {
            try await BaseService.shared.delete(baseId: baseId, actor: currentUser)
            toast = .success("Base '\(base.name)' eliminada")
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
    }
}

// MARK: - Base Mgmt Row

struct BaseMgmtRow: View {
    let base: BaseFS
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(base.code)
                    .font(.headline)
                if !base.active {
                    Text("Inactiva")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            Text(base.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(base.vehicleCountText)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Base Sheet

struct CreateBaseSheet: View {
    let currentUser: UserFS?
    let onCreated: (BaseFS) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var code = ""
    @State private var name = ""
    @State private var address = ""
    @State private var isSaving = false
    @State private var toast: Toast?
    
    var isValid: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty &&
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Información de la Base") {
                    TextField("Código", text: $code)
                        .textInputAutocapitalization(.characters)
                    TextField("Nombre", text: $name)
                    TextField("Dirección (opcional)", text: $address)
                }
            }
            .navigationTitle("Nueva Base")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task { await createBase() }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .loadingOverlay(isLoading: isSaving, message: "Creando base...")
            .toast($toast)
        }
    }
    
    private func createBase() async {
        isSaving = true
        
        do {
            let newBase = try await BaseService.shared.create(
                code: code.trimmingCharacters(in: .whitespaces),
                name: name.trimmingCharacters(in: .whitespaces),
                address: address.trimmingCharacters(in: .whitespaces).isEmpty ? nil : address.trimmingCharacters(in: .whitespaces),
                active: true,
                actor: currentUser
            )
            onCreated(newBase)
            dismiss()
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
        
        isSaving = false
    }
}

// ⚠️ BaseDetailEditView MOVIDA a ManagementViewsEnhanced.swift
// (con funcionalidad mejorada: ver/desasignar vehículos)

// MARK: - Vehicle Management View

struct VehicleManagementView: View {
    let currentUser: UserFS?
    
    @State private var vehicles: [VehicleFS] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var searchText = ""
    @State private var toast: Toast?
    @State private var alertConfig: AlertConfig?
    
    var filteredVehicles: [VehicleFS] {
        if searchText.isEmpty {
            return vehicles
        }
        return vehicles.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            ($0.plate?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            $0.type.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        Group {
            if isLoading && vehicles.isEmpty {
                ProgressView("Cargando vehículos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vehicles.isEmpty {
                VStack(spacing: 20) {
                    EmptyStateView("Sin vehículos", message: "No hay vehículos registrados", icon: "car.fill")
                    
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("Crear Vehículo", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    // 🎯 Indicador de tiempo real
                    if RealtimeManager.shared.isListening(ListenerKeys.vehiclesMain) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(.green)
                                .symbolEffect(.pulse)
                            Text("Sincronización en tiempo real")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.green.opacity(0.1))
                    }
                    
                    ForEach(filteredVehicles) { vehicle in
                        NavigationLink(destination: VehicleDetailEditView(vehicle: vehicle, currentUser: currentUser)) {
                            VehicleMgmtRow(vehicle: vehicle)
                        }
                    }
                    .onDelete(perform: confirmDelete)
                }
                .searchable(text: $searchText, prompt: "Buscar vehículos...")
            }
        }
        .navigationTitle("Gestión de Vehículos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateVehicleSheet(currentUser: currentUser) { newVehicle in
                toast = .success("Vehículo '\(newVehicle.code)' creado")
            }
        }
        // 🎯 REALTIME: Listener en tiempo real
        .task {
            startListening()
        }
        .onDisappear {
            RealtimeManager.shared.stopListening(ListenerKeys.vehiclesMain)
        }
        .refreshable {
            RealtimeManager.shared.stopListening(ListenerKeys.vehiclesMain)
            startListening()
        }
        .toast($toast)
        .alert(config: $alertConfig)
    }
    
    // 🎯 Iniciar listener en tiempo real
    private func startListening() {
        isLoading = true
        
        RealtimeManager.shared.listenToCollection(
            "vehicles",
            listenerKey: ListenerKeys.vehiclesMain,
            orderBy: "code"
        ) { (receivedVehicles: [VehicleFS]) in
            self.vehicles = receivedVehicles
            self.isLoading = false
        }
    }
    
    private func confirmDelete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let vehicle = filteredVehicles[index]
        
        alertConfig = .delete(vehicle.code) {
            Task { await deleteVehicle(vehicle) }
        }
    }
    
    private func deleteVehicle(_ vehicle: VehicleFS) async {
        guard let vehicleId = vehicle.id else { return }
        
        do {
            try await VehicleService.shared.delete(vehicleId: vehicleId, actor: currentUser)
            toast = .success("Vehículo '\(vehicle.code)' eliminado")
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
    }
}

// MARK: - Vehicle Mgmt Row

struct VehicleMgmtRow: View {
    let vehicle: VehicleFS
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(vehicle.code)
                    .font(.headline)
                Text(vehicle.vehicleType.shortName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(vehicleTypeColor.opacity(0.2))
                    .foregroundStyle(vehicleTypeColor)
                    .clipShape(Capsule())
            }
            if let plate = vehicle.plate {
                Text(plate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(vehicle.hasBase ? "Asignado" : "Sin base")
                .font(.caption)
                .foregroundStyle(vehicle.hasBase ? .green : .orange)
        }
        .padding(.vertical, 4)
    }
    
    private var vehicleTypeColor: Color {
        switch vehicle.vehicleType {
        case .svb: return .blue
        case .sva: return .red
        case .svae: return .orange
        case .tsnu: return .green
        case .vir: return .purple
        case .helicopter: return .yellow
        }
    }
}

// MARK: - Create Vehicle Sheet

struct CreateVehicleSheet: View {
    let currentUser: UserFS?
    let onCreated: (VehicleFS) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var code = ""
    @State private var plate = ""
    @State private var selectedType: VehicleFS.VehicleType = .svb
    @State private var isSaving = false
    @State private var toast: Toast?
    
    var isValid: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Información del Vehículo") {
                    TextField("Código", text: $code)
                        .textInputAutocapitalization(.characters)
                    TextField("Matrícula (opcional)", text: $plate)
                        .textInputAutocapitalization(.characters)
                    Picker("Tipo", selection: $selectedType) {
                        ForEach(VehicleFS.VehicleType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("Nuevo Vehículo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task { await createVehicle() }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .loadingOverlay(isLoading: isSaving, message: "Creando vehículo...")
            .toast($toast)
        }
    }
    
    private func createVehicle() async {
        isSaving = true
        
        do {
            let trimmedPlate = plate.trimmingCharacters(in: .whitespaces)
            let newVehicle = try await VehicleService.shared.create(
                code: code.trimmingCharacters(in: .whitespaces),
                plate: trimmedPlate.isEmpty ? nil : trimmedPlate,
                type: selectedType.rawValue,
                baseId: nil,
                actor: currentUser
            )
            onCreated(newVehicle)
            dismiss()
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
        
        isSaving = false
    }
}

// MARK: - Vehicle Detail Edit View

struct VehicleDetailEditView: View {
    let vehicle: VehicleFS
    let currentUser: UserFS?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedBaseId: String?
    @State private var bases: [BaseFS] = []
    @State private var isSaving = false
    @State private var toast: Toast?
    @State private var alertConfig: AlertConfig?
    
    init(vehicle: VehicleFS, currentUser: UserFS?) {
        self.vehicle = vehicle
        self.currentUser = currentUser
        _selectedBaseId = State(initialValue: vehicle.baseId)
    }
    
    var hasChanges: Bool {
        selectedBaseId != vehicle.baseId
    }
    
    var body: some View {
        Form {
            Section("Información") {
                LabeledContent("Código", value: vehicle.code)
                LabeledContent("Matrícula", value: vehicle.plate ?? "Sin matrícula")
                LabeledContent("Tipo", value: vehicle.vehicleType.displayName)
            }
            
            Section("Asignación") {
                Picker("Base", selection: $selectedBaseId) {
                    Text("Sin asignar").tag(nil as String?)
                    ForEach(bases) { base in
                        Text("\(base.code) - \(base.name)").tag(base.id as String?)
                    }
                }
            }
            
            Section("Estadísticas") {
                LabeledContent("Kits asignados", value: "\(vehicle.kitCount)")
            }
            
            Section {
                Button("Eliminar Vehículo", role: .destructive) {
                    alertConfig = .delete(vehicle.code) {
                        Task { await deleteVehicle() }
                    }
                }
            }
        }
        .navigationTitle("Editar Vehículo")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    Task { await saveChanges() }
                }
                .disabled(!hasChanges || isSaving)
            }
        }
        .task {
            bases = await BaseService.shared.getActiveBases()
        }
        .loadingOverlay(isLoading: isSaving, message: "Guardando...")
        .toast($toast)
        .alert(config: $alertConfig)
    }
    
    private func saveChanges() async {
        isSaving = true
        
        do {
            if let baseId = selectedBaseId {
                try await VehicleService.shared.assignToBase(
                    vehicleId: vehicle.id ?? "",
                    baseId: baseId,
                    actor: currentUser
                )
            } else {
                try await VehicleService.shared.unassignFromBase(
                    vehicleId: vehicle.id ?? "",
                    actor: currentUser
                )
            }
            toast = .success("Cambios guardados")
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
        
        isSaving = false
    }
    
    private func deleteVehicle() async {
        guard let vehicleId = vehicle.id else { return }
        
        do {
            try await VehicleService.shared.delete(vehicleId: vehicleId, actor: currentUser)
            dismiss()
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
    }
}

// MARK: - User Management View

struct UserManagementView: View {
    let currentUser: UserFS?
    
    @State private var users: [UserFS] = []
    @State private var roles: [RoleFS] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var selectedUser: UserFS?
    @State private var toast: Toast?
    @State private var searchText = ""
    
    var filteredUsers: [UserFS] {
        if searchText.isEmpty {
            return users
        }
        return users.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Cargando usuarios...")
            } else if users.isEmpty {
                emptyStateView
            } else {
                usersList
            }
        }
        .navigationTitle("Gestión de Usuarios")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Buscar usuarios...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateUserSheet(currentUser: currentUser, roles: roles) {
                Task { await loadUsers() }
                toast = .success("Usuario creado correctamente")
            }
        }
        .sheet(item: $selectedUser) { user in
            UserDetailEditSheet(user: user, currentUser: currentUser, roles: roles) {
                Task { await loadUsers() }
            }
        }
        .task {
            await loadUsers()
        }
        .toast($toast)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Sin usuarios", systemImage: "person.2")
        } description: {
            Text("No hay usuarios registrados.")
        } actions: {
            Button {
                showCreateSheet = true
            } label: {
                Label("Crear Usuario", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Users List
    
    private var usersList: some View {
        List {
            Section {
                Text("\(users.count) usuario(s) registrado(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(filteredUsers) { user in
                Button {
                    selectedUser = user
                } label: {
                    UserMgmtRow(user: user, roles: roles)
                }
                .buttonStyle(.plain)
            }
        }
        .refreshable {
            await loadUsers()
        }
    }
    
    // MARK: - Load Users
    
    private func loadUsers() async {
        isLoading = true
        
        async let usersTask = UserService.shared.getAllUsers()
        async let rolesTask = PolicyService.shared.getAllRoles()
        
        users = await usersTask
        roles = await rolesTask
        
        isLoading = false
    }
}

// MARK: - User Mgmt Row

struct UserMgmtRow: View {
    let user: UserFS
    let roles: [RoleFS]
    
    var role: RoleFS? {
        roles.first(where: { $0.id == user.roleId })
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Text(user.fullName.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundStyle(roleColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(.headline)
                
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Badge de rol
                if let role = role {
                    Text(role.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(roleColor.opacity(0.15))
                        .foregroundStyle(roleColor)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            // Estado
            Circle()
                .fill(user.active ? Color.green : Color.red)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 4)
    }
    
    private var roleColor: Color {
        guard let role = role else { return .gray }
        switch role.kind {
        case .programmer: return .blue
        case .logistics: return .orange
        case .sanitary: return .green
        }
    }
}

// MARK: - Create User Sheet

struct CreateUserSheet: View {
    let currentUser: UserFS?
    let roles: [RoleFS]
    let onCreated: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var fullName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRoleId: String = ""
    @State private var selectedBaseId: String?
    @State private var bases: [BaseFS] = []
    @State private var isActive = true
    @State private var isProcessing = false
    @State private var toast: Toast?
    
    var isValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty &&
        !selectedRoleId.isEmpty &&
        password.count >= 6
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Información Personal") {
                    TextField("Nombre completo", text: $fullName)
                        .textContentType(.name)
                    
                    TextField("Usuario (sin @)", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                
                Section {
                    SecureField("Contraseña (mín. 6 caracteres)", text: $password)
                        .textContentType(.newPassword)
                } header: {
                    Text("Credenciales")
                } footer: {
                    Text("La contraseña debe tener al menos 6 caracteres")
                }
                
                Section("Rol y Permisos") {
                    Picker("Rol", selection: $selectedRoleId) {
                        Text("Seleccionar rol").tag("")
                        ForEach(roles) { role in
                            Text(role.displayName).tag(role.id ?? "")
                        }
                    }
                    
                    Picker("Base asignada", selection: $selectedBaseId) {
                        Text("Sin asignar").tag(nil as String?)
                        ForEach(bases) { base in
                            Text("\(base.code) - \(base.name)").tag(base.id as String?)
                        }
                    }
                    
                    Toggle("Usuario activo", isOn: $isActive)
                }
            }
            .navigationTitle("Nuevo Usuario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task { await createUser() }
                    }
                    .disabled(!isValid || isProcessing)
                }
            }
            .task {
                bases = await BaseService.shared.getActiveBases()
                if let firstRole = roles.first {
                    selectedRoleId = firstRole.id ?? ""
                }
            }
            .toast($toast)
        }
    }
    
    private func createUser() async {
        isProcessing = true
        
        do {
            _ = try await UserService.shared.create(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                username: username.trimmingCharacters(in: .whitespaces),
                fullName: fullName.trimmingCharacters(in: .whitespaces),
                roleId: selectedRoleId,
                baseId: selectedBaseId,
                actor: currentUser
            )
            
            onCreated()
            dismiss()
            
        } catch {
            toast = .error(error)
        }
        
        isProcessing = false
    }
}

// MARK: - User Detail Edit Sheet

struct UserDetailEditSheet: View {
    let user: UserFS
    let currentUser: UserFS?
    let roles: [RoleFS]
    let onUpdated: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var fullName: String
    @State private var username: String
    @State private var email: String
    @State private var selectedRoleId: String
    @State private var selectedBaseId: String?
    @State private var isActive: Bool
    @State private var bases: [BaseFS] = []
    @State private var isProcessing = false
    @State private var toast: Toast?
    @State private var showDeleteConfirmation = false
    
    init(user: UserFS, currentUser: UserFS?, roles: [RoleFS], onUpdated: @escaping () -> Void) {
        self.user = user
        self.currentUser = currentUser
        self.roles = roles
        self.onUpdated = onUpdated
        
        _fullName = State(initialValue: user.fullName)
        _username = State(initialValue: user.username)
        _email = State(initialValue: user.email)
        _selectedRoleId = State(initialValue: user.roleId ?? "")
        _selectedBaseId = State(initialValue: user.baseId)
        _isActive = State(initialValue: user.active)
    }
    
    var hasChanges: Bool {
        fullName != user.fullName ||
        username != user.username ||
        email != user.email ||
        selectedRoleId != (user.roleId ?? "") ||
        selectedBaseId != user.baseId ||
        isActive != user.active
    }
    
    var isSelf: Bool {
        user.id == currentUser?.id
    }
    
    var isValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedRoleId.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Info básica
                Section("Información Personal") {
                    TextField("Nombre completo", text: $fullName)
                        .textContentType(.name)
                    
                    TextField("Usuario", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                
                // Rol y base
                Section {
                    Picker("Rol", selection: $selectedRoleId) {
                        ForEach(roles) { role in
                            Text(role.displayName).tag(role.id ?? "")
                        }
                    }
                    .disabled(isSelf)
                    
                    Picker("Base asignada", selection: $selectedBaseId) {
                        Text("Sin asignar").tag(nil as String?)
                        ForEach(bases) { base in
                            Text("\(base.code) - \(base.name)").tag(base.id as String?)
                        }
                    }
                    
                    Toggle("Usuario activo", isOn: $isActive)
                        .disabled(isSelf)
                } header: {
                    Text("Rol y Permisos")
                } footer: {
                    Group {
                        if isSelf {
                            Text("No puedes cambiar tu propio rol o desactivarte")
                        }
                    }
                }
                
                // Info adicional
                Section("Información del Sistema") {
                    LabeledContent("ID", value: user.id ?? "N/A")
                        .font(.caption.monospaced())
                    
                    LabeledContent("Creado", value: user.createdAt, format: .dateTime)
                    
                    LabeledContent("Actualizado", value: user.updatedAt, format: .dateTime)
                }
                
                // Eliminar (solo si no eres tú)
                if !isSelf {
                    Section {
                        Button("Eliminar Usuario", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } footer: {
                        Text("Esta acción marcará al usuario como inactivo.")
                    }
                }
            }
            .navigationTitle(user.fullName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task { await saveChanges() }
                    }
                    .disabled(!hasChanges || !isValid || isProcessing)
                }
            }
            .task {
                bases = await BaseService.shared.getActiveBases()
            }
            .toast($toast)
            .alert("Eliminar Usuario", isPresented: $showDeleteConfirmation) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    Task { await deleteUser() }
                }
            } message: {
                Text("¿Estás seguro de que quieres eliminar a '\(user.fullName)'? Esta acción marcará al usuario como inactivo.")
            }
        }
    }
    
    // MARK: - Save Changes
    
    private func saveChanges() async {
        isProcessing = true
        
        do {
            var updatedUser = user
            updatedUser.fullName = fullName.trimmingCharacters(in: .whitespaces)
            updatedUser.username = username.trimmingCharacters(in: .whitespaces)
            updatedUser.email = email.trimmingCharacters(in: .whitespaces)
            updatedUser.roleId = selectedRoleId
            updatedUser.baseId = selectedBaseId
            updatedUser.active = isActive
            
            try await UserService.shared.update(user: updatedUser, actor: currentUser)
            
            toast = .success("Usuario actualizado correctamente")
            onUpdated()
            
            try? await Task.sleep(for: .seconds(0.5))
            dismiss()
            
        } catch {
            toast = .error(error)
        }
        
        isProcessing = false
    }
    
    // MARK: - Delete User
    
    private func deleteUser() async {
        guard let userId = user.id else {
            toast = .error("El usuario no tiene ID válido")
            return
        }
        
        isProcessing = true
        
        do {
            try await UserService.shared.delete(userId: userId, actor: currentUser)
            
            toast = .success("Usuario eliminado correctamente")
            onUpdated()
            
            try? await Task.sleep(for: .seconds(0.5))
            dismiss()
            
        } catch {
            toast = .error(error)
        }
        
        isProcessing = false
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Kit Management") {
    NavigationStack {
        KitManagementView(currentUser: nil)
    }
}

#Preview("Base Management") {
    NavigationStack {
        BaseManagementView(currentUser: nil)
    }
}

#Preview("Vehicle Management") {
    NavigationStack {
        VehicleManagementView(currentUser: nil)
    }
}

#Preview("User Management") {
    NavigationStack {
        UserManagementView(currentUser: nil)
    }
}
#endif
