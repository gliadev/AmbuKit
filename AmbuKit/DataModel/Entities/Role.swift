//
//  Role.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//
import Foundation
import SwiftData

@Model
public final class Role {
    @Attribute(.unique)
    public var kindRaw: String

    public var displayName: String

    
    @Relationship(deleteRule: .cascade, inverse: \Policy.role)
    public var policies: [Policy] = []

    public var kind: RoleKind {
        get { RoleKind(rawValue: kindRaw) ?? .sanitary }
        set { kindRaw = newValue.rawValue }
    }

    public init(kind: RoleKind, displayName: String) {
        self.kindRaw = kind.rawValue
        self.displayName = displayName
    }
}
