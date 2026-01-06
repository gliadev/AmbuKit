//
//  SFSymbolsAnimationDemo.swift
//  AmbuKit
//
//  Created by Adolfo on 27/12/25.
//  Demo para LinkedIn: SF Symbols Animados - Antes vs Después
//  📱 Ejecutar en Preview para grabar video/GIF
//

import SwiftUI

// MARK: - Demo View para LinkedIn

/// Vista demo que muestra lado a lado la diferencia entre
/// SF Symbols estáticos y animados
///
/// 📹 Para grabar: Cmd+Shift+5 → Grabar ventana → Seleccionar Preview
@available(iOS 17.0, *)
struct SFSymbolsAnimationDemo: View {
    
    // MARK: - State
    
    @State private var successTrigger = 0
    @State private var isSyncing = false
    @State private var showError = false
    @State private var isBreathing = true
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    
                    // Header
                    headerSection
                    
                    Divider()
                    
                    // Comparativas
                    syncComparison
                    successComparison
                    errorComparison
                    emptyStateComparison
                    
                    Divider()
                    
                    // Controles interactivos
                    interactiveControls
                    
                    // Footer
                    footerSection
                }
                .padding()
            }
            .navigationTitle("SF Symbols Animados")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("❌ ANTES vs ✅ DESPUÉS")
                .font(.title2.bold())
            
            Text("Animaciones nativas iOS 17+")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Sync Comparison
    
    private var syncComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔄 Sincronización")
                .font(.headline)
            
            HStack(spacing: 40) {
                // ANTES
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    
                    Text("ANTES")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Text("Estático")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // DESPUÉS
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                        .symbolEffect(.rotate, isActive: isSyncing)  // 🎯
                    
                    Text("DESPUÉS")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Text(".symbolEffect(.rotate)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Success Comparison
    
    private var successComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("✓ Éxito / Confirmación")
                .font(.headline)
            
            HStack(spacing: 40) {
                // ANTES
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    
                    Text("ANTES")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Text("Aparece sin vida")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // DESPUÉS
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: successTrigger)   // 🎯
                    
                    Text("DESPUÉS")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Text(".symbolEffect(.bounce)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Error Comparison
    
    private var errorComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚠️ Error / Advertencia")
                .font(.headline)
            
            HStack(spacing: 40) {
                // ANTES
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    
                    Text("ANTES")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Text("No llama la atención")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // DESPUÉS
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                        .symbolEffect(.wiggle, isActive: showError)  // 🎯
                    
                    Text("DESPUÉS")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Text(".symbolEffect(.wiggle)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Empty State Comparison
    
    private var emptyStateComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📭 Estado Vacío")
                .font(.headline)
            
            HStack(spacing: 40) {
                // ANTES
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("ANTES")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Text("Frío, sin vida")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // DESPUÉS
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                        .symbolEffect(.breathe, isActive: isBreathing)  // 🎯
                    
                    Text("DESPUÉS")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Text(".symbolEffect(.breathe)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Interactive Controls
    
    private var interactiveControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎮 Prueba las animaciones")
                .font(.headline)
            
            VStack(spacing: 12) {
                Toggle("Sincronizando (rotate)", isOn: $isSyncing)
                Toggle("Mostrar error (wiggle)", isOn: $showError)
                Toggle("Respiración activa (breathe)", isOn: $isBreathing)
                
                Button {
                    successTrigger += 1
                } label: {
                    HStack {
                        Image(systemName: "hand.tap.fill")
                        Text("Disparar éxito (bounce)")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("AmbuKit - TFG DAM 2025")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Gestión de inventario para ambulancias")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top)
    }
}

// MARK: - Code Snippet View (para el post)

@available(iOS 17.0, *)
struct CodeSnippetDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("💻 Implementación")
                .font(.headline)
            
            // Código ANTES
            VStack(alignment: .leading, spacing: 4) {
                Text("❌ ANTES:")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                
                Text("""
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                """)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Código DESPUÉS
            VStack(alignment: .leading, spacing: 4) {
                Text("✅ DESPUÉS:")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                
                Text("""
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: successTrigger)
                """)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview("Demo LinkedIn") {
    SFSymbolsAnimationDemo()
}

@available(iOS 17.0, *)
#Preview("Code Snippet") {
    CodeSnippetDemo()
}
