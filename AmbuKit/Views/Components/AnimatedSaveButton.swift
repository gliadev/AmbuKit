//
//  AnimatedSaveButton.swift
//  AmbuKit
//
//  Created by Adolfo on 27/12/25.
//  Botón de guardado con animaciones SF Symbols para feedback visual
//

import SwiftUI

// MARK: - AnimatedSaveButton

/// Botón de guardado con animaciones de estado
///
/// ## Estados visuales:
/// - **Idle**: Icono de guardar estático
/// - **Saving**: Icono rotando
/// - **Success**: Checkmark con bounce
/// - **Error**: Triángulo con wiggle
///
/// ## Uso:
/// ```swift
/// AnimatedSaveButton(
///     state: $buttonState,
///     action: { await save() }
/// )
/// ```
@available(iOS 17.0, *)
struct AnimatedSaveButton: View {
    
    // MARK: - Properties
    
    @Binding var state: ButtonState
    let title: String
    let action: () async -> Void
    
    // MARK: - State
    
    @State private var successTrigger = 0
    @State private var errorTrigger = 0
    
    // MARK: - Button State
    
    enum ButtonState: Equatable {
        case idle
        case saving
        case success
        case error(String)
        
        var isDisabled: Bool {
            self == .saving
        }
    }
    
    // MARK: - Init
    
    init(
        state: Binding<ButtonState>,
        title: String = "Guardar",
        action: @escaping () async -> Void
    ) {
        self._state = state
        self.title = title
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        Button {
            Task {
                state = .saving
                await action()
            }
        } label: {
            HStack(spacing: 8) {
                iconView
                Text(buttonTitle)
            }
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: 100)
        }
        .buttonStyle(.borderedProminent)
        .tint(buttonColor)
        .buttonBorderShape(.capsule)
        .disabled(state.isDisabled)
        .onChange(of: state) { oldValue, newValue in
            handleStateChange(newValue)
        }
    }
    
    // MARK: - Icon View
    
    @ViewBuilder
    private var iconView: some View {
        switch state {
        case .idle:
            Image(systemName: "square.and.arrow.down.fill")
            
        case .saving:
            // 🎯 Rotación continua mientras guarda
            Image(systemName: "arrow.triangle.2.circlepath")
                .symbolEffect(.rotate, isActive: true)
            
        case .success:
            // 🎯 Bounce al completar con éxito
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: successTrigger)
            
        case .error:
            // 🎯 Wiggle en error
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
                .symbolEffect(.wiggle, value: errorTrigger)
        }
    }
    
    // MARK: - Computed Properties
    
    private var buttonTitle: String {
        switch state {
        case .idle: return title
        case .saving: return "Guardando..."
        case .success: return "¡Guardado!"
        case .error: return "Error"
        }
    }
    
    private var buttonColor: Color {
        switch state {
        case .idle: return .blue
        case .saving: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
    
    // MARK: - State Handler
    
    private func handleStateChange(_ newState: ButtonState) {
        switch newState {
        case .success:
            successTrigger += 1
            // Auto-reset después de 2 segundos
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if state == .success {
                    state = .idle
                }
            }
        case .error:
            errorTrigger += 1
            // Auto-reset después de 3 segundos
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if case .error = state {
                    state = .idle
                }
            }
        default:
            break
        }
    }
}

// MARK: - Simple Save Button (sin binding externo)

/// Versión simplificada que maneja el estado internamente
@available(iOS 17.0, *)
struct SimpleSaveButton: View {
    
    let title: String
    let action: () async throws -> Void
    let onSuccess: (() -> Void)?
    let onError: ((Error) -> Void)?
    
    @State private var state: AnimatedSaveButton.ButtonState = .idle
    
    init(
        title: String = "Guardar",
        action: @escaping () async throws -> Void,
        onSuccess: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.title = title
        self.action = action
        self.onSuccess = onSuccess
        self.onError = onError
    }
    
    var body: some View {
        AnimatedSaveButton(state: $state, title: title) {
            do {
                try await action()
                state = .success
                onSuccess?()
            } catch {
                state = .error(error.localizedDescription)
                onError?(error)
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("AnimatedSaveButton - Estados") {
    VStack(spacing: 24) {
        Text("AnimatedSaveButton")
            .font(.headline)
        
        // Demo interactivo
        AnimatedSaveButtonDemo()
    }
    .padding()
}

@available(iOS 17.0, *)
struct AnimatedSaveButtonDemo: View {
    @State private var state: AnimatedSaveButton.ButtonState = .idle
    
    var body: some View {
        VStack(spacing: 20) {
            AnimatedSaveButton(state: $state) {
                // Simular guardado
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                state = Bool.random() ? .success : .error("Error de red")
            }
            .scaleEffect(1.3)
            
            Divider()
            
            Text("Probar estados:")
                .font(.caption)
            
            HStack(spacing: 12) {
                Button("Idle") { state = .idle }
                    .buttonStyle(.bordered)
                
                Button("Saving") { state = .saving }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                
                Button("Success") { state = .success }
                    .buttonStyle(.bordered)
                    .tint(.green)
                
                Button("Error") { state = .error("Test") }
                    .buttonStyle(.bordered)
                    .tint(.red)
            }
            .font(.caption)
        }
    }
}
