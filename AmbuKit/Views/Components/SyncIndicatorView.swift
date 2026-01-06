//
//  SyncIndicatorView.swift
//  AmbuKit
//
//  Created by Adolfo on 27/12/25.
//  Indicador visual de estado de sincronización con animaciones SF Symbols
//  Integración con SyncState existente en SyncServices.swift
//

import SwiftUI

// MARK: - Sync Indicator View

/// Indicador visual del estado de sincronización con animaciones nativas
///
/// ## Uso:
/// ```swift
/// SyncIndicatorView(state: syncService.currentState)
/// ```
///
/// ## Estados y animaciones:
/// - `.idle` → Icono estático (checkmark)
/// - `.syncing` → Rotación continua (arrow.triangle.2.circlepath)
/// - `.completed` → Bounce de éxito (checkmark.circle.fill)
/// - `.failed` → Wiggle de error (exclamationmark.triangle)
@available(iOS 17.0, *)
struct SyncIndicatorView: View {
    
    // MARK: - Properties
    
    let state: SyncState
    
    /// Trigger para animación de completado
    @State private var completedTrigger = false
    
    /// Trigger para animación de error
    @State private var errorTrigger = false
    
    // MARK: - Computed Properties
    
    private var iconName: String {
        state.icon
    }
    
    private var iconColor: Color {
        switch state {
        case .idle: return .gray
        case .syncing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 8) {
            // Icono animado según estado
            iconView
            
            // Texto de estado
            Text(state.displayName)
                .font(.caption)
                .foregroundStyle(iconColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(iconColor.opacity(0.1))
        .clipShape(Capsule())
        .onChange(of: state) { oldValue, newValue in
            handleStateChange(from: oldValue, to: newValue)
        }
    }
    
    // MARK: - Icon View
    
    @ViewBuilder
    private var iconView: some View {
        switch state {
        case .idle:
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(iconColor)
            
        case .syncing:
            // 🎯 Rotación continua mientras sincroniza
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(iconColor)
                .symbolEffect(.rotate, isActive: true)
            
        case .completed:
            // 🎯 Bounce al completar
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(iconColor)
                .symbolEffect(.bounce, value: completedTrigger)
            
        case .failed:
            // 🎯 Wiggle en error
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(iconColor)
                .symbolEffect(.wiggle, value: errorTrigger)
        }
    }
    
    // MARK: - State Change Handler
    
    private func handleStateChange(from oldState: SyncState, to newState: SyncState) {
        switch newState {
        case .completed:
            completedTrigger.toggle()
        case .failed:
            errorTrigger.toggle()
        default:
            break
        }
    }
}

// MARK: - Compact Version

/// Versión compacta solo con icono (para barras de navegación)
@available(iOS 17.0, *)
struct SyncIndicatorCompact: View {
    let state: SyncState
    
    var body: some View {
        Image(systemName: state.icon)
            .font(.body)
            .foregroundStyle(stateColor)
            .symbolEffect(.rotate, isActive: state == .syncing)
            .symbolEffect(.bounce, value: state == .completed)
    }
    
    private var stateColor: Color {
        switch state {
        case .idle: return .gray
        case .syncing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Sync Indicator - Estados") {
    VStack(spacing: 24) {
        Text("SyncIndicatorView")
            .font(.headline)
        
        VStack(spacing: 16) {
            SyncIndicatorView(state: .idle)
            SyncIndicatorView(state: .syncing)
            SyncIndicatorView(state: .completed)
            SyncIndicatorView(state: .failed("Error de red"))
        }
        
        Divider()
        
        Text("SyncIndicatorCompact")
            .font(.headline)
        
        HStack(spacing: 24) {
            SyncIndicatorCompact(state: .idle)
            SyncIndicatorCompact(state: .syncing)
            SyncIndicatorCompact(state: .completed)
            SyncIndicatorCompact(state: .failed("Error"))
        }
    }
    .padding()
}

@available(iOS 17.0, *)
#Preview("Sync Indicator - Interactivo") {
    SyncIndicatorInteractiveDemo()
}

// MARK: - Interactive Demo

@available(iOS 17.0, *)
struct SyncIndicatorInteractiveDemo: View {
    @State private var currentState: SyncState = .idle
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Demo Interactivo")
                .font(.headline)
            
            SyncIndicatorView(state: currentState)
                .scaleEffect(1.5)
            
            VStack(spacing: 12) {
                Button("Idle") { currentState = .idle }
                    .buttonStyle(.bordered)
                
                Button("Syncing") { currentState = .syncing }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                
                Button("Completed") { currentState = .completed }
                    .buttonStyle(.bordered)
                    .tint(.green)
                
                Button("Failed") { currentState = .failed("Error de prueba") }
                    .buttonStyle(.bordered)
                    .tint(.red)
            }
            
            // Simulación automática
            Button {
                simulateSync()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Simular sincronización")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func simulateSync() {
        currentState = .syncing
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            currentState = Bool.random() ? .completed : .failed("Error simulado")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                currentState = .idle
            }
        }
    }
}
