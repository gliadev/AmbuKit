//
//  EmptyStateView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//  Updated: 27/12/25 - Añadidas animaciones SF Symbols (iOS 17+)
//

import SwiftUI

// MARK: - EmptyStateView

/// Vista para estados vacíos con animación sutil
///
/// ## ❌ ANTES (estático):
/// ```swift
/// Image(systemName: "tray")
///     .font(.largeTitle)
///     .foregroundStyle(.secondary)
/// ```
///
/// ## ✅ DESPUÉS (animado):
/// ```swift
/// Image(systemName: icon)
///     .font(.largeTitle)
///     .foregroundStyle(.secondary)
///     .symbolEffect(.breathe, isActive: true)  // 🎯 Animación sutil
/// ```
struct EmptyStateView: View {
    
    // MARK: - Properties
    
    let title: String
    let message: String?
    let icon: String
    
    /// Controla si la animación está activa
    @State private var isAnimating = false
    
    // MARK: - Initializers
    
    init() {
        self.title = "Sin datos"
        self.message = nil
        self.icon = "tray"
    }
    
    init(_ title: String, message: String? = nil, icon: String = "tray") {
        self.title = title
        self.message = message
        self.icon = icon
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 12) {
            // ✅ DESPUÉS: Icono con animación breathe
            if #available(iOS 17.0, *) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.breathe, isActive: isAnimating)  // 🎯 Animación breathe
            } else {
                // Fallback iOS 16
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
            
            // Textos
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Convenience Initializers

extension EmptyStateView {
    
    /// Estado vacío para inventario
    static var inventory: EmptyStateView {
        EmptyStateView(
            "Sin items",
            message: "Este kit no tiene items asignados",
            icon: "shippingbox"
        )
    }
    
    /// Estado vacío para kits
    static var kits: EmptyStateView {
        EmptyStateView(
            "Sin kits",
            message: "No hay kits disponibles",
            icon: "cross.case"
        )
    }
    
    /// Estado vacío para vehículos
    static var vehicles: EmptyStateView {
        EmptyStateView(
            "Sin vehículos",
            message: "No hay vehículos registrados",
            icon: "car"
        )
    }
    
    /// Estado vacío para usuarios
    static var users: EmptyStateView {
        EmptyStateView(
            "Sin usuarios",
            message: "No hay usuarios en el sistema",
            icon: "person.2"
        )
    }
    
    /// Estado vacío para búsqueda
    static func searchEmpty(query: String) -> EmptyStateView {
        EmptyStateView(
            "Sin resultados",
            message: "No se encontraron coincidencias para \"\(query)\"",
            icon: "magnifyingglass"
        )
    }
}

// MARK: - Previews

#Preview("EmptyState – Default") {
    EmptyStateView()
}

#Preview("EmptyState – Custom") {
    EmptyStateView(
        "No hay kits",
        message: "Añádelos desde el menú de Gestión.",
        icon: "cross.case"
    )
}

#Preview("EmptyState – Inventory") {
    EmptyStateView.inventory
}

#Preview("EmptyState – Search") {
    EmptyStateView.searchEmpty(query: "aspirina")
}
