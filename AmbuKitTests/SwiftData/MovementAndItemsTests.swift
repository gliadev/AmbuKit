//
//  MovementAndItemsTests.swift
//  AmbuKitTests
//
//  Created by Adolfo on 11/11/25.
//


import XCTest
import SwiftData
@testable import AmbuKit

@MainActor
final class MovementAndItemsTests: XCTestCase {
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
    
    func testOnlyProgrammerCanCreateKit() throws {
        let prog = try XCTUnwrap(
            try context.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.username == "programmer" }
            )).first
        )
        let log = try XCTUnwrap(
            try context.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.username == "log.bilbao" }
            )).first
        )
        let vehicle = try XCTUnwrap(try context.fetch(FetchDescriptor<Vehicle>()).first)

        let repo = KitsRepository(context)
        _ = try repo.create(code: "KIT-NEW-01", name: "Nuevo", type: .SVB, vehicle: vehicle, actor: prog)

        XCTAssertThrowsError(
            try repo.create(code: "KIT-NEW-02", name: "Nuevo2", type: .SVB, vehicle: vehicle, actor: log)
        )
    }

    func testThresholdsOnlyForProgrammerAndLogistics() throws {
        let san = try XCTUnwrap(
            try context.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.username == "san.bilbao" }
            )).first
        )
        let log = try XCTUnwrap(
            try context.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.username == "log.bilbao" }
            )).first
        )

        let allItems = try context.fetch(FetchDescriptor<KitItem>())
        guard let item = allItems.first(where: { $0.kit?.code == "KIT-AMP-01" }) ?? allItems.first else {
            XCTFail("Seed no creó KitItem para KIT-AMP-01"); return
        }

        let repo = KitsRepository(context)
        XCTAssertThrowsError(try repo.updateThresholds(item, min: 5.0, max: 12.0, actor: san))
        XCTAssertNoThrow(try repo.updateThresholds(item, min: 5.0, max: 12.0, actor: log))
    }

    func testLogisticsCannotCreateOrDeleteUsers() throws {
        let log = try XCTUnwrap(
            try context.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.username == "log.bilbao" }
            )).first
        )

        let allRoles = try context.fetch(FetchDescriptor<Role>())
        let roleSan = try XCTUnwrap(allRoles.first { $0.kind == .sanitary })

        let base = try XCTUnwrap(try context.fetch(FetchDescriptor<Base>()).first)

        let usersRepo = UsersRepository(context)

        XCTAssertThrowsError(
            try usersRepo.create(username: "x", fullName: "X", role: roleSan, base: base, actor: log)
        )

        let anyUser = try XCTUnwrap(
            try context.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.username == "san.bilbao" }
            )).first
        )
        XCTAssertThrowsError(try usersRepo.delete(anyUser, actor: log))
    }
}
