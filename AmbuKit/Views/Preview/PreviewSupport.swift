//
//  PreviewSupport.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI
import SwiftData

enum PreviewSupport {
    static let container: ModelContainer = {
        let container = try! ModelContainerBuilder.make(inMemory: true)
        let ctx = ModelContext(container)
        try? SeedDataLoader.runIfNeeded(context: ctx)
        return container
    }()

    static func user(_ username: String) -> User {
        let ctx = ModelContext(container)
        let u = try! ctx.fetch(FetchDescriptor<User>(predicate: #Predicate { $0.username == username })).first
        return u!
    }
}
