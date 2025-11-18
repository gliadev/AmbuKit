//
//  AuditLogFS.swift
//  AmbuKit
//
//  Created by Adolfo on 13/11/25.
//



import Foundation
import FirebaseFirestore
import Combine


/// Modelo de registro de auditoría para Firestore
/// Registra todas las acciones realizadas por los usuarios para trazabilidad
/// Equivalente a AuditLog.swift de SwiftData pero adaptado a Firebase
public struct AuditLogFS: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// ID del documento en Firestore (generado automáticamente)
@DocumentID public var id: String?
    
    /// Fecha y hora en que ocurrió la acción
    public var timestamp: Date
    
    /// Nombre de usuario que realizó la acción
    public var actorUsername: String?
    
    /// Rol del usuario que realizó la acción
    public var actorRole: String?
    
    /// Acción realizada (almacenado como String)
    public var actionRaw: String
    
    /// Entidad sobre la que se realizó la acción (almacenado como String)
    public var entityRaw: String
    
    /// ID de la entidad afectada
    public var entityId: String
    
    /// Detalles adicionales sobre la acción (opcional)
    public var details: String?
    
    /// Fecha de creación del registro (mismo que timestamp generalmente)
    public var createdAt: Date
    
    /// Fecha de última actualización (normalmente no se actualiza)
    public var updatedAt: Date
    
    // MARK: - Computed Properties
    
    /// Acción de tipo enum (derivado de actionRaw)
    /// Este campo NO se guarda en Firestore
    public var action: ActionKind {
        get { ActionKind(rawValue: actionRaw) ?? .read }
        set { actionRaw = newValue.rawValue }
    }
    
    /// Entidad de tipo enum (derivado de entityRaw)
    /// Este campo NO se guarda en Firestore
    public var entity: EntityKind {
        get { EntityKind(rawValue: entityRaw) ?? .audit }
        set { entityRaw = newValue.rawValue }
    }
    
    // MARK: - Coding Keys
    
    public enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case actorUsername
        case actorRole
        case actionRaw
        case entityRaw
        case entityId
        case details
        case createdAt
        case updatedAt
        
    }
    
    // MARK: - Initialization
    
    public init(
        id: String? = UUID().uuidString,
        timestamp: Date = Date(),
        actorUsername: String?,
        actorRole: String?,
        action: ActionKind,
        entity: EntityKind,
        entityId: String,
        details: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actorUsername = actorUsername
        self.actorRole = actorRole
        self.actionRaw = action.rawValue
        self.entityRaw = entity.rawValue
        self.entityId = entityId
        self.details = details
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Firestore Collection

public extension AuditLogFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "auditLogs"
}

// MARK: - Helpers

public extension AuditLogFS {
    /// Crear AuditLogFS desde snapshot de Firestore
     static func from(snapshot: DocumentSnapshot) throws -> AuditLogFS? {
        try snapshot.data(as: AuditLogFS.self)
    }
    
    /// Convertir a diccionario para Firestore
     func toDictionary() throws -> [String: Any] {
        let encoder = Firestore.Encoder()
        return try encoder.encode(self)
    }
}

// MARK: - Business Logic Helpers

public extension AuditLogFS {
    /// Descripción legible de la acción
     var actionDescription: String {
        switch action {
        case .create: return "creó"
        case .read: return "consultó"
        case .update: return "modificó"
        case .delete: return "eliminó"
        }
    }
    
    /// Descripción legible de la entidad
     var entityDescription: String {
        switch entity {
        case .base: return "base"
        case .vehicle: return "vehículo"
        case .kit: return "kit"
        case .catalogItem: return "artículo de catálogo"
        case .kitItem: return "artículo de kit"
        case .user: return "usuario"
        case .category: return "categoría"
        case .unit: return "unidad de medida"
        case .audit: return "registro de auditoría"
        }
    }
    
    /// Mensaje completo de auditoría para mostrar en UI
     var fullMessage: String {
        let actor = actorUsername ?? "Usuario desconocido"
        let role = actorRole.map { " (\($0))" } ?? ""
        let detail = details.map { " - \($0)" } ?? ""
        return "\(actor)\(role) \(actionDescription) \(entityDescription) [\(entityId)]\(detail)"
    }
    
    /// Formato de fecha legible
     var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
