//
//  Policy.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//
import Foundation
import SwiftData

@Model
public final class Policy {
    public var entityRaw: String
    public var canCreate: Bool
    public var canRead: Bool
    public var canUpdate: Bool
    public var canDelete: Bool

    
    @Relationship(deleteRule: .nullify)
    public var role: Role?

    public var entity: EntityKind {
        get { EntityKind(rawValue: entityRaw) ?? .kit }
        set { entityRaw = newValue.rawValue }
    }

    public init(
        entity: EntityKind,
        canCreate: Bool,
        canRead: Bool,
        canUpdate: Bool,
        canDelete: Bool,
        role: Role? = nil
    ) {
        self.entityRaw = entity.rawValue
        self.canCreate = canCreate
        self.canRead   = canRead
        self.canUpdate = canUpdate
        self.canDelete = canDelete
        self.role = role
    }
}
