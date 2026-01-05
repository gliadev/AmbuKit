//
//  AlertManager.swift
//  AmbuKit
//
//  Created by Adolfo on 31/12/24.
//

import SwiftUI

/// Configuración de alertas con API moderna de SwiftUI
/// Reemplaza el uso del Alert deprecated
struct AlertConfig: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let primaryLabel: String
    let primaryRole: ButtonRole?
    let primaryAction: @MainActor () -> Void
    let secondaryLabel: String?
    let secondaryAction: (@MainActor () -> Void)?
    
    init(
        title: String,
        message: String,
        primaryLabel: String = "OK",
        primaryRole: ButtonRole? = nil,
        primaryAction: @escaping @MainActor () -> Void = {},
        secondaryLabel: String? = nil,
        secondaryAction: (@MainActor () -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryLabel = primaryLabel
        self.primaryRole = primaryRole
        self.primaryAction = primaryAction
        self.secondaryLabel = secondaryLabel
        self.secondaryAction = secondaryAction
    }
    
    // Equatable conformance (ignoring closures)
    static func == (lhs: AlertConfig, rhs: AlertConfig) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Factory Methods

extension AlertConfig {
    
    /// Alert de error genérico
    /// - Parameter error: Error a mostrar
    /// - Returns: AlertConfig configurado para error
    static func error(_ error: Error) -> AlertConfig {
        AlertConfig(
            title: "Error",
            message: ErrorHelper.friendlyMessage(for: error)
        )
    }
    
    /// Alert de error con mensaje personalizado
    /// - Parameter message: Mensaje de error
    /// - Returns: AlertConfig configurado para error
    static func error(message: String) -> AlertConfig {
        AlertConfig(
            title: "Error",
            message: message
        )
    }
    
    /// Alert de éxito
    /// - Parameter message: Mensaje de éxito
    /// - Returns: AlertConfig configurado para éxito
    static func success(_ message: String) -> AlertConfig {
        AlertConfig(
            title: "¡Listo!",
            message: message
        )
    }
    
    /// Alert de confirmación para acciones destructivas
    /// - Parameters:
    ///   - message: Mensaje de confirmación
    ///   - confirmLabel: Texto del botón de confirmación (default: "Confirmar")
    ///   - onConfirm: Acción a ejecutar al confirmar
    /// - Returns: AlertConfig configurado para confirmación
    static func confirmation(
        _ message: String,
        confirmLabel: String = "Confirmar",
        onConfirm: @escaping @MainActor () -> Void
    ) -> AlertConfig {
        AlertConfig(
            title: "Confirmar acción",
            message: message,
            primaryLabel: confirmLabel,
            primaryRole: .destructive,
            primaryAction: onConfirm,
            secondaryLabel: "Cancelar"
        )
    }
    
    /// Alert de confirmación para eliminar
    /// - Parameters:
    ///   - itemName: Nombre del elemento a eliminar
    ///   - onConfirm: Acción a ejecutar al confirmar
    /// - Returns: AlertConfig configurado para eliminación
    static func delete(
        _ itemName: String,
        onConfirm: @escaping @MainActor () -> Void
    ) -> AlertConfig {
        AlertConfig(
            title: "Eliminar",
            message: "¿Eliminar '\(itemName)'? Esta acción no se puede deshacer.",
            primaryLabel: "Eliminar",
            primaryRole: .destructive,
            primaryAction: onConfirm,
            secondaryLabel: "Cancelar"
        )
    }
    
    /// Alert de información
    /// - Parameters:
    ///   - title: Título del alert
    ///   - message: Mensaje informativo
    /// - Returns: AlertConfig configurado para información
    static func info(title: String, message: String) -> AlertConfig {
        AlertConfig(title: title, message: message)
    }
    
    /// Alert de advertencia
    /// - Parameters:
    ///   - message: Mensaje de advertencia
    ///   - onContinue: Acción a ejecutar si el usuario continúa
    /// - Returns: AlertConfig configurado para advertencia
    static func warning(
        _ message: String,
        onContinue: @escaping @MainActor () -> Void
    ) -> AlertConfig {
        AlertConfig(
            title: "Advertencia",
            message: message,
            primaryLabel: "Continuar",
            primaryAction: onContinue,
            secondaryLabel: "Cancelar"
        )
    }
}

// MARK: - View Extension

extension View {
    
    /// Muestra una alerta usando AlertConfig con API moderna
    /// - Parameter config: Binding al AlertConfig opcional
    /// - Returns: Vista con el modificador de alerta aplicado
    func alert(config: Binding<AlertConfig?>) -> some View {
        self.alert(
            config.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { config.wrappedValue != nil },
                set: { if !$0 { config.wrappedValue = nil } }
            )
        ) {
            if let alertConfig = config.wrappedValue {
                // Botón primario
                Button(alertConfig.primaryLabel, role: alertConfig.primaryRole) {
                    alertConfig.primaryAction()
                    config.wrappedValue = nil
                }
                
                // Botón secundario (opcional)
                if let secondaryLabel = alertConfig.secondaryLabel {
                    Button(secondaryLabel, role: .cancel) {
                        alertConfig.secondaryAction?()
                        config.wrappedValue = nil
                    }
                }
            }
        } message: {
            if let message = config.wrappedValue?.message {
                Text(message)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AlertPreview: View {
    @State private var alertConfig: AlertConfig?
    
    var body: some View {
        VStack(spacing: 20) {
            Button("Error") {
                alertConfig = .error(message: "No tienes permisos para esta acción")
            }
            
            Button("Éxito") {
                alertConfig = .success("Kit creado correctamente")
            }
            
            Button("Confirmación") {
                alertConfig = .confirmation("¿Deseas continuar?") {
                    print("Confirmado")
                }
            }
            
            Button("Eliminar") {
                alertConfig = .delete("Kit SVA-001") {
                    print("Eliminado")
                }
            }
        }
        .alert(config: $alertConfig)
    }
}

#Preview {
    AlertPreview()
}
#endif
