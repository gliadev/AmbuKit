//
//  AuditLog.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData

@Model public final class AuditLog { @Attribute(.unique) public var id: String; public var timestamp: Date; public var actorUsername: String?; public var actorRole: String?; public var actionRaw: String; public var entityRaw: String; public var entityId: String; public var details: String?; public var action: ActionKind { get { ActionKind(rawValue: actionRaw) ?? .read } set { actionRaw = newValue.rawValue } }; public var entity: EntityKind { get { EntityKind(rawValue: entityRaw) ?? .audit } set { entityRaw = newValue.rawValue } }; public init(id: String = UUID().uuidString, timestamp: Date = .now, actorUsername: String?, actorRole: String?, action: ActionKind, entity: EntityKind, entityId: String, details: String? = nil) { self.id = id; self.timestamp = timestamp; self.actorUsername = actorUsername; self.actorRole = actorRole; self.actionRaw = action.rawValue; self.entityRaw = entity.rawValue; self.entityId = entityId; self.details = details } }
