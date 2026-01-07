//
//  ManagementViewsEnhanced.swift
//  AmbuKit
//
//  Created by Adolfo on 6/1/26.
//  Vistas mejoradas para gestión de Kits y Bases
//
//  FUNCIONALIDADES AÑADIDAS:
//  - KitDetailEditView: Añadir/quitar items del catálogo
//  - BaseDetailEditView: Ver y desasignar vehículos
//  - ✅ NUEVO: Campo caducidad opcional al añadir items
//

import SwiftUI

// MARK: - Kit Detail Edit View (MEJORADO)

/// Vista de edición de kit con gestión completa de items
struct KitDetailEditView: View {
    let kit: KitFS
    let currentUser: UserFS?
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State - Datos del kit
    @State private var name: String
    @State private var type: String
    @State private var status: KitFS.Status
    
    // MARK: - State - Items del kit
    @State private var kitItems: [KitItemFS] = []
    @State private var catalogDict: [String: CatalogItemFS] = [:]
    @State private var isLoadingItems = true
    
    // MARK: - State - UI
    @State private var isSaving = false
    @State private var toast: Toast?
    @State private var alertConfig: AlertConfig?
    @State private var showAddItemSheet = false
    @State private var itemToDelete: KitItemFS?
    
    init(kit: KitFS, currentUser: UserFS?) {
        self.kit = kit
        self.currentUser = currentUser
        _name = State(initialValue: kit.name)
        _type = State(initialValue: kit.type)
        _status = State(initialValue: kit.status)
    }
    
    var hasChanges: Bool {
        name != kit.name || type != kit.type || status != kit.status
    }
    
    var body: some View {
        Form {
            // MARK: - Sección: Información básica
            Section("Información") {
                LabeledContent("Código", value: kit.code)
                TextField("Nombre", text: $name)
                TextField("Tipo", text: $type)
                Picker("Estado", selection: $status) {
                    ForEach(KitFS.Status.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
            }
            
            // MARK: - Sección: Items del Kit (NUEVO)
            Section {
                if isLoadingItems {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Cargando items...")
                            .foregroundStyle(.secondary)
                    }
                } else if kitItems.isEmpty {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundStyle(.secondary)
                        Text("Sin items")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(kitItems) { item in
                        KitItemEditRow(
                            item: item,
                            catalogItem: catalogDict[item.catalogItemId ?? ""],
                            onDelete: {
                                itemToDelete = item
                                alertConfig = AlertConfig(
                                    title: "Eliminar Item",
                                    message: "¿Eliminar '\(catalogDict[item.catalogItemId ?? ""]?.name ?? "este item")' del kit?",
                                    primaryLabel: "Eliminar",
                                    primaryRole: .destructive,
                                    primaryAction: { Task { await deleteItem(item) } },
                                    secondaryLabel: "Cancelar"
                                )
                            }
                        )
                    }
                }
                
                // Botón añadir item
                Button {
                    showAddItemSheet = true
                } label: {
                    Label("Añadir Item del Catálogo", systemImage: "plus.circle.fill")
                }
                .foregroundStyle(.blue)
            } header: {
                HStack {
                    Text("Items del Kit (\(kitItems.count))")
                    Spacer()
                    if !kitItems.isEmpty {
                        Button {
                            Task { await loadItems() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                }
            }
            
            // MARK: - Sección: Estadísticas
            Section("Estadísticas") {
                LabeledContent("Total Items", value: "\(kitItems.count)")
                LabeledContent("Stock Bajo", value: "\(kitItems.filter { $0.isBelowMinimum }.count)")
                LabeledContent("Asignado", value: kit.isAssigned ? "Sí" : "No")
                if kit.needsAudit {
                    Label("Necesita auditoría", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            
            // MARK: - Sección: Eliminar
            Section {
                Button("Eliminar Kit", role: .destructive) {
                    if !kitItems.isEmpty {
                        toast = .error("No se puede eliminar: tiene \(kitItems.count) items")
                    } else {
                        alertConfig = .delete(kit.name) {
                            Task { await deleteKit() }
                        }
                    }
                }
            }
        }
        .navigationTitle("Editar Kit")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    Task { await saveChanges() }
                }
                .disabled(!hasChanges || isSaving)
            }
        }
        .task {
            await loadItems()
        }
        .sheet(isPresented: $showAddItemSheet) {
            AddItemToKitSheet(
                kit: kit,
                existingItemIds: Set(kitItems.compactMap { $0.catalogItemId }),
                currentUser: currentUser
            ) { newItem in
                kitItems.append(newItem)
                toast = .success("Item añadido")
            }
        }
        .loadingOverlay(isLoading: isSaving, message: "Guardando...")
        .toast($toast)
        .alert(config: $alertConfig)
    }
    
    // MARK: - Load Items
    
    private func loadItems() async {
        isLoadingItems = true
        
        guard let kitId = kit.id else {
            isLoadingItems = false
            return
        }
        
        // Cargar items y catálogo en paralelo
        async let itemsTask = KitService.shared.getKitItems(kitId: kitId)
        async let catalogTask = CatalogService.shared.getAllItems()
        
        kitItems = await itemsTask
        let allCatalog = await catalogTask
        
        // Crear diccionario de catálogo
        var catalog: [String: CatalogItemFS] = [:]
        for item in allCatalog {
            if let id = item.id {
                catalog[id] = item
            }
        }
        catalogDict = catalog
        
        isLoadingItems = false
    }
    
    // MARK: - Save Changes
    
    private func saveChanges() async {
        isSaving = true
        
        var updatedKit = kit
        updatedKit.name = name
        updatedKit.type = type
        updatedKit.status = status
        
        do {
            try await KitService.shared.updateKit(kit: updatedKit, actor: currentUser)
            toast = .success("Cambios guardados")
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
        
        isSaving = false
    }
    
    // MARK: - Delete Item
    
    private func deleteItem(_ item: KitItemFS) async {
        guard let itemId = item.id else { return }
        
        do {
            try await KitService.shared.removeItemFromKit(kitItemId: itemId, actor: currentUser)
            kitItems.removeAll { $0.id == itemId }
            toast = .success("Item eliminado")
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
    }
    
    // MARK: - Delete Kit
    
    private func deleteKit() async {
        guard let kitId = kit.id else { return }
        
        do {
            try await KitService.shared.deleteKit(kitId: kitId, actor: currentUser)
            dismiss()
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
    }
}

// MARK: - Kit Item Edit Row

struct KitItemEditRow: View {
    let item: KitItemFS
    let catalogItem: CatalogItemFS?
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(catalogItem?.name ?? "Item desconocido")
                    .font(.body)
                
                HStack(spacing: 8) {
                    // Cantidad actual
                    Label("\(Int(item.quantity))", systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(item.isBelowMinimum ? .red : .secondary)
                    
                    // Rango min-max
                    Text("(\(Int(item.min))-\(item.max != nil ? "\(Int(item.max!))" : "∞"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Badge de estado
                    if item.isBelowMinimum {
                        Text("BAJO")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.2))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                    
                    // ✅ TAREA D: Badge de caducidad
                    if let expiry = item.expiry {
                        if item.isExpired {
                            Text("CADUCADO")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.red.opacity(0.2))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        } else if item.isExpiringSoon {
                            Text("CADUCA PRONTO")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            Spacer()
            
            // Botón eliminar
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Item To Kit Sheet

struct AddItemToKitSheet: View {
    let kit: KitFS
    let existingItemIds: Set<String>
    let currentUser: UserFS?
    let onAdded: (KitItemFS) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var catalogItems: [CatalogItemFS] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedItem: CatalogItemFS?
    
    // Campos para el nuevo item
    @State private var quantity: Double = 1
    @State private var minQuantity: Double = 1
    @State private var maxQuantity: Double = 10
    @State private var isSaving = false
    @State private var toast: Toast?
    
    // Sheet para crear nuevo item de catálogo
    @State private var showCreateCatalogItem = false
    
    // ✅ TAREA D: Caducidad opcional
    @State private var hasExpiry = false
    @State private var expiryDate = Date().addingTimeInterval(86400 * 365) // 1 año por defecto
    
    var availableItems: [CatalogItemFS] {
        catalogItems.filter { item in
            guard let id = item.id else { return false }
            // Excluir items que ya están en el kit
            guard !existingItemIds.contains(id) else { return false }
            // Filtrar por búsqueda
            if searchText.isEmpty { return true }
            return item.name.localizedCaseInsensitiveContains(searchText) ||
                   item.code.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Cargando catálogo...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if selectedItem == nil {
                    // Paso 1: Seleccionar item del catálogo
                    selectItemView
                } else {
                    // Paso 2: Configurar cantidades
                    configureItemView
                }
            }
            .navigationTitle(selectedItem == nil ? "Añadir Item" : "Configurar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                
                if selectedItem != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Añadir") {
                            Task { await addItem() }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .task {
                await loadCatalog()
            }
            .sheet(isPresented: $showCreateCatalogItem) {
                CreateCatalogItemSheet(currentUser: currentUser) { newItem in
                    // Añadir al listado y seleccionarlo automáticamente
                    catalogItems.append(newItem)
                    catalogItems.sort { $0.code < $1.code }
                    selectedItem = newItem
                    toast = .success("'\(newItem.name)' creado")
                }
            }
            .toast($toast)
        }
    }
    
    // MARK: - Load Catalog
    
    private func loadCatalog() async {
        catalogItems = await CatalogService.shared.getAllItems()
        isLoading = false
    }
    
    // MARK: - Select Item View
    
    private var selectItemView: some View {
        List {
            // Botón crear nuevo item de catálogo
            Section {
                Button {
                    showCreateCatalogItem = true
                } label: {
                    Label("Crear Nuevo Item de Catálogo", systemImage: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            
            // Lista de items disponibles
            Section {
                if availableItems.isEmpty {
                    ContentUnavailableView(
                        "Sin items disponibles",
                        systemImage: "tray",
                        description: Text("Todos los items ya están en el kit o no hay items en el catálogo")
                    )
                } else {
                    ForEach(availableItems) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(item.code)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if item.critical {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Items del Catálogo (\(availableItems.count))")
            }
        }
        .searchable(text: $searchText, prompt: "Buscar en catálogo...")
    }
    
    // MARK: - Configure Item View
    
    private var configureItemView: some View {
        Form {
            Section("Item Seleccionado") {
                HStack {
                    VStack(alignment: .leading) {
                        Text(selectedItem?.name ?? "")
                            .font(.headline)
                        Text(selectedItem?.code ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Cambiar") {
                        selectedItem = nil
                    }
                    .font(.caption)
                }
            }
            
            Section("Cantidades") {
                HStack {
                    Text("Cantidad Actual")
                    Spacer()
                    TextField("", value: $quantity, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                }
                
                HStack {
                    Text("Mínimo")
                    Spacer()
                    TextField("", value: $minQuantity, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                }
                
                HStack {
                    Text("Máximo")
                    Spacer()
                    TextField("", value: $maxQuantity, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                }
            }
            
            // ✅ TAREA D: Caducidad opcional
            Section {
                Toggle("¿Tiene fecha de caducidad?", isOn: $hasExpiry)
                
                if hasExpiry {
                    DatePicker(
                        "Fecha de caducidad",
                        selection: $expiryDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }
            } header: {
                Text("Caducidad")
            } footer: {
                Text("Solo para items consumibles o farmacológicos. Los items sin caducidad (ej: instrumental) pueden dejarse sin fecha.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Resumen
            Section("Resumen") {
                if quantity < minQuantity {
                    Label("Stock bajo: necesitas \(Int(minQuantity - quantity)) más", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    Label("Stock OK", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
                
                // ✅ TAREA D: Mostrar caducidad si está activa
                if hasExpiry {
                    Label("Caduca: \(expiryDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .loadingOverlay(isLoading: isSaving, message: "Añadiendo...")
    }
    
    // MARK: - Add Item
    
    private func addItem() async {
        guard let catalogItemId = selectedItem?.id,
              let kitId = kit.id else { return }
        
        isSaving = true
        
        do {
            let newItem = try await KitService.shared.addItemToKit(
                catalogItemId: catalogItemId,
                kitId: kitId,
                quantity: quantity,
                min: minQuantity,
                max: maxQuantity > minQuantity ? maxQuantity : nil,
                expiry: hasExpiry ? expiryDate : nil,  // ✅ TAREA D: Usar caducidad si está activa
                lot: nil,
                actor: currentUser
            )
            onAdded(newItem)
            dismiss()
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
        
        isSaving = false
    }
}

// MARK: - Create Catalog Item Sheet

struct CreateCatalogItemSheet: View {
    let currentUser: UserFS?
    let onCreated: (CatalogItemFS) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var code = ""
    @State private var name = ""
    @State private var description = ""
    @State private var isCritical = false
    @State private var isSaving = false
    @State private var toast: Toast?
    
    var isValid: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty &&
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Información Básica") {
                    TextField("Código", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    
                    TextField("Nombre", text: $name)
                    
                    TextField("Descripción (opcional)", text: $description)
                }
                
                Section("Configuración") {
                    Toggle(isOn: $isCritical) {
                        Label("Item Crítico", systemImage: "exclamationmark.triangle.fill")
                    }
                }
                
                Section {
                    Text("Los items críticos generan alertas prioritarias cuando el stock es bajo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Nuevo Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task { await createItem() }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .loadingOverlay(isLoading: isSaving, message: "Creando...")
            .toast($toast)
        }
    }
    
    private func createItem() async {
        isSaving = true
        
        do {
            let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
            let newItem = try await CatalogService.shared.createItem(
                code: code.trimmingCharacters(in: .whitespaces),
                name: name.trimmingCharacters(in: .whitespaces),
                description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                critical: isCritical,
                actor: currentUser
            )
            onCreated(newItem)
            dismiss()
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
        
        isSaving = false
    }
}

// MARK: - Base Detail Edit View (MEJORADO)

/// Vista de edición de base con gestión de vehículos
struct BaseDetailEditView: View {
    let base: BaseFS
    let currentUser: UserFS?
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State - Datos de la base
    @State private var name: String
    @State private var address: String
    @State private var active: Bool
    
    // MARK: - State - Vehículos
    @State private var vehicles: [VehicleFS] = []
    @State private var isLoadingVehicles = true
    
    // MARK: - State - UI
    @State private var isSaving = false
    @State private var toast: Toast?
    @State private var alertConfig: AlertConfig?
    
    init(base: BaseFS, currentUser: UserFS?) {
        self.base = base
        self.currentUser = currentUser
        _name = State(initialValue: base.name)
        _address = State(initialValue: base.address)
        _active = State(initialValue: base.active)
    }
    
    var hasChanges: Bool {
        name != base.name || address != base.address || active != base.active
    }
    
    var body: some View {
        Form {
            // MARK: - Sección: Información básica
            Section("Información") {
                LabeledContent("Código", value: base.code)
                TextField("Nombre", text: $name)
                TextField("Dirección", text: $address)
                Toggle("Activa", isOn: $active)
            }
            
            // MARK: - Sección: Vehículos Asignados (NUEVO)
            Section {
                if isLoadingVehicles {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Cargando vehículos...")
                            .foregroundStyle(.secondary)
                    }
                } else if vehicles.isEmpty {
                    HStack {
                        Image(systemName: "car")
                            .foregroundStyle(.secondary)
                        Text("Sin vehículos asignados")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(vehicles) { vehicle in
                        VehicleInBaseRow(
                            vehicle: vehicle,
                            onUnassign: {
                                alertConfig = AlertConfig(
                                    title: "Desasignar Vehículo",
                                    message: "¿Desasignar '\(vehicle.code)' de esta base?",
                                    primaryLabel: "Desasignar",
                                    primaryRole: .destructive,
                                    primaryAction: { Task { await unassignVehicle(vehicle) } },
                                    secondaryLabel: "Cancelar"
                                )
                            }
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Vehículos Asignados (\(vehicles.count))")
                    Spacer()
                    if !vehicles.isEmpty {
                        Button {
                            Task { await loadVehicles() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                }
            } footer: {
                if !vehicles.isEmpty {
                    Text("Desasigna los vehículos antes de eliminar la base")
                        .foregroundStyle(.secondary)
                }
            }
            
            // MARK: - Sección: Eliminar
            Section {
                Button("Eliminar Base", role: .destructive) {
                    if !vehicles.isEmpty {
                        toast = .error("Tiene vehículos: Tiene \(vehicles.count) vehículos asignados")
                    } else {
                        alertConfig = .delete(base.name) {
                            Task { await deleteBase() }
                        }
                    }
                }
            }
        }
        .navigationTitle("Editar Base")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    Task { await saveChanges() }
                }
                .disabled(!hasChanges || isSaving)
            }
        }
        .task {
            await loadVehicles()
        }
        .loadingOverlay(isLoading: isSaving, message: "Guardando...")
        .toast($toast)
        .alert(config: $alertConfig)
    }
    
    // MARK: - Load Vehicles
    
    private func loadVehicles() async {
        isLoadingVehicles = true
        
        guard let baseId = base.id else {
            isLoadingVehicles = false
            return
        }
        
        vehicles = await VehicleService.shared.getVehiclesByBase(baseId: baseId)
        isLoadingVehicles = false
    }
    
    // MARK: - Save Changes
    
    private func saveChanges() async {
        isSaving = true
        
        var updatedBase = base
        updatedBase.name = name
        updatedBase.address = address
        updatedBase.active = active
        
        do {
            try await BaseService.shared.update(updatedBase, actor: currentUser)
            toast = .success("Cambios guardados")
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
        
        isSaving = false
    }
    
    // MARK: - Unassign Vehicle
    
    private func unassignVehicle(_ vehicle: VehicleFS) async {
        guard let vehicleId = vehicle.id else { return }
        
        do {
            try await VehicleService.shared.unassignFromBase(vehicleId: vehicleId, actor: currentUser)
            vehicles.removeAll { $0.id == vehicleId }
            toast = .success("Vehículo '\(vehicle.code)' desasignado")
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
    }
    
    // MARK: - Delete Base
    
    private func deleteBase() async {
        guard let baseId = base.id else { return }
        
        do {
            try await BaseService.shared.delete(baseId: baseId, actor: currentUser)
            dismiss()
        } catch {
            toast = .error(ErrorHelper.friendlyMessage(for: error))
        }
    }
}

// MARK: - Vehicle In Base Row

struct VehicleInBaseRow: View {
    let vehicle: VehicleFS
    let onUnassign: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(vehicle.code)
                        .font(.body)
                    
                    Text(vehicle.vehicleType.shortName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor.opacity(0.2))
                        .foregroundStyle(typeColor)
                        .clipShape(Capsule())
                }
                
                if let plate = vehicle.plate {
                    Text(plate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Botón desasignar
            Button {
                onUnassign()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
    
    private var typeColor: Color {
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



// MARK: - Previews

#if DEBUG
#Preview("Kit Detail Edit") {
    Text("KitDetailEditView Preview")
        .padding()
}

#Preview("Base Detail Edit") {
    Text("BaseDetailEditView Preview")
        .padding()
}
#endif
