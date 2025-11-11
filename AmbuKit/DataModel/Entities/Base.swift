//
//  Base.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData

@Model
public final class Base { @Attribute(.unique)
    public var code: String; public var name: String; public var location: String?; @Relationship(deleteRule: .cascade, inverse: \Vehicle.base)
    
    public var vehicles: [Vehicle] = []; public init(code: String, name: String, location: String? = nil) {
        self.code = code; self.name = name; self.location = location
    }
}

