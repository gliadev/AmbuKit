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
                $0.code.localizedStandardContains(searchText) ||
                $0.name.localizedStandardContains(searchText)
            }
        }
        
        return result
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    InventoryLoadingView()
                } else if kits.isEmpty {
                    InventoryEmptyStateView()
                } else {
                    InventoryKitsList(
                        filteredKits: filteredKits,
                        kits: kits,
                        currentUser: currentUser,
                        onRefresh: { await loadKits() }
                    )
                }
            }
            .navigationTitle("Inventario")
            .searchable(text: $searchText, prompt: "Buscar kits...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    InventoryFilterMenu(selectedFilter: $selectedFilter)
                }
            }
        }
        .task {
            await loadKits()
        }
    }

    // MARK: - Load Kits
    
    private func loadKits() async {
        isLoading = kits.isEmpty
        kits = await KitService.shared.getAllKits()
        isLoading = false
    }
}

// MARK: - InventoryLoadingView

private struct InventoryLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Cargando kits...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - InventoryEmptyStateView

private struct InventoryEmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No hay kits", systemImage: "shippingbox")
        } description: {
            Text("Añade kits desde la pestaña Gestión.")
        }
    }
}

// MARK: - InventoryFilterMenu

private struct InventoryFilterMenu: View {
    @Binding var selectedFilter: KitFilter

    var body: some View {
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
            Label(
                "Filtrar",
                systemImage: selectedFilter == .all
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
    }
}

// MARK: - InventoryKitsList

private struct InventoryKitsList: View {
    let filteredKits: [KitFS]
    let kits: [KitFS]
    let currentUser: UserFS
    let onRefresh: () async -> Void

    var body: some View {
        List {
            InventoryStatsHeader(kits: kits)

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
            await onRefresh()
        }
    }
}

// MARK: - InventoryStatsHeader

private struct InventoryStatsHeader: View {
    let kits: [KitFS]

    var body: some View {
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

// MARK: - Preview

#Preview("Con datos") {
    let user = UserFS(
        id: "1", uid: "uid1", username: "admin",
        fullName: "Admin", email: "admin@test.com",
        active: true, roleId: "role_programmer", baseId: nil
    )
    
    return InventoryView(currentUser: user)
}
