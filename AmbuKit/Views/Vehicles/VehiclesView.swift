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
            let lowercased = searchText.lowercased()
            result = result.filter {
                $0.code.lowercased().contains(lowercased) ||
                ($0.plate?.lowercased().contains(lowercased) ?? false) ||
                $0.type.lowercased().contains(lowercased)
            }
        }
        
        return result
    }
    
    // MARK: - Stats
    
    private var totalCount: Int { vehicles.count }
    private var svaCount: Int { vehicles.filter { $0.type.uppercased() == "SVA" }.count }
    private var svbCount: Int { vehicles.filter { $0.type.uppercased() == "SVB" }.count }
    private var withBaseCount: Int { vehicles.filter { $0.hasBase }.count }
    private var withKitsCount: Int { vehicles.filter { $0.hasKits }.count }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if vehicles.isEmpty {
                    emptyView
                } else {
                    // Stats header
                    statsHeader
                    
                    // Filtros
                    filterMenu
                    
                    // Lista
                    vehiclesList
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
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Cargando vehículos...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        ContentUnavailableView(
            "Sin vehículos",
            systemImage: "car.fill",
            description: Text("No hay vehículos registrados en el sistema.")
        )
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                VehicleStatBadge(
                    count: totalCount,
                    title: "Total",
                    color: .blue,
                    icon: "car.2.fill"
                )
                
                VehicleStatBadge(
                    count: svaCount,
                    title: "SVA",
                    color: .red,
                    icon: "cross.case.fill"
                )
                
                VehicleStatBadge(
                    count: svbCount,
                    title: "SVB",
                    color: .blue,
                    icon: "shippingbox.fill"
                )
                
                VehicleStatBadge(
                    count: withBaseCount,
                    title: "Con Base",
                    color: .green,
                    icon: "building.fill"
                )
                
                VehicleStatBadge(
                    count: withKitsCount,
                    title: "Con Kits",
                    color: .purple,
                    icon: "shippingbox.fill"
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Filter Menu
    
    private var filterMenu: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VehicleFilter.allCases, id: \.self) { filter in
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
    }
    
    // MARK: - Vehicles List
    
    private var vehiclesList: some View {
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
    
    // MARK: - Load Data
    
    private func loadData() async {
        isLoading = true
        
        async let vehiclesTask = VehicleService.shared.getAllVehicles()
        async let basesTask = BaseService.shared.getAllBases()
        
        vehicles = await vehiclesTask
        bases = await basesTask
        
        isLoading = false
    }
}

// MARK: - Vehicle Stat Badge Component (nombre único)

private struct VehicleStatBadge: View {
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
        .frame(minWidth: 60)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Vehicle Filter Chip Component (nombre único)

private struct VehicleFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vehicle Row View

struct VehicleRowView: View {
    let vehicle: VehicleFS
    let bases: [BaseFS]
    
    private var baseName: String? {
        guard let baseId = vehicle.baseId else { return nil }
        return bases.first { $0.id == baseId }?.name
    }
    
    private var vehicleTypeInfo: (color: Color, icon: String) {
        switch vehicle.type.uppercased() {
        case "SVA":
            return (.red, "cross.case.fill")
        case "SVAE":
            return (.orange, "cross.case")
        case "SVB":
            return (.blue, "shippingbox.fill")
        case "TSNU":
            return (.green, "car.side")
        case "VIR":
            return (.purple, "car.fill")
        case "HELI":
            return (.yellow, "airplane")
        default:
            return (.gray, "car.fill")
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono tipo vehículo
            ZStack {
                Circle()
                    .fill(vehicleTypeInfo.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: vehicleTypeInfo.icon)
                    .font(.title3)
                    .foregroundStyle(vehicleTypeInfo.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Código y matrícula
                HStack {
                    Text(vehicle.code)
                        .font(.headline)
                    
                    if let plate = vehicle.plate, !plate.isEmpty {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(plate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Badges
                HStack(spacing: 6) {
                    // Tipo badge
                    Text(vehicle.type)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(vehicleTypeInfo.color.opacity(0.15))
                        .foregroundStyle(vehicleTypeInfo.color)
                        .clipShape(Capsule())
                    
                    // Base badge
                    if let base = baseName {
                        HStack(spacing: 2) {
                            Image(systemName: "building.fill")
                                .font(.caption2)
                            Text(base)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 2) {
                            Image(systemName: "building")
                                .font(.caption2)
                            Text("Sin base")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .foregroundStyle(.gray)
                        .clipShape(Capsule())
                    }
                    
                    // Kits badge
                    if vehicle.hasKits {
                        HStack(spacing: 2) {
                            Image(systemName: "shippingbox.fill")
                                .font(.caption2)
                            Text("\(vehicle.kitCount)")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
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

// MARK: - Vehicle Detail Screen (nombre único)

struct VehicleDetailScreen: View {
    let vehicle: VehicleFS
    let currentUser: UserFS
    let bases: [BaseFS]
    
    @State private var kits: [KitFS] = []
    @State private var isLoading = true
    
    private var baseName: String? {
        guard let baseId = vehicle.baseId else { return nil }
        return bases.first { $0.id == baseId }?.name
    }
    
    private var vehicleTypeInfo: (color: Color, icon: String, name: String) {
        switch vehicle.type.uppercased() {
        case "SVA":
            return (.red, "cross.case.fill", "Soporte Vital Avanzado")
        case "SVAE":
            return (.orange, "cross.case", "SVA Enfermería")
        case "SVB":
            return (.blue, "shippingbox.fill", "Soporte Vital Básico")
        case "TSNU":
            return (.green, "car.side", "Transporte No Urgente")
        case "VIR":
            return (.purple, "car.fill", "Vehículo Intervención Rápida")
        case "HELI":
            return (.yellow, "airplane", "Helicóptero Sanitario")
        default:
            return (.gray, "car.fill", vehicle.type)
        }
    }
    
    var body: some View {
        List {
            // Header con info principal
            vehicleHeader
            
            // Sección de información
            infoSection
            
            // Sección de kits asignados
            kitsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(vehicle.code)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadKits()
        }
    }
    
    // MARK: - Vehicle Header
    
    private var vehicleHeader: some View {
        Section {
            HStack(spacing: 16) {
                // Icono grande
                ZStack {
                    Circle()
                        .fill(vehicleTypeInfo.color.opacity(0.15))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: vehicleTypeInfo.icon)
                        .font(.largeTitle)
                        .foregroundStyle(vehicleTypeInfo.color)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(vehicle.code)
                        .font(.title2.bold())
                    
                    if let plate = vehicle.plate, !plate.isEmpty {
                        Label(plate, systemImage: "car.rear.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(vehicleTypeInfo.name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(vehicleTypeInfo.color.opacity(0.15))
                        .foregroundStyle(vehicleTypeInfo.color)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        Section("Información") {
            // Tipo
            HStack {
                Label("Tipo", systemImage: "tag.fill")
                Spacer()
                Text(vehicle.type)
                    .foregroundStyle(.secondary)
            }
            
            // Base
            HStack {
                Label("Base", systemImage: "building.fill")
                Spacer()
                if let base = baseName {
                    Text(base)
                        .foregroundStyle(.green)
                } else {
                    Text("Sin asignar")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Matrícula
            if let plate = vehicle.plate, !plate.isEmpty {
                HStack {
                    Label("Matrícula", systemImage: "car.rear.fill")
                    Spacer()
                    Text(plate)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Kits asignados
            HStack {
                Label("Kits asignados", systemImage: "shippingbox.fill")
                Spacer()
                Text("\(vehicle.kitCount)")
                    .foregroundStyle(vehicle.hasKits ? .purple : .secondary)
            }
        }
    }
    
    // MARK: - Kits Section
    
    private var kitsSection: some View {
        Section("Kits Asignados") {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if kits.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "shippingbox")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("Sin kits asignados")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    Spacer()
                }
            } else {
                ForEach(kits) { kit in
                    NavigationLink {
                        KitDetailView(kit: kit, currentUser: currentUser)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: kitIcon(for: kit.type))
                                .font(.title3)
                                .foregroundStyle(kitColor(for: kit.type))
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kit.name)
                                    .font(.headline)
                                Text(kit.code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(kit.type)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(kitColor(for: kit.type).opacity(0.15))
                                .foregroundStyle(kitColor(for: kit.type))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func kitIcon(for type: String) -> String {
        switch type.uppercased() {
        case "SVA": return "cross.case.fill"
        case "SVAE": return "cross.case.fill"
        case "SVB": return "shippingbox.fill"
        default: return "star.fill"
        }
    }
    
    private func kitColor(for type: String) -> Color {
        switch type.uppercased() {
        case "SVA": return .red
        case "SVAE": return .orange
        case "SVB": return .blue
        default: return .purple
        }
    }
    
    // MARK: - Load Kits
    
    private func loadKits() async {
        isLoading = true
        
        // Obtener kits asignados a este vehículo
        guard let vehicleId = vehicle.id else {
            isLoading = false
            return
        }
        
        let allKits = await KitService.shared.getAllKits()
        kits = allKits.filter { $0.vehicleId == vehicleId }
        
        isLoading = false
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
