//
//  AlertsView.swift
//  AmbuKit
//
//  Created by Adolfo on 25/12/25.
//  TAREA 16.4: Alertas completas con datos reales de Firebase
//
//  Carga:
//  - Items con stock bajo (quantity < min)
//  - Items próximos a caducar (< 30 días)
//  - Items caducados
//  TAREA 16.9: Alertas con navegación a kits/items
//

import SwiftUI

// MARK: - AlertsView

struct AlertsView: View {
    
    // MARK: - Properties
    
    let currentUser: UserFS
    
    // MARK: - State
    
    @State private var isLoading = true
    @State private var selectedFilter: AlertFilter = .all
    
    // Alertas
    @State private var lowStockItems: [KitItemFS] = []
    @State private var expiringItems: [KitItemFS] = []
    @State private var expiredItems: [KitItemFS] = []
    
    // Cache para navegación y nombres
    @State private var kitsCache: [String: KitFS] = [:]
    @State private var catalogCache: [String: CatalogItemFS] = [:]
    
    // MARK: - Computed
    
    private var allAlerts: [AlertItem] {
        var alerts: [AlertItem] = []
        
        // Caducados (crítico)
        for item in expiredItems {
            let catalogItem = catalogCache[item.catalogItemId ?? ""]
            alerts.append(AlertItem(
                kitItem: item,
                type: .expired,
                kit: kitsCache[item.kitId ?? ""],
                catalogItemName: catalogItem?.name
            ))
        }
        
        // Stock bajo
        for item in lowStockItems {
            let catalogItem = catalogCache[item.catalogItemId ?? ""]
            alerts.append(AlertItem(
                kitItem: item,
                type: .lowStock,
                kit: kitsCache[item.kitId ?? ""],
                catalogItemName: catalogItem?.name
            ))
        }
        
        // Próximos a caducar
        for item in expiringItems {
            let catalogItem = catalogCache[item.catalogItemId ?? ""]
            alerts.append(AlertItem(
                kitItem: item,
                type: .expiring,
                kit: kitsCache[item.kitId ?? ""],
                catalogItemName: catalogItem?.name
            ))
        }
        
        return alerts
    }
    
    private var filteredAlerts: [AlertItem] {
        switch selectedFilter {
        case .all:
            return allAlerts
        case .lowStock:
            return allAlerts.filter { $0.type == .lowStock }
        case .expiring:
            return allAlerts.filter { $0.type == .expiring }
        case .expired:
            return allAlerts.filter { $0.type == .expired }
        }
    }
    
    // MARK: - Filter Enum
    
    enum AlertFilter: String, CaseIterable {
        case all = "Todas"
        case lowStock = "Stock Bajo"
        case expiring = "Por Caducar"
        case expired = "Caducados"
        
        var color: Color {
            switch self {
            case .all: return .blue
            case .lowStock: return .red
            case .expiring: return .orange
            case .expired: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .all: return "bell.fill"
            case .lowStock: return "arrow.down.circle.fill"
            case .expiring: return "clock.badge.exclamationmark.fill"
            case .expired: return "xmark.circle.fill"
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if allAlerts.isEmpty {
                    emptyView
                } else {
                    // Stats header
                    statsHeader
                    
                    // Filtros
                    filterSection
                    
                    // Lista de alertas
                    alertsList
                }
            }
            .navigationTitle("Alertas")
            .refreshable {
                await loadAlerts()
            }
        }
        .task {
            await loadAlerts()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Cargando alertas...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        ContentUnavailableView(
            "Sin alertas",
            systemImage: "checkmark.circle.fill",
            description: Text("¡Todo está en orden! No hay alertas pendientes.")
        )
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                AlertStatBadge(
                    count: allAlerts.count,
                    title: "Total",
                    color: .blue,
                    icon: "bell.fill"
                )
                
                AlertStatBadge(
                    count: lowStockItems.count,
                    title: "Stock Bajo",
                    color: .red,
                    icon: "arrow.down.circle.fill"
                )
                
                AlertStatBadge(
                    count: expiringItems.count,
                    title: "Por Caducar",
                    color: .orange,
                    icon: "clock.fill"
                )
                
                AlertStatBadge(
                    count: expiredItems.count,
                    title: "Caducados",
                    color: .red,
                    icon: "xmark.circle.fill"
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AlertFilter.allCases, id: \.self) { filter in
                    AlertFilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        color: filter.color,
                        isSelected: selectedFilter == filter,
                        count: countForFilter(filter)
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    private func countForFilter(_ filter: AlertFilter) -> Int {
        switch filter {
        case .all: return allAlerts.count
        case .lowStock: return lowStockItems.count
        case .expiring: return expiringItems.count
        case .expired: return expiredItems.count
        }
    }
    
    // MARK: - Alerts List
    
    private var alertsList: some View {
        List {
            ForEach(filteredAlerts) { alert in
                NavigationLink {
                    // Navegar al kit si existe
                    if let kit = alert.kit {
                        KitDetailView(kit: kit, currentUser: currentUser)
                    } else {
                        AlertItemDetailView(alertItem: alert)
                    }
                } label: {
                    AlertRowView(alert: alert)
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Load Alerts
    
    private func loadAlerts() async {
        isLoading = true
        
        // Cargar alertas
        async let lowStockTask = KitService.shared.getLowStockItems()
        async let expiringTask = KitService.shared.getExpiringItems()
        async let expiredTask = KitService.shared.getExpiredItems()
        async let kitsTask = KitService.shared.getAllKits()
        async let catalogTask = CatalogService.shared.getAllItems()
        
        lowStockItems = await lowStockTask
        expiringItems = await expiringTask
        expiredItems = await expiredTask
        
        // Crear cache de kits para navegación
        let allKits = await kitsTask
        kitsCache = Dictionary(uniqueKeysWithValues: allKits.compactMap { kit in
            guard let id = kit.id else { return nil }
            return (id, kit)
        })
        
        // Crear cache de catalog items para nombres
        let allCatalogItems = await catalogTask
        catalogCache = Dictionary(uniqueKeysWithValues: allCatalogItems.compactMap { item in
            guard let id = item.id else { return nil }
            return (id, item)
        })
        
        isLoading = false
    }
}

// MARK: - Alert Item Model

struct AlertItem: Identifiable {
    let id = UUID()
    let kitItem: KitItemFS
    let type: AlertType
    let kit: KitFS?
    let catalogItemName: String?
    
    enum AlertType {
        case lowStock
        case expiring
        case expired
        
        var title: String {
            switch self {
            case .lowStock: return "Stock Bajo"
            case .expiring: return "Por Caducar"
            case .expired: return "Caducado"
            }
        }
        
        var color: Color {
            switch self {
            case .lowStock: return .red
            case .expiring: return .orange
            case .expired: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .lowStock: return "arrow.down.circle.fill"
            case .expiring: return "clock.badge.exclamationmark.fill"
            case .expired: return "xmark.circle.fill"
            }
        }
    }
}

// MARK: - Alert Row View

struct AlertRowView: View {
    let alert: AlertItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono de alerta
            ZStack {
                Circle()
                    .fill(alert.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: alert.type.icon)
                    .font(.title3)
                    .foregroundStyle(alert.type.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Nombre del item (desde cache o ID)
                Text(alert.catalogItemName ?? alert.kitItem.catalogItemId ?? "Item desconocido")
                    .font(.headline)
                
                // Kit asociado
                HStack(spacing: 4) {
                    if let kit = alert.kit {
                        Image(systemName: "cross.case.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text(kit.name)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else {
                        Text("Kit desconocido")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Detalle según tipo
                HStack(spacing: 8) {
                    // Badge de tipo
                    Text(alert.type.title)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(alert.type.color.opacity(0.15))
                        .foregroundStyle(alert.type.color)
                        .clipShape(Capsule())
                    
                    // Info adicional
                    if alert.type == .lowStock {
                        Text("Stock: \(Int(alert.kitItem.quantity))/\(Int(alert.kitItem.min))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let expiry = alert.kitItem.expiry {
                        Text("Caduca: \(expiry.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Alert Item Detail View

struct AlertItemDetailView: View {
    let alertItem: AlertItem
    
    var body: some View {
        List {
            Section("Información del Item") {
                LabeledContent("Nombre", value: alertItem.catalogItemName ?? "Desconocido")
                LabeledContent("Cantidad", value: "\(Int(alertItem.kitItem.quantity))")
                LabeledContent("Mínimo", value: "\(Int(alertItem.kitItem.min))")
                
                if let max = alertItem.kitItem.max {
                    LabeledContent("Máximo", value: "\(Int(max))")
                }
                
                if let expiry = alertItem.kitItem.expiry {
                    LabeledContent("Caducidad", value: expiry.formatted(date: .long, time: .omitted))
                }
                
                if let lot = alertItem.kitItem.lot, !lot.isEmpty {
                    LabeledContent("Lote", value: lot)
                }
            }
            
            Section("Alerta") {
                HStack {
                    Image(systemName: alertItem.type.icon)
                        .foregroundStyle(alertItem.type.color)
                    Text(alertItem.type.title)
                        .foregroundStyle(alertItem.type.color)
                }
            }
            
            if let kit = alertItem.kit {
                Section("Kit") {
                    LabeledContent("Nombre", value: kit.name)
                    LabeledContent("Código", value: kit.code)
                    LabeledContent("Tipo", value: kit.type)
                }
            }
        }
        .navigationTitle("Detalle de Alerta")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Alert Stat Badge

private struct AlertStatBadge: View {
    let count: Int
    let title: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text("\(count)")
                    .font(.title3.bold())
            }
            .foregroundStyle(color)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 70)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Alert Filter Chip

private struct AlertFilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                if count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Alerts View") {
    let user = UserFS(
        id: "1", uid: "uid1", username: "admin",
        fullName: "Admin", email: "admin@test.com",
        active: true, roleId: "role_programmer", baseId: nil
    )
    
    return AlertsView(currentUser: user)
}
