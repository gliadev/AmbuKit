//
//  ErrorView.swift
//  AmbuKit
//
//  Created by Adolfo on 9/12/25.
//

import SwiftUI

// MARK: - ErrorView

/// Vista reutilizable para mostrar errores con opción de reintentar
/// Diseñada para ser consistente en toda la app
struct ErrorView: View {
    
    // MARK: - Properties
    
    /// Título del error
    let title: String
    
    /// Mensaje descriptivo del error
    let message: String
    
    /// Icono SF Symbol a mostrar (default: exclamationmark.triangle)
    var icon: String = "exclamationmark.triangle"
    
    /// Color del icono (default: red)
    var iconColor: Color = .red
    
    /// Acción al pulsar "Reintentar" (opcional)
    var retryAction: (() -> Void)?
    
    /// Texto del botón de reintentar
    var retryButtonText: String = "Reintentar"
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            // Icono
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(iconColor)
                .symbolRenderingMode(.hierarchical)
            
            // Textos
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            
            // Botón de reintentar
            if let action = retryAction {
                Button {
                    action()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text(retryButtonText)
                    }
                    .font(.body.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Convenience Initializers

extension ErrorView {
    /// Inicializador simple con solo mensaje y acción
    init(_ message: String, retryAction: (() -> Void)? = nil) {
        self.title = "Error"
        self.message = message
        self.retryAction = retryAction
    }
    
    /// Inicializador para errores de red
    static func networkError(retryAction: @escaping () -> Void) -> ErrorView {
        ErrorView(
            title: "Sin conexión",
            message: "No se pudo conectar con el servidor. Verifica tu conexión a internet.",
            icon: "wifi.slash",
            iconColor: .orange,
            retryAction: retryAction
        )
    }
    
    /// Inicializador para errores de permisos
    static func permissionError() -> ErrorView {
        ErrorView(
            title: "Sin permisos",
            message: "No tienes permisos para realizar esta acción.",
            icon: "lock.shield",
            iconColor: .red,
            retryAction: nil
        )
    }
    
    /// Inicializador para item no encontrado
    static func notFound(itemName: String) -> ErrorView {
        ErrorView(
            title: "No encontrado",
            message: "\(itemName) no existe o fue eliminado.",
            icon: "magnifyingglass",
            iconColor: .secondary,
            retryAction: nil
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Error Genérico") {
    ErrorView(
        title: "Error al cargar",
        message: "No se pudieron cargar los datos. Por favor intenta de nuevo.",
        retryAction: { print("Retry tapped") }
    )
}

#Preview("Error de Red") {
    ErrorView.networkError(retryAction: { print("Retry tapped") })
}

#Preview("Error de Permisos") {
    ErrorView.permissionError()
}

#Preview("No Encontrado") {
    ErrorView.notFound(itemName: "El kit")
}

#Preview("Sin Botón Reintentar") {
    ErrorView(
        title: "Error fatal",
        message: "Algo salió muy mal y no se puede recuperar."
    )
}
#endif
