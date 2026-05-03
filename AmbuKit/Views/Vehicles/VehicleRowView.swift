//
//  VehicleRowView.swift
//  AmbuKit
//
//  Created by Adolfo on 26/12/25.
//

import SwiftUI

// MARK: - Vehicle Row View

struct VehicleRowView: View {
    let vehicle: VehicleFS
    let bases: [BaseFS]

    private var baseName: String? {
        guard let baseId = vehicle.baseId else { return nil }
        return bases.first { $0.id == baseId }?.name
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icono tipo vehículo
            ZStack {
                Circle()
                    .fill(vehicle.vehicleType.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: vehicle.vehicleType.systemImage)
                    .font(.title3)
                    .foregroundStyle(vehicle.vehicleType.color)
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
                        .background(vehicle.vehicleType.color.opacity(0.15))
                        .foregroundStyle(vehicle.vehicleType.color)
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
