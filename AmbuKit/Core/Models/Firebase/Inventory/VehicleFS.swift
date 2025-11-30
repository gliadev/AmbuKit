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
    public let plate: String?
    
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
        VehicleType(rawValue: type) ?? .svb
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
        plate: String? = nil,
        type: VehicleType = .svb,
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
    /// Tipos de vehículos de emergencias sanitarias en España
    enum VehicleType: String, Codable, CaseIterable, Sendable {
        /// Soporte Vital Básico - Ambulancia convencional
        case svb = "SVB"
        
        /// Soporte Vital Avanzado - Ambulancia medicalizada
        case sva = "SVA"
        
        /// Soporte Vital Avanzado Enfermería - Ambulancia con enfermero
        case svae = "SVAe"
        
        /// Transporte Sanitario No Urgente
        case tsnu = "TSNU"
        
        /// Vehículo de Intervención Rápida
        case vir = "VIR"
        
        /// Helicóptero sanitario
        case helicopter = "HELI"
        
        /// Nombre para mostrar en UI
        var displayName: String {
            switch self {
            case .svb: return "SVB - Soporte Vital Básico"
            case .sva: return "SVA - Soporte Vital Avanzado"
            case .svae: return "SVAe - SVA Enfermería"
            case .tsnu: return "TSNU - Transporte No Urgente"
            case .vir: return "VIR - Vehículo Intervención Rápida"
            case .helicopter: return "Helicóptero Sanitario"
            }
        }
        
        /// Nombre corto para listas
        var shortName: String {
            switch self {
            case .svb: return "SVB"
            case .sva: return "SVA"
            case .svae: return "SVAe"
            case .tsnu: return "TSNU"
            case .vir: return "VIR"
            case .helicopter: return "HELI"
            }
        }
        
        /// Icono SF Symbol
        var icon: String {
            switch self {
            case .svb: return "cross.case"
            case .sva: return "cross.case.fill"
            case .svae: return "cross.case.fill"
            case .tsnu: return "car.side"
            case .vir: return "car.fill"
            case .helicopter: return "airplane"
            }
        }
        
        /// Color asociado (para UI)
        var colorName: String {
            switch self {
            case .svb: return "blue"
            case .sva: return "red"
            case .svae: return "orange"
            case .tsnu: return "green"
            case .vir: return "purple"
            case .helicopter: return "yellow"
            }
        }
        
        /// Indica si requiere médico a bordo
        var requiresDoctor: Bool {
            switch self {
            case .sva: return true
            default: return false
            }
        }
        
        /// Indica si requiere enfermero a bordo
        var requiresNurse: Bool {
            switch self {
            case .sva, .svae: return true
            default: return false
            }
        }
    }
}

// MARK: - Firestore Collection

public extension VehicleFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "vehicles"
}

// MARK: - Firestore Helpers

public extension VehicleFS {
    /// Crear VehicleFS desde snapshot de Firestore
    static func from(snapshot: DocumentSnapshot) -> VehicleFS? {
        try? snapshot.data(as: VehicleFS.self)
    }
    
    /// Convertir a diccionario para Firestore
    func toDictionary() throws -> [String: Any] {
        let encoder = Firestore.Encoder()
        return try encoder.encode(self)
    }
}  // ✅ Esta llave faltaba

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

// MARK: - Mutating Methods

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
        // Matrícula es opcional, no validamos
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

// MARK: - Equatable

extension VehicleFS: Equatable {
    public static func == (lhs: VehicleFS, rhs: VehicleFS) -> Bool {
        lhs.id == rhs.id &&
        lhs.code == rhs.code &&
        lhs.plate == rhs.plate &&
        lhs.type == rhs.type &&
        lhs.baseId == rhs.baseId &&
        lhs.kitIds == rhs.kitIds
    }
}






























