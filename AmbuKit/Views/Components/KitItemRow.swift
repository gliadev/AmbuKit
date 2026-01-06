//
//  KitItemRow.swift
//  AmbuKit
//
//  Created by Adolfo on 9/12/25.
//  Updated: 27/12/25 - Añadidas animaciones SF Symbols (iOS 17+)
//

import SwiftUI

// MARK: - KitItemRow

/// Fila de item de kit con animaciones visuales para estados de alerta
///
/// ## Animaciones implementadas:
/// - **Badges de estado**: Pulse en BAJO STOCK y CADUCADO
/// - **Icono de actualización**: Rotate mientras guarda
/// - **Cantidad**: Bounce al cambiar
struct KitItemRow: View {
    
    // MARK: - Properties
    
    let item: KitItemFS
    let catalogItem: CatalogItemFS?
    let isUpdating: Bool
    let canEdit: Bool
    let onQuantityChange: (Double) async -> Void
    
    // MARK: - State
    
    @State private var localQuantity: Double
    @State private var quantityTrigger = 0  // Para animación bounce
    
    // MARK: - Init
    
    init(
        item: KitItemFS,
        catalogItem: CatalogItemFS?,
        isUpdating: Bool,
        canEdit: Bool,
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
        VStack(alignment: .leading, spacing: 8) {
            // Fila principal: nombre + cantidad
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    itemName
                    thresholdsText
                }
                
                Spacer()
                
                quantityControl
            }
            
            // Badges de estado (animados)
            statusBadges
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Item Name
    
    private var itemName: some View {
        Text(catalogItem?.name ?? item.catalogItemId ?? "Cargando...")
            .font(.body)
            .foregroundStyle(item.isBelowMinimum ? .red : .primary)
    }
    
    // MARK: - Thresholds Text
    
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
    
    // MARK: - Status Badges (Animados)
    
    @ViewBuilder
    private var statusBadges: some View {
        HStack(spacing: 6) {
            // ✅ Badge de bajo stock - ANIMADO con pulse
            if item.isBelowMinimum {
                StatusBadge.lowStock()
            }
            
            // ✅ Badge de sobre stock - ANIMADO con pulse suave
            if item.isAboveMaximum {
                StatusBadge.overStock()
            }
            
            // ✅ Badge de caducidad próxima - ANIMADO
            if item.isExpiringSoon && !item.isExpired {
                StatusBadge.expiringSoon()
            }
            
            // ✅ Badge de caducado - ANIMADO con pulse intenso
            if item.isExpired {
                StatusBadge.expired()
            }
        }
    }
    
    // MARK: - Quantity Control
    
    @ViewBuilder
    private var quantityControl: some View {
        if isUpdating {
            // ✅ ANIMACIÓN: Icono rotando mientras actualiza
            if #available(iOS 17.0, *) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .symbolEffect(.rotate, isActive: true)
                    .frame(width: 80)
            } else {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 80)
            }
        } else if canEdit {
            // Stepper editable con feedback visual
            HStack(spacing: 8) {
                // ✅ ANIMACIÓN: Número con bounce al cambiar
                if #available(iOS 17.0, *) {
                    Text("\(Int(localQuantity))")
                        .font(.title3.monospacedDigit().bold())
                        .foregroundStyle(quantityColor)
                        .contentTransition(.numericText())  // 🎯 Transición numérica
                        .frame(minWidth: 35, alignment: .trailing)
                } else {
                    Text("\(Int(localQuantity))")
                        .font(.title3.monospacedDigit().bold())
                        .foregroundStyle(quantityColor)
                        .frame(minWidth: 35, alignment: .trailing)
                }
                
                // Botones +/-
                Stepper("", value: $localQuantity, in: 0...999, step: 1)
                    .labelsHidden()
                    .onChange(of: localQuantity) { oldValue, newValue in
                        guard oldValue != newValue else { return }
                        quantityTrigger += 1
                        Task {
                            await onQuantityChange(newValue)
                        }
                    }
            }
        } else {
            // Solo lectura
            Text("\(Int(item.quantity))")
                .font(.title3.monospacedDigit().bold())
                .foregroundStyle(.secondary)
                .frame(minWidth: 40, alignment: .trailing)
        }
    }
    
    // MARK: - Helpers
    
    private var quantityColor: Color {
        if item.isBelowMinimum {
            return .red
        } else if item.isAboveMaximum {
            return .orange
        }
        return .primary
    }
}

// MARK: - Preview

#Preview("KitItemRow - Estados") {
    List {
        // Item OK
        KitItemRow(
            item: KitItemFS(
                id: "1",
                quantity: 15,
                min: 10,
                max: 50
            ),
            catalogItem: CatalogItemFS(
                id: "cat1",
                code: "ADR001",
                name: "Adrenalina 1mg",
                categoryId: "farm"
            ),
            isUpdating: false,
            canEdit: true,
            onQuantityChange: { _ in }
        )
        
        // Item bajo stock
        KitItemRow(
            item: KitItemFS(
                id: "2",
                quantity: 3,
                min: 10,
                max: 50
            ),
            catalogItem: CatalogItemFS(
                id: "cat2",
                code: "ATR001",
                name: "Atropina 0.5mg",
                categoryId: "farm"
            ),
            isUpdating: false,
            canEdit: true,
            onQuantityChange: { _ in }
        )
        
        // Item caducado
        KitItemRow(
            item: KitItemFS(
                id: "3",
                quantity: 20,
                min: 10,
                max: 50,
                expiry: Date().addingTimeInterval(-86400)  // Ayer
            ),
            catalogItem: CatalogItemFS(
                id: "cat3",
                code: "MOR001",
                name: "Morfina 10mg",
                categoryId: "farm"
            ),
            isUpdating: false,
            canEdit: true,
            onQuantityChange: { _ in }
        )
        
        // Item actualizando
        KitItemRow(
            item: KitItemFS(
                id: "4",
                quantity: 25,
                min: 10,
                max: 50
            ),
            catalogItem: CatalogItemFS(
                id: "cat4",
                code: "SUE001",
                name: "Suero Fisiológico 500ml",
                categoryId: "fluidos"
            ),
            isUpdating: true,
            canEdit: true,
            onQuantityChange: { _ in }
        )
    }
}
