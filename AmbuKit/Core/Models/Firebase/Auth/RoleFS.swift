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

//
//  BaseFS.swift
//  AmbuKit
//
//  Created by Migration Task 4
//  Modelo de base para Firebase/Firestore
//

/// Modelo de base/estación para Firestore
struct BaseFS: Codable, Identifiable, Equatable {
    
    @DocumentID var id: String?
    var code: String
    var name: String
    var address: String?
    var active: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String? = nil,
        code: String,
        name: String,
        address: String? = nil,
        active: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.address = address
        self.active = active
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    static let collectionName = "bases"
}






