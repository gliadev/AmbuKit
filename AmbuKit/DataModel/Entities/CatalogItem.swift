//
//  CatalogItem.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData

@Model
public final class CatalogItem {
    @Attribute(.unique) public var code: String
    public var name: String
    public var itemDescription: String?
    public var critical: Bool
    public var minStock: Double?
    public var maxStock: Double?

    @Relationship(deleteRule: .nullify) public var category: Category?
    @Relationship(deleteRule: .nullify) public var uom: UnitOfMeasure?

    public init(
        code: String,
        name: String,
        description: String? = nil,
        critical: Bool = false,
        minStock: Double? = nil,
        maxStock: Double? = nil,
        category: Category? = nil,
        uom: UnitOfMeasure? = nil
    ) {
        self.code = code
        self.name = name
        self.itemDescription = description
        self.critical = critical
        self.minStock = minStock
        self.maxStock = maxStock
        self.category = category
        self.uom = uom
    }
}
