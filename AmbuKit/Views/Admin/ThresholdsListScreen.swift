//
//  ThresholdsListScreen.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

// MARK: - Thresholds List Screen

struct ThresholdsListScreen: View {
    let currentUser: UserFS

    @State private var kits: [KitFS] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Cargando kits...")
            } else if kits.isEmpty {
                ContentUnavailableView(
                    "Sin kits",
                    systemImage: "shippingbox",
                    description: Text("No hay kits para configurar.")
                )
            } else {
                List(kits) { kit in
                    NavigationLink {
                        ThresholdEditorScreen(kit: kit, currentUser: currentUser)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(.orange)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(kit.name)
                                    .font(.headline)
                                Text(kit.code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Editar Umbrales")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            kits = await KitService.shared.getAllKits()
            isLoading = false
        }
    }
}
