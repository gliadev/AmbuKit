//
//  DeletionAuditTests.swift
//  AmbuKitTests
//
//  Created by Adolfo on 11/11/25.
//


import XCTest
import SwiftData
@testable import AmbuKit

@MainActor
final class DeletionAuditTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        container = try ModelContainerBuilder.make(inMemory: true)
        context = ModelContext(container)
        try SeedDataLoader.runIfNeeded(context: context)
    }
    
    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Tests
    
    func testDeleteKitIsBlockedForSanitary() throws {
        let san = try XCTUnwrap(
            try context.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.username == "san.bilbao" }
            )).first
        )
        let kit = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Kit>(
                predicate: #Predicate { $0.code == "KIT-AMP-01" }
            )).first
        )

        let repo = KitsRepository(context)
        XCTAssertThrowsError(try repo.delete(kit, actor: san))
    }

    func testDeleteKitCreatesAuditForLogistics() throws {
        let log = try XCTUnwrap(
            try context.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.username == "log.bilbao" }
            )).first
        )

        let kitCode = "KIT-SVA-01"
        let kit = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Kit>(
                predicate: #Predicate { $0.code == kitCode }
            )).first
        )

        let repo = KitsRepository(context)
        try repo.delete(kit, actor: log)

        // kit eliminado
        let remaining = try context.fetch(FetchDescriptor<Kit>(
            predicate: #Predicate { $0.code == kitCode }
        ))
        XCTAssertTrue(remaining.isEmpty)

        // ❗️Nada de enums dentro de #Predicate: filtramos en memoria
        let allLogs = try context.fetch(FetchDescriptor<AuditLog>())
        let match = allLogs.first { $0.entityId == kitCode && $0.action == .delete }

        XCTAssertNotNil(match)
        XCTAssertEqual(match?.actorUsername, "log.bilbao")
    }
}
