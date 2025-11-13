//
//  EmptyStateView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//
import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String?

    
    init() {
        self.title = "Sin datos"
        self.message = nil
    }

    
    init(_ title: String, message: String? = nil) {
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text(title).font(.headline)
            if let message {
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview("EmptyState – default") {
    EmptyStateView()
}

#Preview("EmptyState – custom") {
    EmptyStateView("No hay kits", message: "Añádelos desde Gestión.")
}
