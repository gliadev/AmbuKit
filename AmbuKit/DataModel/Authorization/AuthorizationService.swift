//
//  AuthorizationService.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation

public enum AuthorizationService {
    public static func allowed(_ action: ActionKind, on entity: EntityKind, for user: User?) -> Bool {
        guard let user, let role = user.role else { return false }

        if role.kind == .programmer { return true }

        guard let p = role.policies.first(where: { $0.entity == entity }) else { return false }

        switch action {
        case .create: return p.canCreate
        case .read:   return p.canRead
        case .update: return p.canUpdate
        case .delete: return p.canDelete
        }
    }
}

