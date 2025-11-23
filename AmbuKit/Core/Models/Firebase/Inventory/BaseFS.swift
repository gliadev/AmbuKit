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
/// Equivalente a Base.swift de SwiftData pero adaptado a Firebase
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
    
    // MARK: - Computed Properties (solo para UI)
    
    /// Vehículos cargados (deben obtenerse de Firestore)
    /// Este campo NO se guarda en Firestore
    public var vehicles: [VehicleFS] = []
    
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
        // vehicles NO se codifica (es solo para UI)
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

// MARK: - Helpers

public extension BaseFS {
    /// Crear BaseFS desde snapshot de Firestore
    static func from(snapshot: DocumentSnapshot) throws -> BaseFS? {
        try snapshot.data(as: BaseFS.self)
    }
    
    /// Convertir a diccionario para Firestore
    func toDictionary() throws -> [String: Any] {
        let encoder = Firestore.Encoder()
        return try encoder.encode(self)
    }
}

// MARK: - Business Logic Helpers

public extension BaseFS {
    /// Añade un vehículo a la base
    mutating func addVehicle(vehicleId: String) {
        guard !vehicleIds.contains(vehicleId) else { return }
        vehicleIds.append(vehicleId)
        updatedAt = Date()
    }
    
    /// Elimina un vehículo de la base
    mutating func removeVehicle(vehicleId: String) {
        vehicleIds.removeAll { $0 == vehicleId }
        updatedAt = Date()
    }
    
    /// Verifica si un vehículo pertenece a esta base
    func hasVehicle(vehicleId: String) -> Bool {
        vehicleIds.contains(vehicleId)
    }
    
    /// Número total de vehículos en esta base
    var vehicleCount: Int {
        vehicleIds.count
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
