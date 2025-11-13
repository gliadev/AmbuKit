//
//  ModelContainerBuilder.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData

public enum ModelContainerBuilder {
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Base.self,
            Vehicle.self,
            Kit.self,
            KitItem.self,
            CatalogItem.self,
            Category.self,
            UnitOfMeasure.self,
            Role.self,
            Policy.self,
            User.self,
            AuditLog.self
        ])

        
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
