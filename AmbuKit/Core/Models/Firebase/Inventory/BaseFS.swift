//
//  BaseFS.swift
//  AmbuKit
//
//  Created by Adolfo on 13/11/25.
//

import Foundation
import FirebaseFirestore
import Combine

/// Modelo de base médica para Firestore
/// Representa una base desde donde operan las ambulancias
public struct BaseFS: Codable, Identifiable, Sendable {
    
    // MARK: - Properties
    
    /// ID del documento en Firestore (generado automáticamente)
    @DocumentID public var id: String?
    
    /// Código único de la base (ej: "BASE001")
    public let code: String
    
    /// Nombre de la base
    public let name: String
    
    /// Dirección física de la base
    public let address: String
    
    /// Indica si la base está activa
    public var active: Bool
    
    /// IDs de vehículos asignados a esta base
    public var vehicleIds: [String]
    
    /// Fecha de creación
    public let createdAt: Date
    
    /// Fecha de última actualización
    public var updatedAt: Date
    
    // MARK: - Coding Keys
    
    public enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case address
        case active
        case vehicleIds
        case createdAt
        case updatedAt
    }
    
    // MARK: - Initialization
    
    public init(
        id: String? = nil,
        code: String,
        name: String,
        address: String,
        active: Bool = true,
        vehicleIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.address = address
        self.active = active
        self.vehicleIds = vehicleIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Firestore Collection

public extension BaseFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "bases"
}

// MARK: - Computed Properties
    
public extension BaseFS {
    /// Verifica si la base tiene vehículos asignados
    var hasVehicles: Bool {    
        !vehicleIds.isEmpty
    }
    
    /// Número total de vehículos en esta base
    var vehicleCount: Int {
        vehicleIds.count
    }
    
    /// Texto descriptivo del número de vehículos
    var vehicleCountText: String {
        switch vehicleCount {
        case 0: return "Sin vehículos"
        case 1: return "1 vehículo"
        default: return "\(vehicleCount) vehículos"
        }
    }
    
    /// Retorna una copia con updatedAt actualizado
    var updated: BaseFS {
        var copy = self
        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - Vehicle Management (Immutable Pattern)

public extension BaseFS {
    /// Retorna una copia con el vehículo añadido
    func addingVehicle(vehicleId: String) -> BaseFS {
        guard !vehicleIds.contains(vehicleId) else { return self }
        var copy = self
        copy.vehicleIds.append(vehicleId)
        copy.updatedAt = Date()
        return copy
    }
    
    /// Retorna una copia con el vehículo eliminado
    func removingVehicle(vehicleId: String) -> BaseFS {
        var copy = self
        copy.vehicleIds.removeAll { $0 == vehicleId }
        copy.updatedAt = Date()
        return copy
    }
    
    /// Verifica si un vehículo pertenece a esta base
    func hasVehicle(vehicleId: String) -> Bool {
        vehicleIds.contains(vehicleId)
    }
}

// MARK: - Mutating Methods (Alternative)

public extension BaseFS {
    /// Añade un vehículo a la base (mutating)
    mutating func addVehicle(vehicleId: String) {
        guard !vehicleIds.contains(vehicleId) else { return }
        vehicleIds.append(vehicleId)
        updatedAt = Date()
    }
    
    /// Elimina un vehículo de la base (mutating)
    mutating func removeVehicle(vehicleId: String) {
        vehicleIds.removeAll { $0 == vehicleId }
        updatedAt = Date()
    }
}

// MARK: - Validation

public extension BaseFS {
    /// Valida que los datos de la base sean correctos
    func validate() throws {
        guard !code.isEmpty else {
            throw ValidationError.emptyCode
        }
        guard !name.isEmpty else {
            throw ValidationError.emptyName
        }
        guard !address.isEmpty else {
            throw ValidationError.emptyAddress
        }
    }
    
    enum ValidationError: LocalizedError {
        case emptyCode
        case emptyName
        case emptyAddress
        
        public var errorDescription: String? {
            switch self {
            case .emptyCode:
                return "El código de la base no puede estar vacío"
            case .emptyName:
                return "El nombre de la base no puede estar vacío"
            case .emptyAddress:
                return "La dirección de la base no puede estar vacía"
            }
        }
    }
}
