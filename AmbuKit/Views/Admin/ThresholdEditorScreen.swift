//
//  ThresholdEditorScreen.swift
//  AmbuKit
//
//  Created by Adolfo on 10/12/25.
//


import SwiftUI

// MARK: - ThresholdEditorScreen

/// Pantalla completa para editar los umbrales (min/max) de los items de un kit
struct ThresholdEditorScreen: View {
    
    // MARK: - Properties
    
    let kit: KitFS
    let currentUser: UserFS
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var items: [KitItemFS] = []
    @State private var catalogDict: [String: CatalogItemFS] = [:]
    @State private var isLoading = true
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
            Section {
                kitInfoHeader
            }
            
            Section {
                ForEach(items) { item in
                    ThresholdRowView(
                        item: item,
                        catalogItem: catalogDict[item.catalogItemId ?? ""],
                        currentUser: currentUser,
                        onSaved: nil
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
            Image(systemName: kitIcon)
                .font(.title)
                .foregroundStyle(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(kit.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Label(kit.code, systemImage: "qrcode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(kit.type)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                
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
    
    /// KitType: SVB, SVAe, SVA, custom
    private var kitIcon: String {
        switch kit.type {
        case "SVA":
            return "cross.case.fill"
        case "SVAe":
            return "cross.case.fill"
        case "SVB":
            return "shippingbox.fill"
        case "custom":
            return "square.grid.2x2.fill"
        default:
            return "shippingbox"
        }
    }
    
    // MARK: - Load Data
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        guard let kitId = kit.id else {
            errorMessage = "El kit no tiene ID válido"
            isLoading = false
            return
        }
        
        async let itemsTask = KitService.shared.getKitItems(kitId: kitId)
        async let catalogTask = CatalogService.shared.getAllItems()
        
        items = await itemsTask
        let allCatalog = await catalogTask
        
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
        code: "KIT-SVB-001",
        name: "Kit SVB Ambulancia 1",
        type: "SVB",
        status: .active,
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
