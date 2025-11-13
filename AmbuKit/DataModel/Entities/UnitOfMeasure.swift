//
//  UnitOfMeasure.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData

@Model public final class UnitOfMeasure { @Attribute(.unique) public var symbol: String; public var name: String; public init(symbol: String, name: String) { self.symbol = symbol; self.name = name } }
