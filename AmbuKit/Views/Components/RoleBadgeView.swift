//
//  RoleBadgeView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

struct RoleBadgeView: View {
    let role: RoleKind?
    var body: some View {
        Group {
            switch role {
            case .programmer?: Label("Programador", systemImage: "hammer.fill")
            case .logistics?:  Label("Logística",  systemImage: "shippingbox.circle.fill")
            case .sanitary?:   Label("Sanitario",  systemImage: "stethoscope")
            default:           Label("—",          systemImage: "questionmark.circle")
            }
        }
        .font(.caption)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
    }
}


