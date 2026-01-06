//
//  ErrorView.swift
//  AmbuKit
//
//  Created by Adolfo on 9/12/25.
//  Updated: 27/12/25 - Añadidas animaciones SF Symbols (iOS 17+)
//

import SwiftUI

// MARK: - ErrorView

/// Vista reutilizable para mostrar errores con animación de feedback
///
/// ## ❌ ANTES (estático):
/// ```swift
/// Image(systemName: icon)
///     .font(.system(size: 48))
///     .foregroundStyle(iconColor)
/// ```
///
/// ## ✅ DESPUÉS (animado):
/// ```swift
/// Image(systemName: icon)
///     .font(.system(size: 48))
///     .foregroundStyle(iconColor)
///     .symbolEffect(.bounce, value: animationTrigger)  // 🎯 Bounce al aparecer
/// ```
struct ErrorView: View {
    
    // MARK: - Properties
    
    /// Título del error
    let title: String
    
    /// Mensaje descriptivo del error
    let message: String
    
    /// Icono SF Symbol a mostrar
    var icon: String = "exclamationmark.triangle"
    
    /// Color del icono
    var iconColor: Color = .red
    
    /// Acción al pulsar "Reintentar"
    var retryAction: (() -> Void)?
    
    /// Texto del botón de reintentar
    var retryButtonText: String = "Reintentar"
    
    /// Trigger para animación de bounce
    @State private var animationTrigger = false
    
    /// Trigger para animación del botón
    @State private var buttonTrigger = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            // ✅ DESPUÉS: Icono con animación bounce
            if #available(iOS 17.0, *) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(iconColor)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.bounce, value: animationTrigger)  // 🎯 Bounce al aparecer
            } else {
                // Fallback iOS 16
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(iconColor)
            }
            
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
            
            // Botón de reintentar con animación
            if let action = retryAction {
                Button {
                    buttonTrigger.toggle()  // Trigger animación
                    action()
                } label: {
                    HStack(spacing: 6) {
                        if #available(iOS 17.0, *) {
                            Image(systemName: "arrow.clockwise")
                                .symbolEffect(.rotate, value: buttonTrigger)  // 🎯 Rotación al pulsar
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
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
        .onAppear {
            // Disparar animación al aparecer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animationTrigger = true
            }
        }
    }
}

// MARK: - Convenience Initializers

extension ErrorView {
    
    /// Inicializador simple con solo mensaje
    init(_ message: String, retryAction: (() -> Void)? = nil) {
        self.title = "Error"
        self.message = message
        self.retryAction = retryAction
    }
    
    /// Error de red/conexión
    static func networkError(retryAction: @escaping () -> Void) -> ErrorView {
        ErrorView(
            title: "Sin conexión",
            message: "No se pudo conectar con el servidor. Verifica tu conexión a internet.",
            icon: "wifi.slash",
            iconColor: .orange,
            retryAction: retryAction
        )
    }
    
    /// Error de permisos
    static func permissionError() -> ErrorView {
        ErrorView(
            title: "Sin permisos",
            message: "No tienes permisos para realizar esta acción.",
            icon: "lock.fill",
            iconColor: .purple
        )
    }
    
    /// Error de sincronización
    static func syncError(retryAction: @escaping () -> Void) -> ErrorView {
        ErrorView(
            title: "Error de sincronización",
            message: "No se pudieron sincronizar los datos. Inténtalo de nuevo.",
            icon: "arrow.triangle.2.circlepath.circle",
            iconColor: .blue,
            retryAction: retryAction
        )
    }
    
    /// Error genérico con mensaje personalizado
    static func custom(title: String, message: String, icon: String = "exclamationmark.circle", color: Color = .red, retryAction: (() -> Void)? = nil) -> ErrorView {
        ErrorView(
            title: title,
            message: message,
            icon: icon,
            iconColor: color,
            retryAction: retryAction
        )
    }
}

// MARK: - Previews

#Preview("ErrorView – Default") {
    ErrorView(
        title: "Error",
        message: "Ha ocurrido un error inesperado.",
        retryAction: { print("Retry") }
    )
}

#Preview("ErrorView – Network") {
    ErrorView.networkError {
        print("Retry network")
    }
}

#Preview("ErrorView – Permission") {
    ErrorView.permissionError()
}

#Preview("ErrorView – Sync") {
    ErrorView.syncError {
        print("Retry sync")
    }
}
