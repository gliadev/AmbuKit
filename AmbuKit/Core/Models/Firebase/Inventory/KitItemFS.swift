//
//  KitItemFS.swift
//  AmbuKit
//
//  Created by Adolfo on 13/11/25.
//

import Foundation
import FirebaseFirestore

/// Modelo Firebase para Items de Kit
/// Representa un item específico dentro de un kit con su cantidad, umbrales y metadata
struct KitItemFS: Codable, Identifiable {
    // MARK: - Firestore Properties
    
    /// ID único en Firestore (auto-generado)
    @DocumentID var id: String?
    
    // MARK: - Data Properties
    
    /// Cantidad actual del item en el kit
    var quantity: Double
    
    /// Cantidad mínima requerida (umbral de alerta)
    var min: Double
    
    /// Cantidad máxima recomendada (opcional)
    var max: Double?
    
    /// Fecha de caducidad del item (opcional)
    var expiry: Date?
    
    /// Número de lote (opcional)
    var lot: String?
    
    /// Notas adicionales sobre el item (opcional)
    var notes: String?
    
    // MARK: - Relationships (por IDs)
    
    /// ID del item del catálogo (referencia a CatalogItemFS)
    var catalogItemId: String?
    
    /// ID del kit al que pertenece (referencia a KitFS)
    var kitId: String?
    
    // MARK: - Timestamps
    
    /// Fecha de creación del registro
    var createdAt: Date
    
    /// Fecha de última actualización
    var updatedAt: Date
    
    // MARK: - Coding Keys
    
    /// Mapeo de propiedades a nombres de campos en Firestore
    enum CodingKeys: String, CodingKey {
        case id
        case quantity
        case min
        case max
        case expiry
        case lot
        case notes
        case catalogItemId
        case kitId
        case createdAt
        case updatedAt
    }
    
    // MARK: - Initializer
    
    /// Inicializador para crear nuevo item de kit
    /// - Parameters:
    ///   - id: ID de Firestore (opcional, auto-generado si es nil)
    ///   - quantity: Cantidad actual
    ///   - min: Cantidad mínima requerida
    ///   - max: Cantidad máxima recomendada (opcional)
    ///   - expiry: Fecha de caducidad (opcional)
    ///   - lot: Número de lote (opcional)
    ///   - notes: Notas adicionales (opcional)
    ///   - catalogItemId: ID del item del catálogo (opcional)
    ///   - kitId: ID del kit al que pertenece (opcional)
    ///   - createdAt: Fecha de creación (default: ahora)
    ///   - updatedAt: Fecha de actualización (default: ahora)
    init(
        id: String? = nil,
        quantity: Double,
        min: Double,
        max: Double? = nil,
        expiry: Date? = nil,
        lot: String? = nil,
        notes: String? = nil,
        catalogItemId: String? = nil,
        kitId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.quantity = quantity
        self.min = min
        self.max = max
        self.expiry = expiry
        self.lot = lot
        self.notes = notes
        self.catalogItemId = catalogItemId
        self.kitId = kitId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Properties

extension KitItemFS {
    /// Indica si tiene cantidad máxima definida
    var hasMaxThreshold: Bool {
        max != nil
    }
    
    /// Indica si tiene fecha de caducidad
    var hasExpiry: Bool {
        expiry != nil
    }
    
    /// Indica si tiene número de lote
    var hasLot: Bool {
        lot != nil && !(lot?.isEmpty ?? true)
    }
    
    /// Indica si tiene notas
    var hasNotes: Bool {
        notes != nil && !(notes?.isEmpty ?? true)
    }
    
    /// Estado del stock basado en la cantidad actual
    var stockStatus: StockStatus {
        if quantity < min {
            return .low
        } else if let maxThreshold = max, quantity > maxThreshold {
            return .high
        } else {
            return .ok
        }
    }
    
    /// Indica si está por debajo del mínimo
    var isBelowMinimum: Bool {
        quantity < min
    }
    
    /// Indica si está por encima del máximo (si existe)
    var isAboveMaximum: Bool {
        guard let maxThreshold = max else { return false }
        return quantity > maxThreshold
    }
    
    /// Porcentaje respecto al mínimo (100% = en el mínimo, <100% = por debajo)
    var percentageOfMinimum: Double {
        guard min > 0 else { return 100 }
        return (quantity / min) * 100
    }
    
    /// Indica si el item está caducado
    var isExpired: Bool {
        guard let expiryDate = expiry else { return false }
        return expiryDate < Date()
    }
    
    /// Indica si el item está próximo a caducar (menos de 30 días)
    var isExpiringSoon: Bool {
        guard let expiryDate = expiry else { return false }
        let daysUntilExpiry = Calendar.current.dateComponents(
            [.day],
            from: Date(),
            to: expiryDate
        ).day ?? 0
        return daysUntilExpiry >= 0 && daysUntilExpiry <= 30
    }
    
    /// Días hasta la caducidad (negativo si ya caducó)
    var daysUntilExpiry: Int? {
        guard let expiryDate = expiry else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Date(),
            to: expiryDate
        ).day
    }
    
    /// Texto descriptivo de la caducidad
    var expiryStatusText: String {
        guard let expiryDate = expiry else { return "Sin caducidad" }
        
        if isExpired {
            return "⚠️ CADUCADO"
        } else if isExpiringSoon {
            if let days = daysUntilExpiry {
                return "⚠️ Caduca en \(days) días"
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Caduca: \(formatter.string(from: expiryDate))"
    }
}

// MARK: - Stock Status

extension KitItemFS {
    /// Estados posibles del stock
    enum StockStatus: String {
        case low = "bajo"
        case ok = "ok"
        case high = "exceso"
        
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
        
        var displayName: String {
            switch self {
            case .low: return "Stock Bajo"
            case .ok: return "Stock OK"
            case .high: return "Stock Alto"
            }
        }
    }
}

// MARK: - Quantity Management

extension KitItemFS {
    /// Actualiza la cantidad del item
    /// - Parameter newQuantity: Nueva cantidad
    /// - Returns: Nueva instancia con la cantidad actualizada
    func withQuantity(_ newQuantity: Double) -> KitItemFS {
        var copy = self
        copy.quantity = Swift.max(0, newQuantity) // No permitir cantidades negativas
        copy.updatedAt = Date()
        return copy
    }
    
    /// Añade cantidad al item
    /// - Parameter amount: Cantidad a añadir
    /// - Returns: Nueva instancia con la cantidad incrementada
    func addingQuantity(_ amount: Double) -> KitItemFS {
        withQuantity(quantity + amount)
    }
    
    /// Resta cantidad al item
    /// - Parameter amount: Cantidad a restar
    /// - Returns: Nueva instancia con la cantidad decrementada
    func subtractingQuantity(_ amount: Double) -> KitItemFS {
        withQuantity(quantity - amount)
    }
}

// MARK: - Threshold Management

extension KitItemFS {
    /// Actualiza los umbrales del item
    /// - Parameters:
    ///   - min: Nuevo mínimo
    ///   - max: Nuevo máximo (opcional)
    /// - Returns: Nueva instancia con umbrales actualizados
    func withThresholds(min: Double, max: Double? = nil) -> KitItemFS {
        var copy = self
        copy.min = min
        copy.max = max
        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - Expiry Management

extension KitItemFS {
    /// Actualiza la fecha de caducidad y el lote
    /// - Parameters:
    ///   - expiry: Nueva fecha de caducidad
    ///   - lot: Nuevo número de lote (opcional)
    /// - Returns: Nueva instancia con datos de caducidad actualizados
    func withExpiryData(expiry: Date?, lot: String? = nil) -> KitItemFS {
        var copy = self
        copy.expiry = expiry
        if let newLot = lot {
            copy.lot = newLot
        }
        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - Helper Methods

extension KitItemFS {
    /// Crea una copia actualizada del item
    /// - Parameter updates: Closure para modificar propiedades
    /// - Returns: Nueva instancia con cambios aplicados
    func updated(_ updates: (inout KitItemFS) -> Void) -> KitItemFS {
        var copy = self
        copy.updatedAt = Date()
        updates(&copy)
        return copy
    }
}

// MARK: - Firestore Collection

extension KitItemFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "kitItems"
}

// MARK: - Sample Data (para previews y testing)

#if DEBUG
extension KitItemFS {
    /// Item de ejemplo: Adrenalina con stock OK
    static let sampleAdrenalineOK = KitItemFS(
        id: "kititem_adre_1",
        quantity: 15,
        min: 10,
        max: 50,
        expiry: Date().addingTimeInterval(86400 * 180), // 6 meses
        lot: "LOT123456",
        notes: nil,
        catalogItemId: "item_adrenaline",
        kitId: "kit_ampulario"
    )
    
    /// Item de ejemplo: Midazolam con stock bajo
    static let sampleMidazolamLow = KitItemFS(
        id: "kititem_mida_1",
        quantity: 3,
        min: 5,
        max: 30,
        expiry: Date().addingTimeInterval(86400 * 90), // 3 meses
        lot: "LOT789012",
        notes: "⚠️ Reponer urgente",
        catalogItemId: "item_midazolam",
        kitId: "kit_ampulario"
    )
    
    /// Item de ejemplo: Gasas próximo a caducar
    static let sampleGauzeExpiring = KitItemFS(
        id: "kititem_gauze_1",
        quantity: 50,
        min: 20,
        max: 100,
        expiry: Date().addingTimeInterval(86400 * 15), // 15 días
        lot: "LOT345678",
        notes: "Revisar caducidad",
        catalogItemId: "item_gauze",
        kitId: "kit_principal"
    )
    
    /// Array de items de ejemplo
    static let samples: [KitItemFS] = [
        sampleAdrenalineOK,
        sampleMidazolamLow,
        sampleGauzeExpiring
    ]
}
#endif
