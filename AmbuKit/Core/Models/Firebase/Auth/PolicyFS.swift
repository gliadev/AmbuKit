//
//  PolicyFS.swift
//  AmbuKit
//
//  Created by Adolfo on 13/11/25.
//

import Foundation
import FirebaseFirestore
import Combine


/// Modelo de política de permisos para Firestore
/// Define qué acciones puede realizar un rol sobre una entidad específica
/// Equivalente a Policy.swift de SwiftData pero adaptado a Firebase


public struct PolicyFS: Codable, Identifiable, Equatable {
    // MARK: - Properties
        
        /// ID del documento en Firestore (generado automáticamente)
        @DocumentID public var id: String?
        
        /// Entidad a la que aplica la política (almacenado como String)
        public var entityRaw: String
        
        /// Permiso para crear (CREATE)
        public var canCreate: Bool
        
        /// Permiso para leer (READ)
        public var canRead: Bool
        
        /// Permiso para actualizar (UPDATE)
        public var canUpdate: Bool
        
        /// Permiso para eliminar (DELETE)
        public var canDelete: Bool
        
        /// ID del rol al que pertenece esta política (referencia a RoleFS)
        public var roleId: String?
        
        /// Fecha de creación
        public var createdAt: Date
        
        /// Fecha de última actualización
        public var updatedAt: Date
        
        // MARK: - Computed Properties
        
        /// Entidad de tipo enum (derivado de entityRaw)
        /// Este campo NO se guarda en Firestore
        public var entity: EntityKind {
            get { EntityKind(rawValue: entityRaw) ?? .kit }
            set { entityRaw = newValue.rawValue }
        }
        
        /// Rol cargado (debe obtenerse de Firestore)
        /// Este campo NO se guarda en Firestore
        public var role: RoleFS? = nil
        
        // MARK: - Coding Keys
        
        public enum CodingKeys: String, CodingKey {
            case id
            case entityRaw
            case canCreate
            case canRead
            case canUpdate
            case canDelete
            case roleId
            case createdAt
            case updatedAt
            // entity y role NO se codifican (son solo para UI)
        }
        
        // MARK: - Initialization
        
        public init(
            id: String? = nil,
            entity: EntityKind,
            canCreate: Bool,
            canRead: Bool,
            canUpdate: Bool,
            canDelete: Bool,
            roleId: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date()
        ) {
            self.id = id
            self.entityRaw = entity.rawValue
            self.canCreate = canCreate
            self.canRead = canRead
            self.canUpdate = canUpdate
            self.canDelete = canDelete
            self.roleId = roleId
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    // MARK: - Firestore Collection

    public extension PolicyFS {
        /// Nombre de la colección en Firestore
        static let collectionName = "policies"
    }

    // MARK: - Helpers

    public extension PolicyFS {
        /// Crear PolicyFS desde snapshot de Firestore
        static func from(snapshot: DocumentSnapshot) throws -> PolicyFS? {
            try snapshot.data(as: PolicyFS.self)
        }
        
        /// Convertir a diccionario para Firestore
        func toDictionary() throws -> [String: Any] {
            let encoder = Firestore.Encoder()
            return try encoder.encode(self)
        }
    }

    // MARK: - Business Logic Helpers

    public extension PolicyFS {
        /// Verifica si tiene permiso para una acción específica
        func hasPermission(for action: ActionKind) -> Bool {
            switch action {
            case .create: return canCreate
            case .read: return canRead
            case .update: return canUpdate
            case .delete: return canDelete
            }
        }
        
        /// Verifica si tiene acceso completo (todos los permisos)
        var hasFullAccess: Bool {
            canCreate && canRead && canUpdate && canDelete
        }
        
        /// Verifica si solo tiene permisos de lectura
        var isReadOnly: Bool {
            canRead && !canCreate && !canUpdate && !canDelete
        }
    }
