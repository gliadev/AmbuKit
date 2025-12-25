//
//  ThresholdRowView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//


import SwiftUI

// MARK: - ThresholdRowView (Firebase)

/// Fila para editar los umbrales (min/max) de un item de kit
struct ThresholdRowView: View {
    
    // MARK: - Properties
    
    let item: KitItemFS
    let catalogItem: CatalogItemFS?
    let currentUser: UserFS
    var onSaved: (() -> Void)?
    
    // MARK: - State
    
    @State private var newMin: Double
    @State private var newMax: Double?
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    // MARK: - Initialization
    
    init(
        item: KitItemFS,
        catalogItem: CatalogItemFS?,
        currentUser: UserFS,
        onSaved: (() -> Void)? = nil
    ) {
        self.item = item
        self.catalogItem = catalogItem
        self.currentUser = currentUser
        self.onSaved = onSaved
        
        // KitItemFS usa: min, max, quantity
        _newMin = State(initialValue: item.min)
        _newMax = State(initialValue: item.max)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            itemHeader
            thresholdInputs
            currentStockInfo
            actionRow
        }
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.2), value: showSuccess)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }
    
    // MARK: - Item Header
    
    private var itemHeader: some View {
        HStack(spacing: 8) {
            Text(catalogItem?.name ?? "Item desconocido")
                .font(.headline)
                .foregroundStyle(catalogItem != nil ? .primary : .secondary)
            
            Spacer()
            
            if catalogItem?.critical == true {
                Text("CRÍTICO")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            }
            
            // Stock bajo: quantity < min
            if item.quantity < item.min {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Threshold Inputs
    
    private var thresholdInputs: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mínimo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Min", value: $newMin, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Máximo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Max", value: Binding(
                    get: { newMax ?? 0 },
                    set: { newMax = $0 > 0 ? $0 : nil }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .frame(width: 80)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Current Stock Info
    
    private var currentStockInfo: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "cube.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("\(Int(item.quantity))")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Divider()
                .frame(height: 12)
            
            Text("Actual: \(Int(item.min))-\(Int(item.max ?? 0))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let code = catalogItem?.code {
                Divider()
                    .frame(height: 12)
                Text(code)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    // MARK: - Action Row
    
    private var actionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    Task { await saveThresholds() }
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Guardar")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(isSaving || !hasChanges || !isValid)
                
                if showSuccess {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Guardado")
                            .foregroundStyle(.green)
                    }
                    .font(.caption)
                    .transition(.opacity.combined(with: .scale))
                }
                
                Spacer()
                
                if hasChanges {
                    Button("Deshacer") {
                        resetValues()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            
            if let error = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                }
                .font(.caption)
            }
            
            if !isValid && hasChanges {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                    Text(validationMessage)
                        .foregroundStyle(.orange)
                }
                .font(.caption)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasChanges: Bool {
        newMin != item.min || newMax != item.max
    }
    
    private var isValid: Bool {
        guard newMin >= 0 else { return false }
        if let max = newMax, max < newMin {
            return false
        }
        return true
    }
    
    private var validationMessage: String {
        if newMin < 0 {
            return "El mínimo no puede ser negativo"
        }
        if let max = newMax, max < newMin {
            return "El máximo debe ser mayor o igual al mínimo"
        }
        return ""
    }
    
    // MARK: - Actions
    
    private func saveThresholds() async {
        isSaving = true
        showSuccess = false
        errorMessage = nil
        
        guard let itemId = item.id else {
            errorMessage = "Item sin ID válido"
            isSaving = false
            return
        }
        
        do {
            try await KitService.shared.updateKitThresholds(
                itemId: itemId,
                min: newMin,
                max: newMax,
                actor: currentUser
            )
            
            showSuccess = true
            onSaved?()
            
            try? await Task.sleep(for: .seconds(2))
            showSuccess = false
            
        } catch let error as KitServiceError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
        }
        
        isSaving = false
    }
    
    private func resetValues() {
        newMin = item.min
        newMax = item.max
        errorMessage = nil
    }
}

// MARK: - Preview

#if DEBUG
struct ThresholdRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ThresholdRowView(
                item: previewItem,
                catalogItem: previewCatalog,
                currentUser: previewUser
            )
        }
        .listStyle(.insetGrouped)
    }
    
    static let previewItem = KitItemFS(
        quantity: 15,
        min: 10,
        max: 50,
        expiry: nil,
        lot: nil,
        catalogItemId: "catalog_001",
        kitId: "kit_001"
    )
    
    static let previewCatalog = CatalogItemFS(
        id: "catalog_001",
        code: "GASA10X10",
        name: "Gasa estéril 10x10",
        critical: false
    )
    
    static let previewUser = UserFS(
        id: "user_prog",
        uid: "uid_prog",
        username: "admin",
        fullName: "Administrador",
        email: "admin@ambukit.com",
        active: true,
        roleId: "role_programmer",
        baseId: nil
    )
}
#endif
