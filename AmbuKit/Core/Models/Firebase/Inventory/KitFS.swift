//
//  KitFS.swift
//  AmbuKit
//
//  Created by Adolfo on 13/11/25.
//

import Foundation
import FirebaseFirestore
import Combine

/// Modelo de kit médico para Firestore
/// Representa un botiquín con sus items
/// Equivalente a Kit.swift de SwiftData pero adaptado a Firebase
public struct KitFS: Codable, Identifiable, Sendable {
    
    // MARK: - Properties
    
    /// ID del documento en Firestore (generado automáticamente)
    @DocumentID public var id: String?
    
    /// Código único del kit (ej: "KIT001")
    public let code: String
    
    /// Nombre del kit
    public let name: String
    
    /// Tipo de kit (ej: "emergency", "trauma", etc.)
    public let type: String
    
    /// Estado actual del kit
    public var status: Status
    
    /// Fecha de la última auditoría
    public var lastAudit: Date?
    
    /// ID del vehículo al que está asignado (referencia a VehicleFS)
    public var vehicleId: String?
    
    /// IDs de items del kit
    public var itemIds: [String]
    
    /// Fecha de creación
    public let createdAt: Date
    
    /// Fecha de última actualización
    public var updatedAt: Date
    
    // MARK: - Computed Properties (solo para UI)
    
    /// Vehículo cargado (debe obtenerse de Firestore)
    /// Este campo NO se guarda en Firestore
    public var vehicle: VehicleFS? = nil
    
    /// Items cargados (deben obtenerse de Firestore)
    /// Este campo NO se guarda en Firestore
    public var items: [KitItemFS] = []
    
    // MARK: - Coding Keys
    
    public enum CodingKeys: String, CodingKey {
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
        // vehicle e items NO se codifican (son solo para UI)
    }
    
    // MARK: - Initialization
    
    public init(
        id: String? = nil,
        code: String,
        name: String,
        type: String = "general",
        status: Status = .active,
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

// MARK: - Status Enum

public extension KitFS {
    enum Status: String, Codable, CaseIterable, Sendable {
        case active = "active"
        case inactive = "inactive"
        case maintenance = "maintenance"
        case expired = "expired"
        
        var displayName: String {
            switch self {
            case .active: return "Activo"
            case .inactive: return "Inactivo"
            case .maintenance: return "Mantenimiento"
            case .expired: return "Caducado"
            }
        }
        
        var color: String {
            switch self {
            case .active: return "green"
            case .inactive: return "gray"
            case .maintenance: return "orange"
            case .expired: return "red"
            }
        }
        
        var icon: String {
            switch self {
            case .active: return "checkmark.circle.fill"
            case .inactive: return "pause.circle.fill"
            case .maintenance: return "wrench.fill"
            case .expired: return "exclamationmark.triangle.fill"
            }
        }
    }
}

// MARK: - Firestore Collection

public extension KitFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "kits"
}

// MARK: - Business Logic Helpers

public extension KitFS {
    /// verificamos si un kit sta asignado a un vehiculo
    var isAssigned: Bool {
        vehicleId != nil
    }
    
    /// Añade un item al kit
    mutating func addItem(itemId: String) {
        guard !itemIds.contains(itemId) else { return }
        itemIds.append(itemId)
        updatedAt = Date()
    }
    
    /// Elimina un item del kit
    mutating func removeItem(itemId: String) {
        itemIds.removeAll { $0 == itemId }
        updatedAt = Date()
    }
    
    /// Verifica si un item está en el kit
    func hasItem(itemId: String) -> Bool {
        itemIds.contains(itemId)
    }
    
    /// Número total de items en el kit
    var itemCount: Int {
        itemIds.count
    }
    
    /// Asigna el kit a un vehículo
    mutating func assignToVehicle(vehicleId: String) {
        self.vehicleId = vehicleId
        updatedAt = Date()
    }
    
    /// Desasigna el kit de su vehículo actual
    mutating func unassignFromVehicle() {
        self.vehicleId = nil
        updatedAt = Date()
    }
    
    /// Actualiza el estado del kit
    mutating func updateStatus(_ newStatus: Status) {
        self.status = newStatus
        updatedAt = Date()
    }
    
    /// Registra una auditoría
    mutating func performAudit() {
        self.lastAudit = Date()
        updatedAt = Date()
    }
    
    /// Verifica si el kit necesita auditoría (más de 30 días)
    var needsAudit: Bool {
        guard let lastAudit = lastAudit else { return true }
        let daysSinceAudit = Calendar.current.dateComponents([.day], from: lastAudit, to: Date()).day ?? 0
        return daysSinceAudit > 30
    }
    
    /// Verifica si el kit está operativo
    var isOperational: Bool {
        status == .active
    }
}

// MARK: - Validation

public extension KitFS {
    /// Valida que los datos del kit sean correctos
    func validate() throws {
        guard !code.isEmpty else {
            throw ValidationError.emptyCode
        }
        guard !name.isEmpty else {
            throw ValidationError.emptyName
        }
    }
    
    enum ValidationError: LocalizedError {
        case emptyCode
        case emptyName
        
        public var errorDescription: String? {
            switch self {
            case .emptyCode:
                return "El código del kit no puede estar vacío"
            case .emptyName:
                return "El nombre del kit no puede estar vacío"
            }
        }
    }
}
