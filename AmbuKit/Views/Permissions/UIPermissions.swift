//
//  UIPermissions.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import Foundation

enum UIPermissions {
    static func canCreateKits(_ user: User?) -> Bool {
        AuthorizationService.allowed(.create, on: .kit, for: user)
    }
    static func canEditThresholds(_ user: User?) -> Bool {
        guard let k = user?.role?.kind else { return false }
        return k == .programmer || k == .logistics
    }
    static func userMgmt(_ user: User?) -> (create: Bool, read: Bool, update: Bool, delete: Bool) {
        (AuthorizationService.allowed(.create, on: .user, for: user),
         AuthorizationService.allowed(.read,   on: .user, for: user),
         AuthorizationService.allowed(.update, on: .user, for: user),
         AuthorizationService.allowed(.delete, on: .user, for: user))
    }
}
