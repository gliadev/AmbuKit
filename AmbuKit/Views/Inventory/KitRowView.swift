//
//  KitRowView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

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
                        .background(kit.kitType.color.opacity(0.1))
                        .foregroundStyle(kit.kitType.color)
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
                .fill(kit.kitType.color.opacity(0.15))
                .frame(width: 44, height: 44)

            Image(systemName: kit.kitType.systemImage)
                .font(.title3)
                .foregroundStyle(kit.kitType.color)
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
