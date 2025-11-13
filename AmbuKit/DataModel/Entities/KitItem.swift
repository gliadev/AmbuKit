//
//  KitItem.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData

@Model public final class KitItem { public var quantity: Double; public var min: Double; public var max: Double?; public var expiry: Date?; public var lot: String?; public var notes: String?; @Relationship(deleteRule: .nullify) public var catalogItem: CatalogItem?; @Relationship(deleteRule: .nullify) public var kit: Kit?; public init(quantity: Double, min: Double, max: Double? = nil, expiry: Date? = nil, lot: String? = nil, notes: String? = nil, catalogItem: CatalogItem? = nil, kit: Kit? = nil) { self.quantity = quantity; self.min = min; self.max = max; self.expiry = expiry; self.lot = lot; self.notes = notes; self.catalogItem = catalogItem; self.kit = kit } } 
