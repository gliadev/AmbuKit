//
//  PoliciesRepository.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData
public struct PoliciesRepository { private let context: ModelContext; public init(_ context: ModelContext) { self.context = context }
    @discardableResult public func createRole(_ kind: RoleKind, name: String) -> Role { let r = Role(kind: kind, displayName: name); context.insert(r); return r }
    @discardableResult public func grant(_ role: Role, entity: EntityKind, create: Bool, read: Bool, update: Bool, delete: Bool) -> Policy { let p = Policy(entity: entity, canCreate: create, canRead: read, canUpdate: update, canDelete: delete, role: role); context.insert(p); return p }
}
