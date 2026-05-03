//
//  VehicleStatBadge.swift
//  AmbuKit
//
//  Created by Adolfo on 26/12/25.
//

import SwiftUI

// MARK: - Vehicle Stat Badge

struct VehicleStatBadge: View {
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
