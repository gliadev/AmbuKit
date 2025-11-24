//
//  VehicleFS.swift
//  AmbuKit
//
//  Created by Adolfo on 13/11/25.
//


import Foundation
import FirebaseFirestore
import Combine

/// Modelo de vehículo para Firestore
/// Representa una ambulancia o vehículo médico
/// Equivalente a Vehicle.swift de SwiftData pero adaptado a Firebase
public struct VehicleFS: Codable, Identifiable, Sendable {
    
    // MARK: - Properties
    
    /// ID del documento en Firestore (generado automáticamente)
    @DocumentID public var id: String?
    
    /// Código único del vehículo (ej: "AMB001")
    public let code: String
    
    /// Matrícula del vehículo
    public let plate: String
    
    /// Tipo de vehículo (almacenado como String)
    public let type: String
    
    /// ID de la base a la que pertenece (referencia a BaseFS)
    public var baseId: String?
    
    /// IDs de kits asignados a este vehículo
    public var kitIds: [String]
    
    /// Fecha de creación
    public let createdAt: Date
    
    /// Fecha de última actualización
    public var updatedAt: Date
    
    // MARK: - Computed Properties (solo para UI)
    
    /// Tipo de vehículo como enum
    public var vehicleType: VehicleType {
        VehicleType(rawValue: type) ?? .ambulance
    }
    
    /// Base cargada (debe obtenerse de Firestore)
    /// Este campo NO se guarda en Firestore
    public var base: BaseFS? = nil
    
    /// Kits cargados (deben obtenerse de Firestore)
    /// Este campo NO se guarda en Firestore
    public var kits: [KitFS] = []
    
    // MARK: - Coding Keys
    
    public enum CodingKeys: String, CodingKey {
        case id
        case code
        case plate
        case type
        case baseId
        case kitIds
        case createdAt
        case updatedAt
        // vehicleType, base y kits NO se codifican (son solo para UI)
    }
    
    // MARK: - Initialization
    
    public init(
        id: String? = nil,
        code: String,
        plate: String,
        type: VehicleType = .ambulance,
        baseId: String? = nil,
        kitIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.plate = plate
        self.type = type.rawValue
        self.baseId = baseId
        self.kitIds = kitIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - VehicleType Enum

public extension VehicleFS {
    enum VehicleType: String, Codable, CaseIterable, Sendable {
        case ambulance = "ambulance"
        case van = "van"
        case car = "car"
        case motorcycle = "motorcycle"
        case helicopter = "helicopter"
        
        var displayName: String {
            switch self {
            case .ambulance: return "Ambulancia"
            case .van: return "Furgoneta"
            case .car: return "Coche"
            case .motorcycle: return "Motocicleta"
            case .helicopter: return "Helicóptero"
            }
        }
        
        var icon: String {
            switch self {
            case .ambulance: return "cross.case.fill"
            case .van: return "car.fill"
            case .car: return "car"
            case .motorcycle: return "bicycle"
            case .helicopter: return "airplane"
            }
        }
    }
}

// MARK: - Firestore Collection

public extension VehicleFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "vehicles"
}


// MARK: - Business Logic Helpers

// MARK: - Computed Properties (for Services)

public extension VehicleFS {
    /// Verifica si el vehículo tiene kits asignados
    var hasKits: Bool {
        !kitIds.isEmpty
    }
    
    /// Verifica si el vehículo tiene base asignada
    var hasBase: Bool {
        baseId != nil
    }
    
    /// ID de la base a la que está asignado (alias para compatibilidad)
    var assignedTo: String? {
        baseId
    }
}

public extension VehicleFS {
    /// Añade un kit al vehículo
    mutating func addKit(kitId: String) {
        guard !kitIds.contains(kitId) else { return }
        kitIds.append(kitId)
        updatedAt = Date()
    }
    
    /// Elimina un kit del vehículo
    mutating func removeKit(kitId: String) {
        kitIds.removeAll { $0 == kitId }
        updatedAt = Date()
    }
    
    /// Verifica si un kit está asignado a este vehículo
    func hasKit(kitId: String) -> Bool {
        kitIds.contains(kitId)
    }
    
    /// Número total de kits en este vehículo
    var kitCount: Int {
        kitIds.count
    }
    
    /// Asigna el vehículo a una base
    mutating func assignToBase(baseId: String) {
        self.baseId = baseId
        updatedAt = Date()
    }
    
    /// Desasigna el vehículo de su base actual
    mutating func unassignFromBase() {
        self.baseId = nil
        updatedAt = Date()
    }
}

// MARK: - Validation

public extension VehicleFS {
    /// Valida que los datos del vehículo sean correctos
    func validate() throws {
        guard !code.isEmpty else {
            throw ValidationError.emptyCode
        }
        guard !plate.isEmpty else {
            throw ValidationError.emptyPlate
        }
    }
    
    enum ValidationError: LocalizedError {
        case emptyCode
        case emptyPlate
        
        public var errorDescription: String? {
            switch self {
            case .emptyCode:
                return "El código del vehículo no puede estar vacío"
            case .emptyPlate:
                return "La matrícula del vehículo no puede estar vacía"
            }
        }
    }
}
