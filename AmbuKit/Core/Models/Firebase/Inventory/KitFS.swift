//
//  KitFS.swift
//  AmbuKit
//
//  Created by Adolfo on 13/11/25.
//

import Foundation
import FirebaseFirestore

/// Modelo Firebase para Kits
/// Representa un botiquín o kit de emergencias con su inventario
struct KitFS: Codable, Identifiable {
    // MARK: - Firestore Properties
    
    /// ID único en Firestore (auto-generado)
    @DocumentID var id: String?
    
    // MARK: - Data Properties
    
    /// Código único del kit (ej: "KIT-001", "AMPULARIO-SVA")
    var code: String
    
    /// Nombre descriptivo del kit (ej: "Kit Principal SVA", "Ampulario")
    var name: String
    
    /// Tipo de kit (enum compartido con SwiftData)
    var type: KitType
    
    /// Estado del kit (ej: "ok", "revision", "mantenimiento")
    var status: String
    
    /// Fecha de última auditoría/revisión (opcional)
    var lastAudit: Date?
    
    // MARK: - Relationships (por IDs)
    
    /// ID del vehículo al que está asignado (referencia a VehicleFS)
    var vehicleId: String?
    
    /// IDs de los items que contiene el kit
    /// Array vacío si no tiene items
    var itemIds: [String]
    
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
        case type
        case status
        case lastAudit
        case vehicleId
        case itemIds
        case createdAt
        case updatedAt
    }
    
    // MARK: - Initializer
    
    /// Inicializador para crear nuevo kit
    /// - Parameters:
    ///   - id: ID de Firestore (opcional, auto-generado si es nil)
    ///   - code: Código único del kit
    ///   - name: Nombre descriptivo
    ///   - type: Tipo de kit (SVB, SVAe, SVA, custom)
    ///   - status: Estado del kit (default: "ok")
    ///   - lastAudit: Fecha de última auditoría (opcional)
    ///   - vehicleId: ID del vehículo asignado (opcional)
    ///   - itemIds: IDs de items contenidos (default: array vacío)
    ///   - createdAt: Fecha de creación (default: ahora)
    ///   - updatedAt: Fecha de actualización (default: ahora)
    init(
        id: String? = nil,
        code: String,
        name: String,
        type: KitType,
        status: String = "ok",
        lastAudit: Date? = nil,
        vehicleId: String? = nil,
        itemIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.type = type
        self.status = status
        self.lastAudit = lastAudit
        self.vehicleId = vehicleId
        self.itemIds = itemIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Properties

extension KitFS {
    /// Indica si está asignado a un vehículo
    var isAssigned: Bool {
        vehicleId != nil && !(vehicleId?.isEmpty ?? true)
    }
    
    /// Indica si tiene items
    var hasItems: Bool {
        !itemIds.isEmpty
    }
    
    /// Cantidad de items en el kit
    var itemCount: Int {
        itemIds.count
    }
    
    /// Indica si tiene fecha de auditoría
    var hasBeenAudited: Bool {
        lastAudit != nil
    }
    
    /// Texto para mostrar la cantidad de items
    var itemCountText: String {
        switch itemCount {
        case 0:
            return "Sin items"
        case 1:
            return "1 item"
        default:
            return "\(itemCount) items"
        }
    }
    
    /// Color del estado para UI
    var statusColor: String {
        switch status.lowercased() {
        case "ok":
            return "green"
        case "revision", "revisión":
            return "orange"
        case "mantenimiento":
            return "red"
        default:
            return "gray"
        }
    }
    
    /// Icono SF Symbol según el estado
    var statusIcon: String {
        switch status.lowercased() {
        case "ok":
            return "checkmark.circle.fill"
        case "revision", "revisión":
            return "exclamationmark.triangle.fill"
        case "mantenimiento":
            return "wrench.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    /// Días desde la última auditoría
    var daysSinceLastAudit: Int? {
        guard let lastAudit = lastAudit else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: lastAudit, to: Date()).day
        return days
    }
    
    /// Texto descriptivo de la última auditoría
    var lastAuditText: String {
        guard let days = daysSinceLastAudit else {
            return "Nunca auditado"
        }
        
        switch days {
        case 0:
            return "Auditado hoy"
        case 1:
            return "Auditado ayer"
        case 2...7:
            return "Auditado hace \(days) días"
        case 8...30:
            return "Auditado hace \(days/7) semanas"
        case 31...365:
            return "Auditado hace \(days/30) meses"
        default:
            return "Auditoría antigua"
        }
    }
    
    /// Indica si necesita auditoría (más de 30 días)
    var needsAudit: Bool {
        guard let days = daysSinceLastAudit else { return true }
        return days > 30
    }
}

// MARK: - Item Management

extension KitFS {
    /// Añade un item al kit
    /// - Parameter itemId: ID del item a añadir
    /// - Returns: Nueva instancia con el item añadido
    func addingItem(_ itemId: String) -> KitFS {
        var copy = self
        if !copy.itemIds.contains(itemId) {
            copy.itemIds.append(itemId)
            copy.updatedAt = Date()
        }
        return copy
    }
    
    /// Elimina un item del kit
    /// - Parameter itemId: ID del item a eliminar
    /// - Returns: Nueva instancia sin el item
    func removingItem(_ itemId: String) -> KitFS {
        var copy = self
        copy.itemIds.removeAll { $0 == itemId }
        copy.updatedAt = Date()
        return copy
    }
    
    /// Verifica si contiene un item específico
    /// - Parameter itemId: ID del item a verificar
    /// - Returns: true si el item está en el kit
    func containsItem(_ itemId: String) -> Bool {
        itemIds.contains(itemId)
    }
}

// MARK: - Status Management

extension KitFS {
    /// Estados válidos para un kit
    enum Status: String, CaseIterable {
        case ok = "ok"
        case revision = "revision"
        case maintenance = "mantenimiento"
        
        var displayName: String {
            switch self {
            case .ok: return "Operativo"
            case .revision: return "En Revisión"
            case .maintenance: return "Mantenimiento"
            }
        }
        
        var color: String {
            switch self {
            case .ok: return "green"
            case .revision: return "orange"
            case .maintenance: return "red"
            }
        }
        
        var icon: String {
            switch self {
            case .ok: return "checkmark.circle.fill"
            case .revision: return "exclamationmark.triangle.fill"
            case .maintenance: return "wrench.fill"
            }
        }
    }
    
    /// Actualiza el estado del kit
    /// - Parameter newStatus: Nuevo estado
    /// - Returns: Nueva instancia con el estado actualizado
    func withStatus(_ newStatus: Status) -> KitFS {
        var copy = self
        copy.status = newStatus.rawValue
        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - Audit Management

extension KitFS {
    /// Marca el kit como auditado ahora
    /// - Returns: Nueva instancia con fecha de auditoría actualizada
    func markAsAudited() -> KitFS {
        var copy = self
        copy.lastAudit = Date()
        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - Vehicle Assignment

extension KitFS {
    /// Asigna el kit a un vehículo
    /// - Parameter vehicleId: ID del vehículo (nil para desasignar)
    /// - Returns: Nueva instancia con el vehículo asignado
    func assignedTo(vehicle vehicleId: String?) -> KitFS {
        var copy = self
        copy.vehicleId = vehicleId
        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - Helper Methods

extension KitFS {
    /// Crea una copia actualizada del kit
    /// - Parameter updates: Closure para modificar propiedades
    /// - Returns: Nueva instancia con cambios aplicados
    func updated(_ updates: (inout KitFS) -> Void) -> KitFS {
        var copy = self
        copy.updatedAt = Date()
        updates(&copy)
        return copy
    }
}

// MARK: - Firestore Collection

extension KitFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "kits"
}

// MARK: - Sample Data (para previews y testing)

#if DEBUG
extension KitFS {
    /// Kit de ejemplo: Ampulario SVA
    static let sampleAmpulario = KitFS(
        id: "kit_ampulario",
        code: "AMPULARIO-SVA",
        name: "Ampulario SVA",
        type: .SVA,
        status: "ok",
        lastAudit: Date().addingTimeInterval(-86400 * 5), // 5 días atrás
        vehicleId: "vehicle_sva_1",
        itemIds: ["item_adrenaline", "item_midazolam"]
    )
    
    /// Kit de ejemplo: Kit Principal
    static let samplePrincipal = KitFS(
        id: "kit_principal",
        code: "KIT-PRINCIPAL-001",
        name: "Kit Principal SVA",
        type: .SVA,
        status: "ok",
        lastAudit: Date().addingTimeInterval(-86400 * 2), // 2 días atrás
        vehicleId: "vehicle_sva_1",
        itemIds: ["item_gauze"]
    )
    
    /// Kit de ejemplo sin asignar
    static let sampleUnassigned = KitFS(
        id: "kit_spare",
        code: "KIT-RESERVA",
        name: "Kit Reserva",
        type: .custom,
        status: "revision",
        lastAudit: nil,
        vehicleId: nil,
        itemIds: []
    )
    
    /// Array de kits de ejemplo
    static let samples: [KitFS] = [
        sampleAmpulario,
        samplePrincipal,
        sampleUnassigned
    ]
}
#endif
