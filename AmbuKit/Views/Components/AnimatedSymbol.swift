//
//  AnimatedSymbol.swift
//  AmbuKit
//
//  Created by Adolfo on 27/12/25.
//
//  Componente reutilizable para SF Symbols animados (iOS 17+)
//  Implementa animaciones nativas: bounce, pulse, wiggle, rotate, breathe, replace
//

import SwiftUI

// MARK: - Animation Type

/// Tipos de animación disponibles para SF Symbols
@available(iOS 17.0, *)
public enum SymbolAnimation: String, CaseIterable, Sendable {
    case none       // Sin animación
    case bounce     // Rebote (feedback de acción)
    case pulse      // Pulsación tipo latido
    case wiggle     // Movimiento lateral
    case rotate     // Rotación continua
    case breathe    // Respiración sutil
    case scale      // Escala suave
    
    /// Descripción para UI
    var displayName: String {
        switch self {
        case .none: return "Sin animación"
        case .bounce: return "Rebote"
        case .pulse: return "Pulso"
        case .wiggle: return "Vibración"
        case .rotate: return "Rotación"
        case .breathe: return "Respiración"
        case .scale: return "Escala"
        }
    }
}

// MARK: - Animated Symbol View

/// Vista reutilizable para SF Symbols con animaciones nativas
///
/// ## Uso básico:
/// ```swift
/// AnimatedSymbol("checkmark.circle.fill", animation: .bounce)
/// ```
///
/// ## Con trigger (animación al cambiar valor):
/// ```swift
/// AnimatedSymbol("arrow.clockwise", animation: .rotate, isActive: isSyncing)
/// ```
///
/// ## Con color y tamaño:
/// ```swift
/// AnimatedSymbol(
///     "exclamationmark.triangle",
///     animation: .wiggle,
///     color: .red,
///     size: .title
/// )
/// ```
@available(iOS 17.0, *)
public struct AnimatedSymbol: View {
    
    // MARK: - Properties
    
    /// Nombre del SF Symbol
    let symbolName: String
    
    /// Tipo de animación a aplicar
    let animation: SymbolAnimation
    
    /// Si la animación continua está activa
    let isActive: Bool
    
    /// Valor que dispara animación discreta al cambiar
    let trigger: Bool
    
    /// Color del símbolo
    let color: Color?
    
    /// Tamaño de fuente
    let size: Font
    
    /// Modo de renderizado
    let renderingMode: SymbolRenderingMode
    
    // MARK: - Initializer
    
    /// Inicializador principal
    /// - Parameters:
    ///   - symbolName: Nombre del SF Symbol
    ///   - animation: Tipo de animación (default: .none)
    ///   - isActive: Para animaciones continuas (rotate, breathe)
    ///   - trigger: Dispara animación discreta al cambiar
    ///   - color: Color opcional
    ///   - size: Tamaño de fuente (default: .body)
    ///   - renderingMode: Modo de renderizado (default: .hierarchical)
    public init(
        _ symbolName: String,
        animation: SymbolAnimation = .none,
        isActive: Bool = false,
        trigger: Bool = false,
        color: Color? = nil,
        size: Font = .body,
        renderingMode: SymbolRenderingMode = .hierarchical
    ) {
        self.symbolName = symbolName
        self.animation = animation
        self.isActive = isActive
        self.trigger = trigger
        self.color = color
        self.size = size
        self.renderingMode = renderingMode
    }
    
    // MARK: - Body
    
    public var body: some View {
        Image(systemName: symbolName)
            .font(size)
            .symbolRenderingMode(renderingMode)
            .foregroundStyle(color ?? .primary)
            .modifier(AnimationModifier(
                animation: animation,
                isActive: isActive,
                trigger: trigger
            ))
    }
}

// MARK: - Animation Modifier

@available(iOS 17.0, *)
private struct AnimationModifier: ViewModifier {
    let animation: SymbolAnimation
    let isActive: Bool
    let trigger: Bool
    
    func body(content: Content) -> some View {
        switch animation {
        case .none:
            content
            
        case .bounce:
            content
                .symbolEffect(.bounce, value: trigger)
            
        case .pulse:
            content
                .symbolEffect(.pulse, isActive: isActive)
            
        case .wiggle:
            content
                .symbolEffect(.wiggle, isActive: isActive)
            
        case .rotate:
            content
                .symbolEffect(.rotate, isActive: isActive)
            
        case .breathe:
            content
                .symbolEffect(.breathe, isActive: isActive)
            
        case .scale:
            content
                .symbolEffect(.scale, isActive: isActive)
        }
    }
}

// MARK: - Convenience Extensions

@available(iOS 17.0, *)
public extension AnimatedSymbol {
    
    /// Símbolo de carga/sincronización con rotación
    static func loading(_ symbolName: String = "arrow.triangle.2.circlepath", isActive: Bool = true) -> AnimatedSymbol {
        AnimatedSymbol(
            symbolName,
            animation: .rotate,
            isActive: isActive,
            color: .blue,
            size: .title2
        )
    }
    
    /// Símbolo de éxito con rebote
    static func success(_ symbolName: String = "checkmark.circle.fill", trigger: Bool) -> AnimatedSymbol {
        AnimatedSymbol(
            symbolName,
            animation: .bounce,
            trigger: trigger,
            color: .green,
            size: .title2
        )
    }
    
    /// Símbolo de error con wiggle
    static func error(_ symbolName: String = "exclamationmark.triangle.fill", trigger: Bool) -> AnimatedSymbol {
        AnimatedSymbol(
            symbolName,
            animation: .wiggle,
            trigger: trigger,
            color: .red,
            size: .title2
        )
    }
    
    /// Símbolo de advertencia con pulso
    static func warning(_ symbolName: String = "exclamationmark.circle.fill", isActive: Bool = true) -> AnimatedSymbol {
        AnimatedSymbol(
            symbolName,
            animation: .pulse,
            isActive: isActive,
            color: .orange,
            size: .title2
        )
    }
    
    /// Símbolo de estado vacío con respiración
    static func empty(_ symbolName: String = "tray", isActive: Bool = true) -> AnimatedSymbol {
        AnimatedSymbol(
            symbolName,
            animation: .breathe,
            isActive: isActive,
            color: .secondary,
            size: .largeTitle
        )
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("AnimatedSymbol - Galería") {
    ScrollView {
        VStack(spacing: 32) {
            // Header
            Text("SF Symbols Animados")
                .font(.largeTitle.bold())
                .padding(.top)
            
            Text("iOS 17+ Native Animations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
            
            // Grid de ejemplos
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 24) {
                
                // Bounce
                VStack(spacing: 8) {
                    AnimatedSymbol(
                        "checkmark.circle.fill",
                        animation: .bounce,
                        trigger: true,
                        color: .green,
                        size: .largeTitle
                    )
                    Text("Bounce")
                        .font(.caption)
                }
                
                // Pulse
                VStack(spacing: 8) {
                    AnimatedSymbol(
                        "heart.fill",
                        animation: .pulse,
                        isActive: true,
                        color: .red,
                        size: .largeTitle
                    )
                    Text("Pulse")
                        .font(.caption)
                }
                
                // Wiggle
                VStack(spacing: 8) {
                    AnimatedSymbol(
                        "bell.fill",
                        animation: .wiggle,
                        isActive: true,
                        color: .orange,
                        size: .largeTitle
                    )
                    Text("Wiggle")
                        .font(.caption)
                }
                
                // Rotate
                VStack(spacing: 8) {
                    AnimatedSymbol(
                        "arrow.triangle.2.circlepath",
                        animation: .rotate,
                        isActive: true,
                        color: .blue,
                        size: .largeTitle
                    )
                    Text("Rotate")
                        .font(.caption)
                }
                
                // Breathe
                VStack(spacing: 8) {
                    AnimatedSymbol(
                        "tray",
                        animation: .breathe,
                        isActive: true,
                        color: .gray,
                        size: .largeTitle
                    )
                    Text("Breathe")
                        .font(.caption)
                }
                
                // Scale
                VStack(spacing: 8) {
                    AnimatedSymbol(
                        "star.fill",
                        animation: .scale,
                        isActive: true,
                        color: .yellow,
                        size: .largeTitle
                    )
                    Text("Scale")
                        .font(.caption)
                }
            }
            .padding()
            
            Divider()
            
            // Convenience methods
            Text("Métodos de conveniencia")
                .font(.headline)
            
            HStack(spacing: 32) {
                VStack(spacing: 8) {
                    AnimatedSymbol.loading()
                    Text("loading()")
                        .font(.caption)
                }
                
                VStack(spacing: 8) {
                    AnimatedSymbol.success(trigger: true)
                    Text("success()")
                        .font(.caption)
                }
                
                VStack(spacing: 8) {
                    AnimatedSymbol.warning()
                    Text("warning()")
                        .font(.caption)
                }
                
                VStack(spacing: 8) {
                    AnimatedSymbol.empty()
                    Text("empty()")
                        .font(.caption)
                }
            }
            .padding()
        }
        .padding()
    }
}
