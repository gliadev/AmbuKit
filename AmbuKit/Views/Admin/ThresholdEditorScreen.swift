//
//  ThresholdEditorScreen.swift
//  AmbuKit
//
//  Created by Adolfo on 10/12/25.
//


import SwiftUI

// MARK: - ThresholdEditorScreen

/// Pantalla completa para editar los umbrales (min/max) de los items de un kit
///
/// **Características:**
/// - Lista todos los items del kit con sus umbrales actuales
/// - Permite editar min/max de cada item
/// - Muestra nombre del item desde el catálogo
/// - Feedback visual de guardado (loading/success/error)
///
/// **Permisos:**
/// - Requiere permiso de edición de umbrales (Programador o Logística)
struct ThresholdEditorScreen: View {
    
    // MARK: - Properties
    
    /// Kit cuyos umbrales se van a editar
    let kit: KitFS
    
    /// Usuario actual de Firebase
    let currentUser: UserFS
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    /// Items del kit
    @State private var items: [KitItemFS] = []
    
    /// Diccionario de catálogo (itemId -> CatalogItemFS)
    @State private var catalogDict: [String: CatalogItemFS] = [:]
    
    /// Estado de carga
    @State private var isLoading = true
    
    /// Mensaje de error
    @State private var errorMessage: String?
    
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
                itemsListView
            }
        }
        .navigationTitle(kit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(kit.name)
                        .font(.headline)
                    Text(kit.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.blue)
            
            Text("Cargando items del kit...")
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
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        ContentUnavailableView {
            Label("Sin items", systemImage: "shippingbox")
        } description: {
            Text("Este kit no tiene items configurados.")
        } actions: {
            Button("Volver") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Items List View
    
    private var itemsListView: some View {
        List {
            // Header con info del kit
            Section {
                kitInfoHeader
            }
            
            // Items del kit
            Section {
                ForEach(items) { item in
                    ThresholdRowView(
                        item: item,
                        catalogItem: catalogDict[item.catalogItemId],
                        currentUser: currentUser,
                        onSaved: {
                            // Callback opcional cuando se guarda
                            // Podríamos recargar datos si es necesario
                        }
                    )
                }
            } header: {
                HStack {
                    Text("Items (\(items.count))")
                    Spacer()
                    Text("Ajusta min/máx")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Kit Info Header
    
    private var kitInfoHeader: some View {
        HStack(spacing: 16) {
            // Icono
            Image(systemName: kitIcon)
                .font(.title)
                .foregroundStyle(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(kit.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    // Código
                    Label(kit.code, systemImage: "qrcode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Tipo
                    Text(kit.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                
                // Vehículo asignado
                if let vehicleId = kit.vehicleId, !vehicleId.isEmpty {
                    Label("Asignado a vehículo", systemImage: "car.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    
    private var kitIcon: String {
        switch kit.type {
        case .SVA, .SVAe:
            return "cross.case.fill"
        case .SVB:
            return "shippingbox.fill"
        case .pediatrico:
            return "figure.and.child.holdinghands"
        case .trauma:
            return "bandage.fill"
        case .ampulario:
            return "pills.fill"
        }
    }
    
    // MARK: - Load Data
    
    /// Carga los items del kit y el catálogo
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        guard let kitId = kit.id else {
            errorMessage = "El kit no tiene ID válido"
            isLoading = false
            return
        }
        
        // Cargar en paralelo: items del kit y catálogo completo
        async let itemsTask = KitService.shared.getKitItems(kitId: kitId)
        async let catalogTask = CatalogService.shared.getAllItems()
        
        items = await itemsTask
        let allCatalog = await catalogTask
        
        // Crear diccionario de catálogo para acceso rápido
        var catalog: [String: CatalogItemFS] = [:]
        for item in allCatalog {
            if let id = item.id {
                catalog[id] = item
            }
        }
        catalogDict = catalog
        
        #if DEBUG
        print("📦 ThresholdEditorScreen cargado:")
        print("   - Kit: \(kit.name) (\(kitId))")
        print("   - Items: \(items.count)")
        print("   - Catálogo: \(catalogDict.count) items")
        #endif
        
        isLoading = false
    }
}

// MARK: - Preview

#if DEBUG
struct ThresholdEditorScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ThresholdEditorScreen(
                kit: previewKit,
                currentUser: previewUser
            )
        }
    }
    
    static let previewKit = KitFS(
        id: "kit_001",
        code: "KIT-SVB-001",
        name: "Kit SVB Ambulancia 1",
        type: .SVB,
        status: "activo",
        vehicleId: "vehicle_001"
    )
    
    static let previewUser = UserFS(
        id: "user_prog",
        uid: "uid_prog",
        username: "admin",
        fullName: "Administrador",
        email: "admin@ambukit.com",
        active: true,
        roleId: "role_programmer",
        baseId: nil
    )
}
#endif
