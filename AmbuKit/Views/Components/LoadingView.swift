//
//  LoadingView.swift
//  AmbuKit
//
//  Created by Adolfo on 31/12/24.
//

import SwiftUI

/// Vista de carga con mensaje personalizable y animación suave
struct LoadingView: View {
    
    // MARK: - Properties
    
    let message: String
    let showBackground: Bool
    
    // MARK: - Initialization
    
    /// Crea una vista de carga
    /// - Parameters:
    ///   - message: Mensaje a mostrar (default: "Cargando...")
    ///   - showBackground: Si debe mostrar fondo (default: true)
    init(_ message: String = "Cargando...", showBackground: Bool = true) {
        self.message = message
        self.showBackground = showBackground
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(showBackground ? Color(.systemBackground) : Color.clear)
    }
}

// MARK: - Loading Overlay Modifier

/// Modificador para mostrar loading como overlay
struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let message: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)
            
            if isLoading {
                LoadingView(message, showBackground: false)
                    .background(.ultraThinMaterial)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

extension View {
    /// Muestra un overlay de carga sobre la vista
    /// - Parameters:
    ///   - isLoading: Si está cargando
    ///   - message: Mensaje a mostrar
    /// - Returns: Vista con overlay de carga
    func loadingOverlay(isLoading: Bool, message: String = "Cargando...") -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading, message: message))
    }
}

// MARK: - Previews

#Preview("LoadingView") {
    LoadingView("Cargando kits...")
}

#Preview("LoadingView - Sin fondo") {
    ZStack {
        Color.blue.opacity(0.3)
        LoadingView("Procesando...", showBackground: false)
    }
}

#Preview("Loading Overlay") {
    List {
        Text("Item 1")
        Text("Item 2")
        Text("Item 3")
    }
    .loadingOverlay(isLoading: true, message: "Guardando cambios...")
}
