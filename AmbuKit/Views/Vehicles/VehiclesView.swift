//
//  VehiclesView.swift
//  AmbuKit
//
//  Created by Adolfo on 26/12/25.
//
//  TAREA 16.6: Vista de vehículos - 100% Firebase
//
//  Características:
//  - Stats header con badges coloridos
//  - Filtros por tipo y estado
//  - Lista con badges de tipo, base, kits
//  - Pull-to-refresh
//  - Búsqueda
//

import SwiftUI

// MARK: - VehiclesView

struct VehiclesView: View {
    
    // MARK: - Properties
    
    let currentUser: UserFS
    
    // MARK: - State
    
    @State private var vehicles: [VehicleFS] = []
    @State private var bases: [BaseFS] = []
    @State private var stats: VehicleStats = .empty
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedFilter: VehicleFilter = .all
    
    // MARK: - Filter Enum
    
    enum VehicleFilter: String, CaseIterable {
        case all = "Todos"
        case sva = "SVA"
        case svb = "SVB"
        case svae = "SVAe"
        case withBase = "Con Base"
        case withoutBase = "Sin Base"
        case withKits = "Con Kits"
        
        var icon: String {
            switch self {
            case .all: return "car.2.fill"
            case .sva: return "cross.case.fill"
            case .svb: return "shippingbox.fill"
            case .svae: return "cross.case"
            case .withBase: return "building.fill"
            case .withoutBase: return "building"
            case .withKits: return "shippingbox.fill"
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredVehicles: [VehicleFS] {
        var result = vehicles
        
        // Aplicar filtro
        switch selectedFilter {
        case .all:
            break
        case .sva:
            result = result.filter { $0.type.uppercased() == "SVA" }
        case .svb:
            result = result.filter { $0.type.uppercased() == "SVB" }
        case .svae:
            result = result.filter { $0.type.uppercased() == "SVAE" }
        case .withBase:
            result = result.filter { $0.hasBase }
        case .withoutBase:
            result = result.filter { !$0.hasBase }
        case .withKits:
            result = result.filter { $0.hasKits }
        }
        
        // Aplicar búsqueda
        if !searchText.isEmpty {
            result = result.filter {
                $0.code.localizedStandardContains(searchText) ||
                ($0.plate?.localizedStandardContains(searchText) ?? false) ||
                $0.type.localizedStandardContains(searchText)
            }
        }
        
        return result
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    VehiclesLoadingView()
                } else if vehicles.isEmpty {
                    VehiclesEmptyView()
                } else {
                    VehiclesStatsHeader(stats: stats)
                    VehiclesFilterMenu(selectedFilter: $selectedFilter)
                    VehiclesListView(
                        filteredVehicles: filteredVehicles,
                        currentUser: currentUser,
                        bases: bases
                    )
                }
            }
            .navigationTitle("Vehículos")
            .searchable(text: $searchText, prompt: "Buscar vehículos...")
            .refreshable {
                await loadData()
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Load Data
    
    private func loadData() async {
        isLoading = true

        async let vehiclesTask = VehicleService.shared.getAllVehicles()
        async let basesTask = BaseService.shared.getAllBases()

        let loadedVehicles = await vehiclesTask
        vehicles = loadedVehicles
        bases = await basesTask
        stats = VehicleStats(vehicles: loadedVehicles)

        isLoading = false
    }
}

// MARK: - VehicleStats

struct VehicleStats: Equatable {
    let totalCount: Int
    let svaCount: Int
    let svbCount: Int
    let withBaseCount: Int
    let withKitsCount: Int

    static let empty = VehicleStats(totalCount: 0, svaCount: 0, svbCount: 0, withBaseCount: 0, withKitsCount: 0)

    init(totalCount: Int, svaCount: Int, svbCount: Int, withBaseCount: Int, withKitsCount: Int) {
        self.totalCount = totalCount
        self.svaCount = svaCount
        self.svbCount = svbCount
        self.withBaseCount = withBaseCount
        self.withKitsCount = withKitsCount
    }

    init(vehicles: [VehicleFS]) {
        var sva = 0, svb = 0, withBase = 0, withKits = 0
        for vehicle in vehicles {
            switch vehicle.type.uppercased() {
            case "SVA": sva += 1
            case "SVB": svb += 1
            default: break
            }
            if vehicle.hasBase { withBase += 1 }
            if vehicle.hasKits { withKits += 1 }
        }
        self.init(
            totalCount: vehicles.count,
            svaCount: sva,
            svbCount: svb,
            withBaseCount: withBase,
            withKitsCount: withKits
        )
    }
}

// MARK: - VehiclesLoadingView

private struct VehiclesLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Cargando vehículos...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - VehiclesEmptyView

private struct VehiclesEmptyView: View {
    var body: some View {
        ContentUnavailableView(
            "Sin vehículos",
            systemImage: "car.fill",
            description: Text("No hay vehículos registrados en el sistema.")
        )
    }
}

// MARK: - VehiclesStatsHeader

private struct VehiclesStatsHeader: View {
    let stats: VehicleStats

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                VehicleStatBadge(count: stats.totalCount,    title: "Total",    color: .blue,   icon: "car.2.fill")
                VehicleStatBadge(count: stats.svaCount,      title: "SVA",      color: .red,    icon: "cross.case.fill")
                VehicleStatBadge(count: stats.svbCount,      title: "SVB",      color: .blue,   icon: "shippingbox.fill")
                VehicleStatBadge(count: stats.withBaseCount, title: "Con Base", color: .green,  icon: "building.fill")
                VehicleStatBadge(count: stats.withKitsCount, title: "Con Kits", color: .purple, icon: "shippingbox.fill")
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground))
    }
}

// MARK: - VehiclesFilterMenu

private struct VehiclesFilterMenu: View {
    @Binding var selectedFilter: VehiclesView.VehicleFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(VehiclesView.VehicleFilter.allCases, id: \.self) { filter in
                    VehicleFilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - VehiclesListView

private struct VehiclesListView: View {
    let filteredVehicles: [VehicleFS]
    let currentUser: UserFS
    let bases: [BaseFS]

    var body: some View {
        List {
            ForEach(filteredVehicles) { vehicle in
                NavigationLink {
                    VehicleDetailScreen(vehicle: vehicle, currentUser: currentUser, bases: bases)
                } label: {
                    VehicleRowView(vehicle: vehicle, bases: bases)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Vehicles View") {
    let user = UserFS(
        id: "1", uid: "uid1", username: "admin",
        fullName: "Admin", email: "admin@test.com",
        active: true, roleId: "role_programmer", baseId: nil
    )
    
    return VehiclesView(currentUser: user)
}
