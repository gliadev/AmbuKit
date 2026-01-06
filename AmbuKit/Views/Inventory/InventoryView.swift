//
//  InventoryView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//
//  TAREA 16.2: Vista de inventario mejorada - 100% Firebase
//
//  Características:
//  - Badges de estado coloridos
//  - Iconos por tipo de kit
//  - Búsqueda
//  - Pull to refresh
//  - Filtros
//

import SwiftUI

// MARK: - InventoryView

/// Vista principal del inventario de kits - 100% Firebase
struct InventoryView: View {
    
    // MARK: - Properties
    
    let currentUser: UserFS
    
    // MARK: - State
    
    @State private var kits: [KitFS] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedFilter: KitFilter = .all
    
    // MARK: - Filtered Kits
    
    private var filteredKits: [KitFS] {
        var result = kits
        
        // Aplicar filtro
        switch selectedFilter {
        case .all:
            break
        case .active:
            result = result.filter { $0.status == .active }
        case .needsAudit:
            result = result.filter { $0.needsAudit }
        case .unassigned:
            result = result.filter { !$0.isAssigned }
        case .maintenance:
            result = result.filter { $0.status == .maintenance }
        }
        
        // Aplicar búsqueda
        if !searchText.isEmpty {
            result = result.filter {
                $0.code.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if kits.isEmpty {
                    emptyStateView
                } else {
                    kitsList
                }
            }
            .navigationTitle("Inventario")
            .searchable(text: $searchText, prompt: "Buscar kits...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    filterMenu
                }
            }
        }
        .task {
            await loadKits()
        }
    }
    
    // MARK: - Filter Menu
    
    private var filterMenu: some View {
        Menu {
            ForEach(KitFilter.allCases, id: \.self) { filter in
                Button {
                    selectedFilter = filter
                } label: {
                    HStack {
                        Text(filter.label)
                        if selectedFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: selectedFilter == .all
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Cargando kits...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No hay kits", systemImage: "shippingbox")
        } description: {
            Text("Añade kits desde la pestaña Gestión.")
        }
    }
    
    // MARK: - Kits List
    
    private var kitsList: some View {
        List {
            // Header con estadísticas
            statsHeader
            
            // Lista de kits
            ForEach(filteredKits) { kit in
                NavigationLink {
                    KitDetailView(kit: kit, currentUser: currentUser)
                } label: {
                    KitRowView(kit: kit)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadKits()
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        Section {
            HStack(spacing: 12) {
                StatBadge(
                    count: kits.count,
                    label: "Total",
                    color: .blue,
                    icon: "shippingbox.fill"
                )
                
                StatBadge(
                    count: kits.filter { $0.status == .active }.count,
                    label: "Activos",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                StatBadge(
                    count: kits.filter { $0.needsAudit }.count,
                    label: "Auditoría",
                    color: .purple,
                    icon: "clipboard.fill"
                )
                
                StatBadge(
                    count: kits.filter { !$0.isAssigned }.count,
                    label: "Libres",
                    color: .orange,
                    icon: "car.fill"
                )
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Load Kits
    
    private func loadKits() async {
        isLoading = kits.isEmpty
        kits = await KitService.shared.getAllKits()
        isLoading = false
    }
}

// MARK: - Kit Filter Enum

enum KitFilter: CaseIterable {
    case all
    case active
    case needsAudit
    case unassigned
    case maintenance
    
    var label: String {
        switch self {
        case .all: return "Todos"
        case .active: return "Activos"
        case .needsAudit: return "Auditoría"
        case .unassigned: return "Sin Asignar"
        case .maintenance: return "Mantenimiento"
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let count: Int
    let label: String
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
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Kit Row View

struct KitRowView: View {
    let kit: KitFS
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono del tipo de kit
            kitTypeIcon
            
            // Info principal
            VStack(alignment: .leading, spacing: 4) {
                // Código y badge de estado
                HStack {
                    Text(kit.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    statusBadge
                }
                
                // Nombre
                Text(kit.name)
                    .font(.headline)
                    .lineLimit(1)
                
                // Info adicional
                HStack(spacing: 8) {
                    // Tipo de kit
                    Text(kit.type)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(kitTypeColor.opacity(0.1))
                        .foregroundStyle(kitTypeColor)
                        .clipShape(Capsule())
                    
                    // Asignación
                    if kit.isAssigned {
                        HStack(spacing: 2) {
                            Image(systemName: "car.fill")
                            Text("Asignado")
                        }
                        .font(.caption)
                        .foregroundStyle(.green)
                    }
                    
                    // Auditoría
                    if kit.needsAudit {
                        HStack(spacing: 2) {
                            Image(systemName: "clipboard")
                            Text("Auditar")
                        }
                        .font(.caption)
                        .foregroundStyle(.purple)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Kit Type Icon
    
    @ViewBuilder
    private var kitTypeIcon: some View {
        ZStack {
            Circle()
                .fill(kitTypeColor.opacity(0.15))
                .frame(width: 44, height: 44)
            
            Image(systemName: kitTypeSystemImage)
                .font(.title3)
                .foregroundStyle(kitTypeColor)
        }
    }
    
    /// Icono del sistema según el tipo de kit
    private var kitTypeSystemImage: String {
        let type = kit.type.lowercased()
        
        if type.contains("sva") {
            return "cross.case.fill"
        } else if type.contains("svb") {
            return "shippingbox.fill"
        } else if type.contains("ped") {
            return "figure.and.child.holdinghands"
        } else if type.contains("trauma") {
            return "bandage.fill"
        } else if type.contains("ampul") {
            return "pills.fill"
        } else {
            return "cross.case.fill"
        }
    }
    
    /// Color según el tipo de kit
    private var kitTypeColor: Color {
        let type = kit.type.lowercased()
        
        if type.contains("sva") {
            return .red
        } else if type.contains("svb") {
            return .blue
        } else if type.contains("ped") {
            return .pink
        } else if type.contains("trauma") {
            return .orange
        } else if type.contains("ampul") {
            return .purple
        } else {
            return .blue
        }
    }
    
    // MARK: - Status Badge
    
    @ViewBuilder
    private var statusBadge: some View {
        Text(kit.status.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }
    
    /// Color según el estado del kit
    private var statusColor: Color {
        switch kit.status {
        case .active:
            return .green
        case .inactive:
            return .gray
        case .maintenance:
            return .orange
        case .expired:
            return .red
        }
    }
}

// MARK: - Preview

#Preview("Con datos") {
    let user = UserFS(
        id: "1", uid: "uid1", username: "admin",
        fullName: "Admin", email: "admin@test.com",
        active: true, roleId: "role_programmer", baseId: nil
    )
    
    return InventoryView(currentUser: user)
}
