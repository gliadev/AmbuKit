//
//  ToastView.swift
//  AmbuKit
//
//  Created by Adolfo on 31/12/24.
//

import SwiftUI

// MARK: - Toast Type

/// Tipos de toast con sus características visuales
enum ToastType: Sendable {
    case success
    case error
    case info
    case warning
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        case .warning: return .orange
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .success: return "Éxito"
        case .error: return "Error"
        case .info: return "Información"
        case .warning: return "Advertencia"
        }
    }
}

// MARK: - Toast Model

/// Configuración de un toast notification
struct Toast: Identifiable, Equatable, Sendable {
    let id: UUID
    let type: ToastType
    let message: String
    let duration: TimeInterval
    
    init(
        type: ToastType,
        message: String,
        duration: TimeInterval = 3.0
    ) {
        self.id = UUID()
        self.type = type
        self.message = message
        self.duration = duration
    }
    
    // Equatable
    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Factory

extension Toast {
    /// Toast de éxito
    static func success(_ message: String, duration: TimeInterval = 3.0) -> Toast {
        Toast(type: .success, message: message, duration: duration)
    }
    
    /// Toast de error
    static func error(_ message: String, duration: TimeInterval = 4.0) -> Toast {
        Toast(type: .error, message: message, duration: duration)
    }
    
    /// Toast de error desde Error
    static func error(_ error: Error, duration: TimeInterval = 4.0) -> Toast {
        Toast(type: .error, message: ErrorHelper.friendlyMessage(for: error), duration: duration)
    }
    
    /// Toast informativo
    static func info(_ message: String, duration: TimeInterval = 3.0) -> Toast {
        Toast(type: .info, message: message, duration: duration)
    }
    
    /// Toast de advertencia
    static func warning(_ message: String, duration: TimeInterval = 4.0) -> Toast {
        Toast(type: .warning, message: message, duration: duration)
    }
}

// MARK: - Toast View

/// Vista de toast notification
struct ToastView: View {
    let toast: Toast
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .font(.title3)
                .foregroundStyle(toast.type.color)
                .symbolRenderingMode(.hierarchical)
            
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(toast.type.accessibilityLabel): \(toast.message)")
    }
}

// MARK: - Toast Modifier (Swift 6)

/// Modificador para mostrar toasts - Compatible con Swift 6 strict concurrency
struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let currentToast = toast {
                    ToastView(toast: currentToast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(999)
                        .task(id: currentToast.id) {
                            // ✅ Swift 6: Task.sleep en lugar de DispatchQueue
                            do {
                                try await Task.sleep(for: .seconds(currentToast.duration))
                                // Solo ocultar si sigue siendo el mismo toast
                                if toast?.id == currentToast.id {
                                    toast = nil
                                }
                            } catch {
                                // Task cancelada (vista desapareció)
                            }
                        }
                        .padding(.top, 8)
                }
            }
            .animation(.spring(duration: 0.3), value: toast)
    }
}

// MARK: - View Extension

extension View {
    /// Muestra un toast notification
    /// - Parameter toast: Binding al Toast opcional
    /// - Returns: Vista con capacidad de mostrar toasts
    func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

// MARK: - Previews

#Preview("Toast Success") {
    VStack {
        Text("Contenido de la app")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast(.constant(Toast.success("Kit creado correctamente")))
}

#Preview("Toast Error") {
    VStack {
        Text("Contenido de la app")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast(.constant(Toast.error("No tienes permisos para esta acción")))
}

#Preview("Toast Warning") {
    VStack {
        Text("Contenido de la app")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast(.constant(Toast.warning("El kit está próximo a caducar")))
}

#Preview("Toast Info") {
    VStack {
        Text("Contenido de la app")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast(.constant(Toast.info("Sincronizando datos...")))
}

#if DEBUG
struct ToastInteractivePreview: View {
    @State private var toast: Toast?
    
    var body: some View {
        VStack(spacing: 20) {
            Button("✅ Success") {
                toast = .success("Operación completada")
            }
            
            Button("❌ Error") {
                toast = .error("No tienes permisos")
            }
            
            Button("⚠️ Warning") {
                toast = .warning("Stock bajo detectado")
            }
            
            Button("ℹ️ Info") {
                toast = .info("Datos sincronizados")
            }
        }
        .toast($toast)
    }
}

#Preview("Interactive") {
    ToastInteractivePreview()
}
#endif
