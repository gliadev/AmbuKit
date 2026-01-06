//
//  UserFS.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//


import Foundation
import FirebaseFirestore
import Combine

/// Modelo de usuario para Firestore
/// Equivalente a User.swift de SwiftData pero adaptado a Firebase
public struct UserFS: Codable, Identifiable, Sendable {
    
    // MARK: - Properties
    
    /// ID del documento en Firestore (generado automáticamente)
    @DocumentID public var id: String?
    
    /// UID de Firebase Auth (único por usuario)
    public let uid: String
    
    /// Nombre de usuario (único)
    public var username: String
    
    /// Nombre completo del usuario
    public var fullName: String
    
    /// Email del usuario
    public var email: String
    
    /// Indica si el usuario está activo
    public var active: Bool
    
    /// ID del rol asignado (referencia a RoleFS)
    public var roleId: String?
    
    /// ID de la base asignada (referencia a BaseFS)
    public var baseId: String?
    
    /// Fecha de creación
    public var createdAt: Date
    
    /// Fecha de última actualización
    public var updatedAt: Date
    
    // MARK: - Computed Properties (solo para UI)
    
    /// Rol cargado (debe obtenerse de Firestore)
    /// Este campo NO se guarda en Firestore
    public var role: RoleFS? = nil
    
    /// Base cargada (debe obtenerse de Firestore)
    /// Este campo NO se guarda en Firestore
    public var base: BaseFS? = nil
    
    // MARK: - Coding Keys
    
    public enum CodingKeys: String, CodingKey {
        case id
        case uid
        case username
        case fullName
        case email
        case active
        case roleId
        case baseId
        case createdAt
        case updatedAt
        // role y base NO se codifican (son solo para UI)
    }
    
    // MARK: - Initialization
    
    public init(
        id: String? = nil,
        uid: String,
        username: String,
        fullName: String,
        email: String,
        active: Bool = true,
        roleId: String? = nil,
        baseId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.uid = uid
        self.username = username
        self.fullName = fullName
        self.email = email
        self.active = active
        self.roleId = roleId
        self.baseId = baseId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Firestore Collection

public extension UserFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "users"
}

// MARK: - Helpers

public extension UserFS {
    /// Crear UserFS desde snapshot de Firestore
    static func from(snapshot: DocumentSnapshot) throws -> UserFS? {
        try snapshot.data(as: UserFS.self)
    }
    
    /// Convertir a diccionario para Firestore
    func toDictionary() throws -> [String: Any] {
        let encoder = Firestore.Encoder()
        return try encoder.encode(self)
    }
}
