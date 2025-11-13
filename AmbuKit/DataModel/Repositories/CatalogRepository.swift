//
//  CatalogRepository.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData

public struct CatalogRepository {
    private let context: ModelContext
    public init(_ context: ModelContext) { self.context = context }

    @discardableResult
    public func createCategory(code: String, name: String, icon: String? = nil) -> Category {
        let c = Category(code: code, name: name, icon: icon)
        context.insert(c)
        return c
    }

    @discardableResult
    public func createUOM(symbol: String, name: String) -> UnitOfMeasure {
        let u = UnitOfMeasure(symbol: symbol, name: name)
        context.insert(u)
        return u
    }

    @discardableResult
    public func createItem(
        code: String,
        name: String,
        description: String? = nil,
        critical: Bool = false,
        minStock: Double? = nil,
        maxStock: Double? = nil,
        category: Category? = nil,
        uom: UnitOfMeasure? = nil
    ) -> CatalogItem {
        
        let i = CatalogItem(
            code: code,
            name: name,
            description: description,
            critical: critical,
            minStock: minStock,
            maxStock: maxStock,
            category: category,
            uom: uom
        )
        context.insert(i)
        return i
    }
}
