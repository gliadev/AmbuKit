//
//  InventoryView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//


import SwiftUI

// MARK: - InventoryView (Firebase)

/// Vista principal de inventario de kits
/// Muestra lista de todos los kits desde Firebase con estados de carga y error
struct InventoryView: View {
    
    // MARK: - Properties
    
    /// Usuario actual (Firebase)
    let currentUser: UserFS
    
    // MARK: - State
    
    /// Lista de kits cargados desde Firebase
    @State private var kits: [KitFS] = []
    
    /// Indica si está cargando datos iniciales
    @State private var isLoading = true
    
    /// Mensaje de error si la carga falla
    @State private var errorMessage: String?
    
    /// Indica si está refrescando (pull to refresh)
    @State private var isRefreshing = false
    
    /// Texto de búsqueda para filtrar kits
    @State private var searchText = ""
    
    // MARK: - Computed Properties
    
    /// Kits filtrados por búsqueda
    private var filteredKits: [KitFS] {
        guard !searchText.isEmpty else { return kits }
        let lowercased = searchText.lowercased()
        return kits.filter {
            $0.code.lowercased().contains(lowercased) ||
            $0.name.lowercased().contains(lowercased)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(message: error)
                } else if kits.isEmpty {
                    emptyView
                } else {
                    kitsList
                }
            }
            .navigationTitle("Kits")
            .searchable(text: $searchText, prompt: "Buscar por código o nombre")
            .toolbar {
                toolbarContent
            }
            .task {
                await loadKits()
            }
            .refreshable {
                await refreshKits()
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Vista de carga inicial
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Cargando kits...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    /// Vista de error con opción de reintentar
    private func errorView(message: String) -> some View {
        ErrorView(
            title: "Error al cargar",
            message: message,
            retryAction: {
                Task {
                    await loadKits()
                }
            }
        )
    }
    
    /// Vista cuando no hay kits
    private var emptyView: some View {
        EmptyStateView(
            "No hay kits",
            message: "Añade kits desde la pestaña Gestión (Programador)."
        )
    }
    
    /// Lista de kits
    private var kitsList: some View {
        List {
            ForEach(filteredKits) { kit in
                NavigationLink {
                    KitDetailView(kit: kit, currentUser: currentUser)
                } label: {
                    KitRowView(kit: kit)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if filteredKits.isEmpty && !searchText.isEmpty {
                EmptyStateView(
                    "Sin resultados",
                    message: "No hay kits que coincidan con '\(searchText)'"
                )
            }
        }
    }
    
    /// Contenido del toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await refreshKits() }
            } label: {
                Label("Actualizar", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing || isLoading)
        }
    }
    
    // MARK: - Data Loading
    
    /// Carga inicial de kits desde Firebase
    private func loadKits() async {
        isLoading = true
        errorMessage = nil
        
        // Cargar kits ordenados por código
        let loadedKits = await KitService.shared.getAllKits()
        
        // Actualizar UI
        kits = loadedKits
        isLoading = false
        
        // Si no hay kits y esperábamos datos, podría ser un error silencioso
        // pero en este caso getAllKits() devuelve [] si hay error
    }
    
    /// Refresca los kits (pull to refresh o botón)
    private func refreshKits() async {
        isRefreshing = true
        
        // Limpiar cache para forzar recarga
        KitService.shared.clearKitCache()
        
        // Recargar
        let loadedKits = await KitService.shared.getAllKits()
        kits = loadedKits
        
        isRefreshing = false
    }
}

// MARK: - KitRowView

/// Fila individual de kit en la lista
private struct KitRowView: View {
    let kit: KitFS
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(kit.name)
                    .font(.body)
                
                HStack(spacing: 8) {
                    // Código
                    Text(kit.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Badge de estado si no es "ok"
                    if kit.status != .active {
                        Text(kit.status.rawValue.uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(kit.status == .maintenance ? .red : .orange)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // Tipo de kit
            Text(kit.type)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - KitDetailView (Firebase)

/// Vista de detalle de un kit con sus items
/// Permite ver y modificar cantidades de stock
struct KitDetailView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// Kit a mostrar (Firebase)
    let kit: KitFS
    
    /// Usuario actual (Firebase)
    let currentUser: UserFS
    
    // MARK: - State
    
    /// Items del kit
    @State private var items: [KitItemFS] = []
    
    /// Cache de items del catálogo (id -> CatalogItemFS)
    @State private var catalogItems: [String: CatalogItemFS] = [:]
    
    /// Indica si está cargando
    @State private var isLoading = true
    
    /// Mensaje de error
    @State private var errorMessage: String?
    
    /// ID del item que se está actualizando (para mostrar spinner)
    @State private var updatingItemId: String?
    
    /// Indica si se puede eliminar el kit
    @State private var canDeleteKit = false
    
    /// Indica si se puede actualizar stock
    @State private var canUpdateStock = false
    
    /// Alerta de confirmación para eliminar
    @State private var showDeleteConfirmation = false
    
    /// Alerta de error
    @State private var showError = false
    @State private var alertErrorMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else if items.isEmpty {
                emptyView
            } else {
                itemsList
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
        .refreshable {
            await refreshItems()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertErrorMessage)
        }
        .alert("Eliminar Kit", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                Task { await deleteKit() }
            }
        } message: {
            Text("¿Estás seguro de eliminar '\(kit.name)'? Esta acción no se puede deshacer.")
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Cargando items...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func errorView(message: String) -> some View {
        ErrorView(
            title: "Error al cargar",
            message: message,
            retryAction: {
                Task { await loadData() }
            }
        )
    }
    
    private var emptyView: some View {
        EmptyStateView(
            "Sin items",
            message: "Este kit no tiene items configurados."
        )
    }
    
    private var itemsList: some View {
        List {
            // Sección de información del kit
            Section {
                kitInfoRow(title: "Código", value: kit.code)
                kitInfoRow(title: "Tipo", value: kit.type)
                kitInfoRow(title: "Estado", value: kit.status.rawValue.capitalized)
                
                if let lastAudit = kit.lastAudit {
                    kitInfoRow(
                        title: "Última auditoría",
                        value: lastAudit.formatted(date: .abbreviated, time: .omitted)
                    )
                }
            } header: {
                Text("Información")
            }
            
            // Sección de items
            Section {
                ForEach(items) { item in
                    KitItemRow(
                        item: item,
                        catalogItem: catalogItems[item.catalogItemId ?? ""],
                        isUpdating: updatingItemId == item.id,
                        canEdit: canUpdateStock,
                        onQuantityChange: { newQty in
                            await updateQuantity(item: item, newQuantity: newQty)
                        }
                    )
                }
            } header: {
                HStack {
                    Text("Items (\(items.count))")
                    Spacer()
                    stockSummary
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    /// Fila de información del kit
    private func kitInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
    
    /// Resumen de stock (bajo/sobre)
    private var stockSummary: some View {
        let lowCount = items.filter { $0.isBelowMinimum }.count
        let overCount = items.filter { $0.isAboveMaximum }.count
        
        return HStack(spacing: 8) {
            if lowCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("\(lowCount)")
                }
                .font(.caption.bold())
                .foregroundStyle(.red)
            }
            
            if overCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("\(overCount)")
                }
                .font(.caption.bold())
                .foregroundStyle(.orange)
            }
        }
    }
    
    /// Contenido del toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if canDeleteKit {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    /// Carga inicial de datos
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        // Cargar permisos en paralelo con los datos
        async let permDeleteTask = AuthorizationServiceFS.allowed(.delete, on: .kit, for: currentUser)
        async let permUpdateTask = AuthorizationServiceFS.allowed(.update, on: .kitItem, for: currentUser)
        async let itemsTask = KitService.shared.getKitItems(kitId: kit.id ?? "")
        async let catalogTask = CatalogService.shared.getAllItems()
        
        // Esperar resultados
        canDeleteKit = await permDeleteTask
        canUpdateStock = await permUpdateTask
        items = await itemsTask
        
        // Construir diccionario de catálogo
        let allCatalogItems: [CatalogItemFS] = await catalogTask
        var newCatalogItems: [String: CatalogItemFS] = [:]
        for item in allCatalogItems {
            if let id = item.id {
                newCatalogItems[id] = item
            }
        }
        catalogItems = newCatalogItems
        
        isLoading = false
    }
    
    /// Refresca los items
    private func refreshItems() async {
        KitService.shared.clearKitItemCache()
        items = await KitService.shared.getKitItems(kitId: kit.id ?? "")
    }
    
    // MARK: - Actions
    
    /// Actualiza la cantidad de un item (actualización optimista)
    private func updateQuantity(item: KitItemFS, newQuantity: Double) async {
        guard let itemId = item.id else { return }
        
        // Guardar valor original para posible rollback
        let originalQuantity = item.quantity
        
        // 1. Actualización optimista del UI
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].quantity = newQuantity
        }
        
        // 2. Mostrar indicador de carga
        updatingItemId = itemId
        
        // 3. Actualizar en Firebase
        do {
            var updatedItem = item
            updatedItem.quantity = newQuantity
            updatedItem.updatedAt = Date()
            
            try await KitService.shared.updateKitItem(kitItem: updatedItem, actor: currentUser)
            
        } catch {
            // 4. Rollback si falla
            if let index = items.firstIndex(where: { $0.id == itemId }) {
                items[index].quantity = originalQuantity
            }
            
            // Mostrar error
            alertErrorMessage = "Error al actualizar: \(error.localizedDescription)"
            showError = true
        }
        
        // 5. Quitar indicador de carga
        updatingItemId = nil
    }
    
    /// Elimina el kit
    private func deleteKit() async {
        do {
            try await KitService.shared.deleteKit(kitId: kit.id ?? "", actor: currentUser)
            
            // Volver atrás
            dismiss()
            
        } catch {
            alertErrorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Preview

#if DEBUG
struct InventoryViewPreview: PreviewProvider {
    static var previews: some View {
        InventoryView(currentUser: previewUser)
            .previewDisplayName("Inventory View")
    }
    
    static let previewUser = UserFS(
        id: "user_preview",
        uid: "uid_preview",
        username: "preview",
        fullName: "Preview User",
        email: "preview@ambukit.com",
        active: true,
        roleId: "role_programmer",
        baseId: "base_bilbao1"
    )
}
#endif 
