//
//  CatalogItemFS.swift
//  AmbuKit
//
//  Created by Adolfo on 13/11/25.
//

import Foundation
import FirebaseFirestore

/// Modelo Firebase para Items del Catálogo
/// Representa un producto/material disponible en el sistema (medicamentos, material sanitario, etc.)
struct CatalogItemFS: Codable, Identifiable {
    // MARK: - Firestore Properties
    
    /// ID único en Firestore (auto-generado)
    @DocumentID var id: String?
    
    // MARK: - Data Properties
    
    /// Código único del item (ej: "ADRE1MG", "MIDA5MG")
    var code: String
    
    /// Nombre del producto (ej: "Adrenalina 1mg", "Midazolam 5mg")
    var name: String
    
    /// Descripción detallada del producto (opcional)
    var itemDescription: String?
    
    /// Indica si es un item crítico (requiere atención especial)
    var critical: Bool
    
    /// Stock mínimo recomendado (opcional)
    var minStock: Double?
    
    /// Stock máximo recomendado (opcional)
    var maxStock: Double?
    
    // MARK: - Relationships (por IDs)
    
    /// ID de la categoría a la que pertenece (referencia a CategoryFS)
    var categoryId: String?
    
    /// ID de la unidad de medida (referencia a UnitOfMeasureFS)
    var uomId: String?
    
    // MARK: - Timestamps
    
    /// Fecha de creación del registro
    var createdAt: Date
    
    /// Fecha de última actualización
    var updatedAt: Date
    
    // MARK: - Coding Keys
    
    /// Mapeo de propiedades a nombres de campos en Firestore
    enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case itemDescription
        case critical
        case minStock
        case maxStock
        case categoryId
        case uomId
        case createdAt
        case updatedAt
    }
    
    // MARK: - Initializer
    
    /// Inicializador para crear nuevo item de catálogo
    /// - Parameters:
    ///   - id: ID de Firestore (opcional, auto-generado si es nil)
    ///   - code: Código único del item
    ///   - name: Nombre del producto
    ///   - description: Descripción detallada (opcional)
    ///   - critical: Si es item crítico (default: false)
    ///   - minStock: Stock mínimo recomendado (opcional)
    ///   - maxStock: Stock máximo recomendado (opcional)
    ///   - categoryId: ID de la categoría (opcional)
    ///   - uomId: ID de la unidad de medida (opcional)
    ///   - createdAt: Fecha de creación (default: ahora)
    ///   - updatedAt: Fecha de actualización (default: ahora)
    init(
        id: String? = nil,
        code: String,
        name: String,
        description: String? = nil,
        critical: Bool = false,
        minStock: Double? = nil,
        maxStock: Double? = nil,
        categoryId: String? = nil,
        uomId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.itemDescription = description
        self.critical = critical
        self.minStock = minStock
        self.maxStock = maxStock
        self.categoryId = categoryId
        self.uomId = uomId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Properties

extension CatalogItemFS {
    /// Indica si tiene descripción
    var hasDescription: Bool {
        itemDescription != nil && !(itemDescription?.isEmpty ?? true)
    }
    
    /// Indica si tiene rangos de stock definidos
    var hasStockRange: Bool {
        minStock != nil || maxStock != nil
    }
    
    /// Indica si pertenece a una categoría
    var hasCategory: Bool {
        categoryId != nil && !(categoryId?.isEmpty ?? true)
    }
    
    /// Indica si tiene unidad de medida asignada
    var hasUOM: Bool {
        uomId != nil && !(uomId?.isEmpty ?? true)
    }
    
    /// Badge para UI indicando si es crítico
    var criticalBadge: String {
        critical ? "⚠️ CRÍTICO" : ""
    }
}

// MARK: - Stock Validation

extension CatalogItemFS {
    /// Valida si una cantidad está dentro del rango recomendado
    /// - Parameter quantity: Cantidad a validar
    /// - Returns: Estado del stock (low, ok, high)
    func validateStock(_ quantity: Double) -> StockStatus {
        if let min = minStock, quantity < min {
            return .low
        }
        if let max = maxStock, quantity > max {
            return .high
        }
        return .ok
    }
    
    /// Estados posibles del stock
    enum StockStatus {
        case low      // Por debajo del mínimo
        case ok       // Dentro del rango
        case high     // Por encima del máximo
        
        var color: String {
            switch self {
            case .low: return "red"
            case .ok: return "green"
            case .high: return "orange"
            }
        }
        
        var icon: String {
            switch self {
            case .low: return "arrow.down.circle.fill"
            case .ok: return "checkmark.circle.fill"
            case .high: return "arrow.up.circle.fill"
            }
        }
    }
}

// MARK: - Helper Methods

extension CatalogItemFS {
    /// Crea una copia actualizada del item
    /// - Parameter updates: Closure para modificar propiedades
    /// - Returns: Nueva instancia con cambios aplicados
    func updated(_ updates: (inout CatalogItemFS) -> Void) -> CatalogItemFS {
        var copy = self
        copy.updatedAt = Date()
        updates(&copy)
        return copy
    }
}

// MARK: - Firestore Collection

extension CatalogItemFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "catalogItems"
}

// MARK: - Sample Data (para previews y testing)

#if DEBUG
extension CatalogItemFS {
    /// Item de ejemplo: Adrenalina
    static let sampleAdrenaline = CatalogItemFS(
        id: "item_adrenaline",
        code: "ADRE1MG",
        name: "Adrenalina 1mg",
        description: "Ampolla de adrenalina 1mg/ml para emergencias",
        critical: true,
        minStock: 10,
        maxStock: 50,
        categoryId: "cat_pharmacy",
        uomId: "uom_unit"
    )
    
    /// Item de ejemplo: Midazolam
    static let sampleMidazolam = CatalogItemFS(
        id: "item_midazolam",
        code: "MIDA5MG",
        name: "Midazolam 5mg",
        description: "Ampolla de midazolam 5mg/ml",
        critical: true,
        minStock: 5,
        maxStock: 30,
        categoryId: "cat_pharmacy",
        uomId: "uom_unit"
    )
    
    /// Item de ejemplo: Gasas
    static let sampleGauze = CatalogItemFS(
        id: "item_gauze",
        code: "GASA10X10",
        name: "Gasa estéril 10x10",
        description: "Gasa estéril para curas",
        critical: false,
        minStock: 20,
        maxStock: 100,
        categoryId: "cat_dressings",
        uomId: "uom_unit"
    )
    
    /// Array de items de ejemplo
    static let samples: [CatalogItemFS] = [
        sampleAdrenaline,
        sampleMidazolam,
        sampleGauze
    ]
}
#endif
