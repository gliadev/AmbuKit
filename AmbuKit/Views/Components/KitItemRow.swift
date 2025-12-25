//
//  KitItemRow.swift
//  AmbuKit
//
//  Created by Adolfo on 9/12/25.
//



import SwiftUI

// MARK: - KitItemRow

/// Componente reutilizable para mostrar un item de kit
/// Incluye nombre, umbrales, cantidad editable con Stepper y badges de estado
struct KitItemRow: View {
    
    // MARK: - Properties
    
    /// Item del kit a mostrar
    let item: KitItemFS
    
    /// Item del catálogo (para obtener nombre)
    let catalogItem: CatalogItemFS?
    
    /// Indica si este item se está actualizando
    let isUpdating: Bool
    
    /// Indica si el usuario puede editar la cantidad
    let canEdit: Bool
    
    /// Callback cuando cambia la cantidad
    let onQuantityChange: (Double) async -> Void
    
    // MARK: - State
    
    /// Cantidad local para el Stepper (evita problemas de binding async)
    @State private var localQuantity: Double
    
    // MARK: - Initialization
    
    init(
        item: KitItemFS,
        catalogItem: CatalogItemFS?,
        isUpdating: Bool,
        canEdit: Bool = true,
        onQuantityChange: @escaping (Double) async -> Void
    ) {
        self.item = item
        self.catalogItem = catalogItem
        self.isUpdating = isUpdating
        self.canEdit = canEdit
        self.onQuantityChange = onQuantityChange
        self._localQuantity = State(initialValue: item.quantity)
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // Indicador de estado (color lateral)
            statusIndicator
            
            // Contenido principal
            VStack(alignment: .leading, spacing: 6) {
                // Nombre del item
                itemName
                
                // Umbrales min/max
                thresholdsText
                
                // Badges de estado
                statusBadges
            }
            
            Spacer()
            
            // Control de cantidad
            quantityControl
        }
        .padding(.vertical, 4)
        // Actualizar cantidad local cuando cambie el item
        .onChange(of: item.quantity) { _, newValue in
            localQuantity = newValue
        }
    }
    
    // MARK: - Subviews
    
    /// Indicador visual de estado (barra lateral de color)
    private var statusIndicator: some View {
        Rectangle()
            .fill(statusColor)
            .frame(width: 4)
            .cornerRadius(2)
    }
    
    /// Color según el estado del stock
    private var statusColor: Color {
        if item.isBelowMinimum {
            return .red
        } else if item.isAboveMaximum {
            return .orange
        } else if item.isExpiringSoon {
            return .yellow
        } else if item.isExpired {
            return .purple
        } else {
            return .green
        }
    }
    
    /// Nombre del item del catálogo
    private var itemName: some View {
        Text(catalogItem?.name ?? "Cargando...")
            .font(.body)
            .foregroundStyle(item.isBelowMinimum ? .red : .primary)
    }
    
    /// Texto de umbrales (mínimo y máximo)
    private var thresholdsText: some View {
        HStack(spacing: 4) {
            Text("Mín: \(Int(item.min))")
            
            if let max = item.max {
                Text("·")
                Text("Máx: \(Int(max))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    
    /// Badges de estado (bajo stock, sobre stock, caducidad)
    @ViewBuilder
    private var statusBadges: some View {
        HStack(spacing: 6) {
            // Badge de bajo stock
            if item.isBelowMinimum {
                StatusBadge(
                    text: "BAJO STOCK",
                    icon: "arrow.down.circle.fill",
                    color: .red
                )
            }
            
            // Badge de sobre stock
            if item.isAboveMaximum {
                StatusBadge(
                    text: "SOBRE STOCK",
                    icon: "arrow.up.circle.fill",
                    color: .orange
                )
            }
            
            // Badge de caducidad próxima
            if item.isExpiringSoon && !item.isExpired {
                StatusBadge(
                    text: "CADUCA PRONTO",
                    icon: "clock.fill",
                    color: .yellow
                )
            }
            
            // Badge de caducado
            if item.isExpired {
                StatusBadge(
                    text: "CADUCADO",
                    icon: "exclamationmark.triangle.fill",
                    color: .purple
                )
            }
        }
    }
    
    /// Control de cantidad (Stepper o texto si no puede editar)
    @ViewBuilder
    private var quantityControl: some View {
        if isUpdating {
            // Spinner mientras actualiza
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 80)
        } else if canEdit {
            // Stepper editable
            Stepper(
                value: $localQuantity,
                in: 0...999,
                step: 1
            ) {
                Text("\(Int(localQuantity))")
                    .font(.body.monospacedDigit().bold())
                    .frame(minWidth: 30, alignment: .trailing)
            }
            .labelsHidden()
            .onChange(of: localQuantity) { oldValue, newValue in
                // Solo actualizar si el valor realmente cambió
                guard oldValue != newValue else { return }
                
                Task {
                    await onQuantityChange(newValue)
                }
            }
        } else {
            // Solo lectura
            Text("\(Int(item.quantity))")
                .font(.body.monospacedDigit().bold())
                .foregroundStyle(.secondary)
                .frame(minWidth: 40, alignment: .trailing)
        }
    }
}

// MARK: - StatusBadge

/// Badge pequeño para mostrar estados
private struct StatusBadge: View {
    let text: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color)
        .cornerRadius(4)
    }
}

// MARK: - Preview

#if DEBUG
struct KitItemRowPreview: PreviewProvider {
    static var previews: some View {
        List {
            KitItemRow(
                item: KitItemFS.sampleAdrenalineOK,
                catalogItem: nil,
                isUpdating: false,
                canEdit: true,
                onQuantityChange: { _ in }
            )
        }
        .previewDisplayName("Item OK")
    }
}
#endif




















