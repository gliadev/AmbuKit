//
//  BaseFS.swift
//  AmbuKit
//
//  Created by Adolfo on 13/11/25.
//


import Foundation
import FirebaseFirestore

/// Modelo de base/estación para Firestore
/// Representa una base o sede donde se ubican vehículos/ambulancias
public struct BaseFS: Codable, Identifiable, Equatable {
    
    // MARK: - Firestore Properties
    
    /// ID único en Firestore (auto-generado)
    @DocumentID public var id: String?
    
    // MARK: - Data Properties
    
    /// Código único de la base (ej: "2401", "2402", "2333")
    public var code: String
    
    /// Nombre descriptivo de la base (ej: "Bilbao 1", "Trapaga")
    public var name: String
    
    /// Ubicación o dirección de la base (opcional)
    public var address: String?
    
    /// Indica si la base está activa
    public var active: Bool
    
    // MARK: - Relationships (por IDs)
    
    /// IDs de los vehículos asignados a esta base
    /// Array vacío si no hay vehículos asignados
    public var vehicleIds: [String]
    
    // MARK: - Timestamps
    
    /// Fecha de creación del registro
    public var createdAt: Date
    
    /// Fecha de última actualización
    public var updatedAt: Date
    
    // MARK: - Coding Keys
    
    /// Mapeo de propiedades a nombres de campos en Firestore
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
    
    // MARK: - Initializer
    
    /// Inicializador para crear nueva base
    /// - Parameters:
    ///   - id: ID de Firestore (opcional, auto-generado si es nil)
    ///   - code: Código único de la base
    ///   - name: Nombre descriptivo
    ///   - address: Ubicación o dirección (opcional)
    ///   - active: Si está activa (default: true)
    ///   - vehicleIds: IDs de vehículos asignados (default: array vacío)
    ///   - createdAt: Fecha de creación (default: ahora)
    ///   - updatedAt: Fecha de actualización (default: ahora)
    public init(
        id: String? = nil,
        code: String,
        name: String,
        address: String? = nil,
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

// MARK: - Computed Properties

public extension BaseFS {
    /// Indica si tiene dirección definida
    var hasAddress: Bool {
        address != nil && !(address?.isEmpty ?? true)
    }
    
    /// Indica si tiene vehículos asignados
    var hasVehicles: Bool {
        !vehicleIds.isEmpty
    }
    
    /// Cantidad de vehículos asignados
    var vehicleCount: Int {
        vehicleIds.count
    }
    
    /// Texto para mostrar la cantidad de vehículos
    var vehicleCountText: String {
        switch vehicleCount {
        case 0:
            return "Sin vehículos"
        case 1:
            return "1 vehículo"
        default:
            return "\(vehicleCount) vehículos"
        }
    }
}

// MARK: - Vehicle Management

public extension BaseFS {
    /// Añade un vehículo a la base
    /// - Parameter vehicleId: ID del vehículo a añadir
    /// - Returns: Nueva instancia con el vehículo añadido
    func addingVehicle(_ vehicleId: String) -> BaseFS {
        var copy = self
        if !copy.vehicleIds.contains(vehicleId) {
            copy.vehicleIds.append(vehicleId)
            copy.updatedAt = Date()
        }
        return copy
    }
    
    /// Elimina un vehículo de la base
    /// - Parameter vehicleId: ID del vehículo a eliminar
    /// - Returns: Nueva instancia sin el vehículo
    func removingVehicle(_ vehicleId: String) -> BaseFS {
        var copy = self
        copy.vehicleIds.removeAll { $0 == vehicleId }
        copy.updatedAt = Date()
        return copy
    }
    
    /// Verifica si un vehículo está asignado a esta base
    /// - Parameter vehicleId: ID del vehículo a verificar
    /// - Returns: true si el vehículo está asignado
    func hasVehicle(_ vehicleId: String) -> Bool {
        vehicleIds.contains(vehicleId)
    }
}

// MARK: - Helper Methods

public extension BaseFS {
    /// Crea una copia actualizada de la base
    /// - Parameter updates: Closure para modificar propiedades
    /// - Returns: Nueva instancia con cambios aplicados
    func updated(_ updates: (inout BaseFS) -> Void) -> BaseFS {
        var copy = self
        copy.updatedAt = Date()
        updates(&copy)
        return copy
    }
}

// MARK: - Firestore Collection

public extension BaseFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "bases"
}

// MARK: - Firestore Helpers

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

// MARK: - Sample Data (para previews y testing)

#if DEBUG
public extension BaseFS {
    /// Base de ejemplo: Bilbao 1
    static let sampleBilbao1 = BaseFS(
        id: "base_bilbao1",
        code: "2401",
        name: "Bilbao 1",
        address: "Calle Gran Vía, 45, Bilbao",
        active: true,
        vehicleIds: ["vehicle_1", "vehicle_2"]
    )
    
    /// Base de ejemplo: Trapaga
    static let sampleTrapaga = BaseFS(
        id: "base_trapaga",
        code: "2333",
        name: "Trapaga",
        address: "Avda. Principal, 12, Trapaga",
        active: true,
        vehicleIds: ["vehicle_3"]
    )
    
    /// Base de ejemplo sin vehículos
    static let sampleEmpty = BaseFS(
        id: "base_empty",
        code: "9999",
        name: "Base Nueva",
        address: nil,
        active: true,
        vehicleIds: []
    )
    
    /// Array de bases de ejemplo
    static let samples: [BaseFS] = [
        sampleBilbao1,
        sampleTrapaga,
        sampleEmpty
    ]
}
#endif
