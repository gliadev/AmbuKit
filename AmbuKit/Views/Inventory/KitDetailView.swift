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
    @State private var showAuditSheet = false
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoading {
                KitDetailLoadingView()
            } else if items.isEmpty {
                KitDetailEmptyStateView()
            } else {
                KitDetailContentView(
                    items: items,
                    catalogDict: catalogDict,
                    kit: kit,
                    currentUser: currentUser,
                    canUpdateStock: canUpdateStock,
                    updatingItemId: updatingItemId,
                    showAuditSheet: $showAuditSheet,
                    onItemQuantityChange: { item, newQuantity in
                        await updateItemQuantity(item: item, newQuantity: newQuantity)
                    },
                    onRefresh: { await loadData() }
                )
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
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Botón refresh
        ToolbarItem(placement: .primaryAction) {
            Button("Actualizar", systemImage: "arrow.clockwise") {
                Task { await loadData() }
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

// MARK: - KitDetailLoadingView

private struct KitDetailLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Cargando items...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - KitDetailEmptyStateView

private struct KitDetailEmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Sin items", systemImage: "tray")
        } description: {
            Text("Este kit no tiene items configurados.")
        }
    }
}

// MARK: - KitDetailContentView

private struct KitDetailContentView: View {
    let items: [KitItemFS]
    let catalogDict: [String: CatalogItemFS]
    let kit: KitFS
    let currentUser: UserFS
    let canUpdateStock: Bool
    let updatingItemId: String?
    @Binding var showAuditSheet: Bool
    let onItemQuantityChange: (KitItemFS, Double) async -> Void
    let onRefresh: () async -> Void

    var body: some View {
        List {
            KitInfoSection(kit: kit, showAuditSheet: $showAuditSheet)
            KitStatsSection(items: items)
            KitItemsSection(
                items: items,
                catalogDict: catalogDict,
                canUpdateStock: canUpdateStock,
                updatingItemId: updatingItemId,
                onItemQuantityChange: onItemQuantityChange
            )
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await onRefresh()
        }
    }
}

// MARK: - KitInfoSection

private struct KitInfoSection: View {
    let kit: KitFS
    @Binding var showAuditSheet: Bool

    private var statusColor: Color {
        switch kit.status {
        case .active: return .green
        case .inactive: return .gray
        case .maintenance: return .orange
        case .expired: return .red
        }
    }

    var body: some View {
        Section {
            HStack {
                Label("Código", systemImage: "number")
                Spacer()
                Text(kit.code)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Tipo", systemImage: kit.kitType.systemImage)
                Spacer()
                Text(kit.type)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(kit.kitType.color.opacity(0.15))
                    .foregroundStyle(kit.kitType.color)
                    .clipShape(Capsule())
            }

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

            Button {
                showAuditSheet = true
            } label: {
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
            }
            .buttonStyle(.plain)

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
}

// MARK: - KitStatsSection

private struct KitStatsSection: View {
    let items: [KitItemFS]

    var body: some View {
        Section {
            HStack(spacing: 20) {
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

                VStack {
                    Text("\(items.count(where: { $0.isBelowMinimum }))")
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                    Text("Stock Bajo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()

                VStack {
                    Text("\(items.count(where: { $0.isExpiringSoon || $0.isExpired }))")
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
}

// MARK: - KitItemsSection

private struct KitItemsSection: View {
    let items: [KitItemFS]
    let catalogDict: [String: CatalogItemFS]
    let canUpdateStock: Bool
    let updatingItemId: String?
    let onItemQuantityChange: (KitItemFS, Double) async -> Void

    var body: some View {
        Section {
            ForEach(items) { item in
                KitItemRow(
                    item: item,
                    catalogItem: catalogDict[item.catalogItemId ?? ""],
                    isUpdating: updatingItemId == item.id,
                    canEdit: canUpdateStock,
                    onQuantityChange: { newQuantity in
                        await onItemQuantityChange(item, newQuantity)
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
