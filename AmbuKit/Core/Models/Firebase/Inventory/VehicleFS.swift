//
//  VehicleFS.swift
//  AmbuKit
//
//  Created by Adolfo on 13/11/25.
//

import Foundation
import FirebaseFirestore

/// Modelo Firebase para Vehículos
/// Representa una ambulancia o vehículo de emergencias
struct VehicleFS: Codable, Identifiable {
    // MARK: - Firestore Properties
    
    /// ID único en Firestore (auto-generado)
    @DocumentID var id: String?
    
    // MARK: - Data Properties
    
    /// Código único del vehículo (ej: "AMB-001", "SVA-2401")
    var code: String
    
    /// Matrícula del vehículo (opcional) (ej: "1234-ABC")
    var plate: String?
    
    /// Tipo de vehículo (ej: "SVB Básica", "SVA Avanzada", "SVAe Enfermerizada")
    var type: String
    
    // MARK: - Relationships (por IDs)
    
    /// ID de la base a la que está asignado el vehículo (referencia a BaseFS)
    var baseId: String?
    
    /// IDs de los kits asignados al vehículo
    /// Array vacío si no tiene kits asignados
    var kitIds: [String]
    
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
        case plate
        case type
        case baseId
        case kitIds
        case createdAt
        case updatedAt
    }
    
    // MARK: - Initializer
    
    /// Inicializador para crear nuevo vehículo
    /// - Parameters:
    ///   - id: ID de Firestore (opcional, auto-generado si es nil)
    ///   - code: Código único del vehículo
    ///   - plate: Matrícula del vehículo (opcional)
    ///   - type: Tipo de vehículo
    ///   - baseId: ID de la base asignada (opcional)
    ///   - kitIds: IDs de kits asignados (default: array vacío)
    ///   - createdAt: Fecha de creación (default: ahora)
    ///   - updatedAt: Fecha de actualización (default: ahora)
    init(
        id: String? = nil,
        code: String,
        plate: String? = nil,
        type: String,
        baseId: String? = nil,
        kitIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.plate = plate
        self.type = type
        self.baseId = baseId
        self.kitIds = kitIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Properties

extension VehicleFS {
    /// Indica si tiene matrícula registrada
    var hasPlate: Bool {
        plate != nil && !(plate?.isEmpty ?? true)
    }
    
    /// Indica si está asignado a una base
    var hasBase: Bool {
        baseId != nil && !(baseId?.isEmpty ?? true)
    }
    
    /// Indica si tiene kits asignados
    var hasKits: Bool {
        !kitIds.isEmpty
    }
    
    /// Cantidad de kits asignados
    var kitCount: Int {
        kitIds.count
    }
    
    /// Texto descriptivo del vehículo (código + matrícula si existe)
    var displayName: String {
        if hasPlate {
            return "\(code) (\(plate!))"
        }
        return code
    }
    
    /// Texto para mostrar la cantidad de kits
    var kitCountText: String {
        switch kitCount {
        case 0:
            return "Sin kits"
        case 1:
            return "1 kit"
        default:
            return "\(kitCount) kits"
        }
    }
    
    /// Icono SF Symbol según el tipo de vehículo
    var typeIcon: String {
        if type.contains("SVA") {
            return "cross.case.fill"
        } else if type.contains("SVB") {
            return "cross.circle.fill"
        } else {
            return "car.fill"
        }
    }
}

// MARK: - Kit Management

extension VehicleFS {
    /// Añade un kit al vehículo
    /// - Parameter kitId: ID del kit a añadir
    /// - Returns: Nueva instancia con el kit añadido
    func addingKit(_ kitId: String) -> VehicleFS {
        var copy = self
        if !copy.kitIds.contains(kitId) {
            copy.kitIds.append(kitId)
            copy.updatedAt = Date()
        }
        return copy
    }
    
    /// Elimina un kit del vehículo
    /// - Parameter kitId: ID del kit a eliminar
    /// - Returns: Nueva instancia sin el kit
    func removingKit(_ kitId: String) -> VehicleFS {
        var copy = self
        copy.kitIds.removeAll { $0 == kitId }
        copy.updatedAt = Date()
        return copy
    }
    
    /// Verifica si un kit está asignado a este vehículo
    /// - Parameter kitId: ID del kit a verificar
    /// - Returns: true si el kit está asignado
    func hasKit(_ kitId: String) -> Bool {
        kitIds.contains(kitId)
    }
}

// MARK: - Base Assignment

extension VehicleFS {
    /// Asigna el vehículo a una base
    /// - Parameter baseId: ID de la base
    /// - Returns: Nueva instancia con la base asignada
    func assignedTo(base baseId: String?) -> VehicleFS {
        var copy = self
        copy.baseId = baseId
        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - Helper Methods

extension VehicleFS {
    /// Crea una copia actualizada del vehículo
    /// - Parameter updates: Closure para modificar propiedades
    /// - Returns: Nueva instancia con cambios aplicados
    func updated(_ updates: (inout VehicleFS) -> Void) -> VehicleFS {
        var copy = self
        copy.updatedAt = Date()
        updates(&copy)
        return copy
    }
}

// MARK: - Firestore Collection

extension VehicleFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "vehicles"
}

// MARK: - Vehicle Types

extension VehicleFS {
    /// Tipos comunes de vehículos de emergencias
    enum VehicleType: String, CaseIterable {
        case svb = "SVB Básica"
        case svae = "SVAe Enfermerizada"
        case sva = "SVA Avanzada"
        
        var description: String {
            rawValue
        }
        
        var icon: String {
            switch self {
            case .svb:
                return "cross.circle.fill"
            case .svae:
                return "cross.case.fill"
            case .sva:
                return "staroflife.fill"
            }
        }
    }
}

// MARK: - Sample Data (para previews y testing)

#if DEBUG
extension VehicleFS {
    /// Vehículo de ejemplo: SVA en Bilbao 1
    static let sampleSVA = VehicleFS(
        id: "vehicle_sva_1",
        code: "SVA-2401",
        plate: "1234-ABC",
        type: VehicleType.sva.rawValue,
        baseId: "base_bilbao1",
        kitIds: ["kit_ampulario", "kit_principal"]
    )
    
    /// Vehículo de ejemplo: SVB en Trapaga
    static let sampleSVB = VehicleFS(
        id: "vehicle_svb_1",
        code: "SVB-2333",
        plate: "5678-DEF",
        type: VehicleType.svb.rawValue,
        baseId: "base_trapaga",
        kitIds: ["kit_basico"]
    )
    
    /// Vehículo de ejemplo sin asignar
    static let sampleUnassigned = VehicleFS(
        id: "vehicle_spare",
        code: "AMB-RESERVA",
        plate: nil,
        type: VehicleType.svae.rawValue,
        baseId: nil,
        kitIds: []
    )
    
    /// Array de vehículos de ejemplo
    static let samples: [VehicleFS] = [
        sampleSVA,
        sampleSVB,
        sampleUnassigned
    ]
}
#endif






