//
//  StatusBadge.swift
//  AmbuKit
//
//  Created by Adolfo on 27/12/25.
//  Badge de estado con animaciones SF Symbols para alertas visuales
//  Usado en KitItemRow para mostrar estados de stock y caducidad
//

import SwiftUI

// MARK: - StatusBadge

/// Badge animado para mostrar estados de alerta
///
/// ## Uso:
/// ```swift
/// StatusBadge(
///     text: "BAJO STOCK",
///     icon: "arrow.down.circle.fill",
///     color: .red,
///     style: .critical  // Animación pulse
/// )
/// ```
struct StatusBadge: View {
    
    // MARK: - Properties
    
    let text: String
    let icon: String
    let color: Color
    var style: BadgeStyle = .normal
    
    // MARK: - Badge Style
    
    enum BadgeStyle {
        case normal      // Sin animación
        case warning     // Pulse suave
        case critical    // Pulse intenso + wiggle
        case success     // Bounce una vez
    }
    
    // MARK: - State
    
    @State private var isAnimating = false
    @State private var successTrigger = 0
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 4) {
            if #available(iOS 17.0, *) {
                animatedIcon
            } else {
                staticIcon
            }
            
            Text(text)
                .font(.caption2.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color)
        .clipShape(Capsule())
        .onAppear {
            isAnimating = true
            if style == .success {
                successTrigger += 1
            }
        }
    }
    
    // MARK: - Animated Icon (iOS 17+)
    
    @available(iOS 17.0, *)
    private var animatedIcon: some View {
        Group {
            switch style {
            case .normal:
                Image(systemName: icon)
                    .font(.caption2)
                
            case .warning:
                // Pulse suave para advertencias
                Image(systemName: icon)
                    .font(.caption2)
                    .symbolEffect(.pulse, isActive: isAnimating)
                
            case .critical:
                // Pulse + escala para críticos (BAJO STOCK, CADUCADO)
                Image(systemName: icon)
                    .font(.caption2)
                    .symbolEffect(.pulse.byLayer, isActive: isAnimating)
                    .symbolEffect(.bounce, value: isAnimating)
                
            case .success:
                // Bounce una vez para éxito
                Image(systemName: icon)
                    .font(.caption2)
                    .symbolEffect(.bounce, value: successTrigger)
            }
        }
    }
    
    // MARK: - Static Icon (iOS 16)
    
    private var staticIcon: some View {
        Image(systemName: icon)
            .font(.caption2)
    }
}

// MARK: - Convenience Initializers

extension StatusBadge {
    
    /// Badge de bajo stock (crítico - pulsa)
    static func lowStock() -> StatusBadge {
        StatusBadge(
            text: "BAJO STOCK",
            icon: "arrow.down.circle.fill",
            color: .red,
            style: .critical
        )
    }
    
    /// Badge de sobre stock (advertencia)
    static func overStock() -> StatusBadge {
        StatusBadge(
            text: "SOBRE STOCK",
            icon: "arrow.up.circle.fill",
            color: .orange,
            style: .warning
        )
    }
    
    /// Badge de caducidad próxima (advertencia)
    static func expiringSoon() -> StatusBadge {
        StatusBadge(
            text: "CADUCA PRONTO",
            icon: "clock.fill",
            color: .yellow,
            style: .warning
        )
    }
    
    /// Badge de caducado (crítico - pulsa)
    static func expired() -> StatusBadge {
        StatusBadge(
            text: "CADUCADO",
            icon: "exclamationmark.triangle.fill",
            color: .purple,
            style: .critical
        )
    }
    
    /// Badge de stock OK
    static func stockOK() -> StatusBadge {
        StatusBadge(
            text: "OK",
            icon: "checkmark.circle.fill",
            color: .green,
            style: .success
        )
    }
    
    /// Badge de sincronizado
    static func synced() -> StatusBadge {
        StatusBadge(
            text: "SYNC",
            icon: "checkmark.icloud.fill",
            color: .blue,
            style: .success
        )
    }
}

// MARK: - Preview

#Preview("StatusBadge - Todos los estilos") {
    VStack(spacing: 20) {
        Text("StatusBadge Animados")
            .font(.headline)
        
        VStack(spacing: 12) {
            StatusBadge.lowStock()
            StatusBadge.overStock()
            StatusBadge.expiringSoon()
            StatusBadge.expired()
            StatusBadge.stockOK()
            StatusBadge.synced()
        }
        
        Divider()
        
        Text("Estilos")
            .font(.headline)
        
        HStack(spacing: 12) {
            StatusBadge(text: "Normal", icon: "circle.fill", color: .gray, style: .normal)
            StatusBadge(text: "Warning", icon: "exclamationmark.circle.fill", color: .orange, style: .warning)
            StatusBadge(text: "Critical", icon: "xmark.circle.fill", color: .red, style: .critical)
            StatusBadge(text: "Success", icon: "checkmark.circle.fill", color: .green, style: .success)
        }
    }
    .padding()
}



