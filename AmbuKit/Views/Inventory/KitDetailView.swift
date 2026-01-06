//
//  KitDetailView.swift
//  AmbuKit
//
//  Created by Adolfo on 26/12/25.
//  TAREA 16.3: Vista de detalle de kit - 100% Firebase
//
//  Características:
//  - Info del kit (código, tipo, estado, auditoría)
//  - Lista de items con datos del catálogo
//  - Stepper para modificar cantidades
//  - Indicadores de stock bajo/alto
//  - Indicadores de caducidad
//  - Permisos verificados
//  - Botón de editar kit (Programador/Logística)
//  NOTA: Usa KitItemRow de Views/Components/KitItemRow/
//

import SwiftUI

// MARK: - KitDetailView

/// Vista de detalle de un kit con sus items - 100% Firebase
struct KitDetailView: View {
    
    // MARK: - Properties
    
    let kit: KitFS
    let currentUser: UserFS
    
    // MARK: - State
    
    @State private var items: [KitItemFS] = []
    @State private var catalogDict: [String: CatalogItemFS] = [:]
    @State private var isLoading = true
    @State private var canUpdateStock = false
    @State private var canEditKit = false  // ✅ NUEVO: Permiso para editar kit
    @State private var errorMessage: String?
    @State private var updatingItemId: String?
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if items.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .navigationTitle(kit.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarContent
        }
        .task {
            await loadData()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Botón refresh
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await loadData() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
        
        // ✅ NUEVO: Botón Editar (solo Programador y Logística)
        ToolbarItem(placement: .secondaryAction) {
            if canEditKit {
                NavigationLink {
                    KitDetailEditView(kit: kit, currentUser: currentUser)
                } label: {
                    Label("Editar Kit", systemImage: "pencil.circle")
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Cargando items...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Sin items", systemImage: "tray")
        } description: {
            Text("Este kit no tiene items configurados.")
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        List {
            // Sección: Info del kit
            kitInfoSection
            
            // Sección: Estadísticas rápidas
            statsSection
            
            // Sección: Items del kit
            itemsSection
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadData()
        }
    }
    
    // MARK: - Kit Info Section
    
    private var kitInfoSection: some View {
        Section {
            // Código
            HStack {
                Label("Código", systemImage: "number")
                Spacer()
                Text(kit.code)
                    .foregroundStyle(.secondary)
            }
            
            // Tipo
            HStack {
                Label("Tipo", systemImage: kitTypeIcon)
                Spacer()
                Text(kit.type)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(kitTypeColor.opacity(0.15))
                    .foregroundStyle(kitTypeColor)
                    .clipShape(Capsule())
            }
            
            // Estado
            HStack {
                Label("Estado", systemImage: kit.status.icon)
                Spacer()
                Text(kit.status.displayName)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
            
            // Última auditoría
            HStack {
                Label("Auditoría", systemImage: "clipboard")
                Spacer()
                if let lastAudit = kit.lastAudit {
                    Text(lastAudit, style: .date)
                        .foregroundStyle(kit.needsAudit ? .orange : .secondary)
                } else {
                    Text("Nunca")
                        .foregroundStyle(.orange)
                }
                
                if kit.needsAudit {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            
            // Asignación
            HStack {
                Label("Vehículo", systemImage: "car.fill")
                Spacer()
                if kit.isAssigned {
                    Text("Asignado")
                        .foregroundStyle(.green)
                } else {
                    Text("Sin asignar")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Información del Kit")
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        Section {
            HStack(spacing: 20) {
                // Total items
                VStack {
                    Text("\(items.count)")
                        .font(.title2.bold())
                        .foregroundStyle(.blue)
                    Text("Items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // Stock bajo
                VStack {
                    Text("\(items.filter { $0.isBelowMinimum }.count)")
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                    Text("Stock Bajo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // Próximos a caducar
                VStack {
                    Text("\(items.filter { $0.isExpiringSoon || $0.isExpired }.count)")
                        .font(.title2.bold())
                        .foregroundStyle(.red)
                    Text("Caducidad")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Items Section
    
    private var itemsSection: some View {
        Section {
            ForEach(items) { item in
                KitItemRow(
                    item: item,
                    catalogItem: catalogDict[item.catalogItemId ?? ""],
                    isUpdating: updatingItemId == item.id,
                    canEdit: canUpdateStock,
                    onQuantityChange: { newQuantity in
                        await updateItemQuantity(item: item, newQuantity: newQuantity)
                    }
                )
            }
        } header: {
            HStack {
                Text("Items (\(items.count))")
                Spacer()
                if canUpdateStock {
                    Text("Pulsa +/- para ajustar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var kitTypeIcon: String {
        let type = kit.type.lowercased()
        if type.contains("sva") { return "cross.case.fill" }
        if type.contains("svb") { return "shippingbox.fill" }
        if type.contains("ped") { return "figure.and.child.holdinghands" }
        if type.contains("trauma") { return "bandage.fill" }
        if type.contains("ampul") { return "pills.fill" }
        return "cross.case.fill"
    }
    
    private var kitTypeColor: Color {
        let type = kit.type.lowercased()
        if type.contains("sva") { return .red }
        if type.contains("svb") { return .blue }
        if type.contains("ped") { return .pink }
        if type.contains("trauma") { return .orange }
        if type.contains("ampul") { return .purple }
        return .blue
    }
    
    private var statusColor: Color {
        switch kit.status {
        case .active: return .green
        case .inactive: return .gray
        case .maintenance: return .orange
        case .expired: return .red
        }
    }
    
    // MARK: - Load Data
    
    private func loadData() async {
        isLoading = items.isEmpty
        
        guard let kitId = kit.id else {
            errorMessage = "El kit no tiene ID válido"
            isLoading = false
            return
        }
        
        // Cargar en paralelo
        async let itemsTask = KitService.shared.getKitItems(kitId: kitId)
        async let catalogTask = CatalogService.shared.getAllItems()
        async let updatePermissionTask = AuthorizationServiceFS.allowed(.update, on: .kitItem, for: currentUser)
        async let editKitPermissionTask = AuthorizationServiceFS.allowed(.update, on: .kit, for: currentUser)  // ✅ NUEVO
        
        items = await itemsTask
        let allCatalog = await catalogTask
        canUpdateStock = await updatePermissionTask
        canEditKit = await editKitPermissionTask  // ✅ NUEVO
        
        // Crear diccionario de catálogo
        var catalog: [String: CatalogItemFS] = [:]
        for item in allCatalog {
            if let id = item.id {
                catalog[id] = item
            }
        }
        catalogDict = catalog
        
        isLoading = false
    }
    
    // MARK: - Update Item Quantity
    
    private func updateItemQuantity(item: KitItemFS, newQuantity: Double) async {
        updatingItemId = item.id
        
        let updatedItem = item.withQuantity(newQuantity)
        
        do {
            try await KitService.shared.updateKitItem(kitItem: updatedItem, actor: currentUser)
            
            // Actualizar lista local
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = updatedItem
            }
        } catch {
            errorMessage = "Error al actualizar: \(error.localizedDescription)"
        }
        
        updatingItemId = nil
    }
}

// MARK: - Preview

#Preview("Con items") {
    NavigationStack {
        KitDetailView(
            kit: KitFS(
                id: "kit_001",
                code: "KIT-SVA-001",
                name: "Kit SVA Principal",
                type: "SVA",
                status: .active,
                lastAudit: Date().addingTimeInterval(-86400 * 45),
                vehicleId: "vehicle_001"
            ),
            currentUser: UserFS(
                id: "user_1",
                uid: "uid_1",
                username: "admin",
                fullName: "Admin User",
                email: "admin@test.com",
                active: true,
                roleId: "role_programmer",
                baseId: nil
            )
        )
    }
}
