//
//  RoleFS.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import Foundation
import FirebaseFirestore

/// Modelo de rol para Firestore
struct RoleFS: Codable, Identifiable, Equatable {
    
    @DocumentID var id: String?
    var kindRaw: String
    var displayName: String
    var createdAt: Date
    var updatedAt: Date
    
    // Computed property para acceder al enum RoleKind
    var kind: RoleKind {
        get { RoleKind(rawValue: kindRaw) ?? .sanitary }
        set { kindRaw = newValue.rawValue }
    }
    
    init(
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
    
    static let collectionName = "roles"
}
