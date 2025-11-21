//
//  AuditService.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//
import Foundation
import SwiftData

public struct AuditService {
    private let context: ModelContext;
    public init(_ context: ModelContext) { self.context = context }
    
    @discardableResult public func log(_ action: ActionKind, entity: EntityKind, entityId: String, actor: User?, details: String? = nil) -> AuditLog {
        let entry = AuditLog(actorUsername: actor?.username,
                             actorRole: actor?.role?.kind.rawValue,
                             action: action, entity: entity,
                             entityId: entityId, details: details);
        context.insert(entry);
        
        do {
            try context.save()
        } catch { } ; return entry }
}

