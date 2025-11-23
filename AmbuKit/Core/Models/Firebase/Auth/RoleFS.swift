//
//  RoleFS.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//


import Foundation
import FirebaseFirestore
import Combine

/// Modelo de rol para Firestore
public struct RoleFS: Codable, Identifiable, Equatable, Sendable {
    
    @DocumentID public var id: String?
    public let kindRaw: String
    public let displayName: String
    public let createdAt: Date
    public var updatedAt: Date
    
    // Computed property para acceder al enum RoleKind
    public var kind: RoleKind {
        get { RoleKind(rawValue: kindRaw) ?? .sanitary }
        set { /* No se puede modificar en struct con let */ }
    }
    
    public init(
        id: String? = nil,
        kind: RoleKind,
        displayName: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public static let collectionName = "roles"
}

// MARK: - Helpers

public extension RoleFS {
    /// Crear RoleFS desde snapshot de Firestore
    static func from(snapshot: DocumentSnapshot) throws -> RoleFS? {
        try snapshot.data(as: RoleFS.self)
    }
    
    /// Convertir a diccionario para Firestore
    func toDictionary() throws -> [String: Any] {
        let encoder = Firestore.Encoder()
        return try encoder.encode(self)
    }
}






























































































































