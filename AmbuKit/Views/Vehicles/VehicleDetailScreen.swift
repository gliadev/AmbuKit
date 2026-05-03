//
//  VehicleDetailScreen.swift
//  AmbuKit
//
//  Created by Adolfo on 26/12/25.
//

import SwiftUI

// MARK: - Vehicle Detail Screen

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
                        .fill(vehicle.vehicleType.color.opacity(0.15))
                        .frame(width: 70, height: 70)

                    Image(systemName: vehicle.vehicleType.systemImage)
                        .font(.largeTitle)
                        .foregroundStyle(vehicle.vehicleType.color)
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

                    Text(vehicle.vehicleType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(vehicle.vehicleType.color.opacity(0.15))
                        .foregroundStyle(vehicle.vehicleType.color)
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
