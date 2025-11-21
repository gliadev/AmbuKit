//
//  User.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData

@Model
public final class User: @unchecked Sendable { 
    
    @Attribute(.unique)
    public var username: String
    
    public var fullName: String
    public var active: Bool
    
    @Relationship(deleteRule: .nullify)
    public var role: Role?
    
    @Relationship(deleteRule: .nullify)
    public var base: Base?
    
    public init(
        username: String,
        fullName: String,
        active: Bool = true,
        role: Role? = nil,
        base: Base? = nil
    ) {
        self.username = username
        self.fullName = fullName
        self.active = active
        self.role = role
        self.base = base
    }
}
