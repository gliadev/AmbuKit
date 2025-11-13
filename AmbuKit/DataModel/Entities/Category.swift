//
//  Category.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData
@Model public final class Category { @Attribute(.unique) public var code: String; public var name: String; public var icon: String?; public init(code: String, name: String, icon: String? = nil) { self.code = code; self.name = name; self.icon = icon } }
