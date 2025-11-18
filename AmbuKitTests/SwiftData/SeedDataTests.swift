//
//  SeedDataTests.swift
//  AmbuKitTests
//
//  Created by Adolfo on 11/11/25.
//

import XCTest
import SwiftData
@testable import AmbuKit

@MainActor
final class SeedDataTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainerBuilder.make(inMemory: true)
        context = ModelContext(container)
        try SeedDataLoader.runIfNeeded(context: context)
    }

    func testSeedCreatesInitialData() throws {
        let roles = try context.fetch(FetchDescriptor<Role>())
        XCTAssertEqual(Set(roles.map { $0.kind }),
                       Set([.programmer, .logistics, .sanitary]))

        let bases = try context.fetch(FetchDescriptor<Base>())
        XCTAssertGreaterThanOrEqual(bases.count, 2)

        let kits = try context.fetch(FetchDescriptor<Kit>())
        XCTAssertGreaterThanOrEqual(kits.count, 2)

        let items = try context.fetch(FetchDescriptor<KitItem>())
        XCTAssertGreaterThanOrEqual(items.count, 5)
    }
}
