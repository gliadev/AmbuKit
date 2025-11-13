//
//  AuthorizationRulesTests.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import XCTest
import SwiftData
@testable import AmbuKit

@MainActor
final class AuthorizationRulesTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainerBuilder.make(inMemory: true)
        context = ModelContext(container)
        try SeedDataLoader.runIfNeeded(context: context)
    }

    func testSanitaryCapabilities() throws {
        let san = try XCTUnwrap(
            try context.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.username == "san.bilbao" }
            )).first
        )

        XCTAssertFalse(AuthorizationService.allowed(.create, on: .kit, for: san))
        XCTAssertFalse(AuthorizationService.allowed(.update, on: .kit, for: san))
        XCTAssertFalse(AuthorizationService.allowed(.delete, on: .kit, for: san))

        XCTAssertFalse(AuthorizationService.allowed(.create, on: .kitItem, for: san))
        XCTAssertTrue (AuthorizationService.allowed(.update, on: .kitItem, for: san))
    }

    func testLogisticsLimits() throws {
        let log = try XCTUnwrap(
            try context.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.username == "log.bilbao" }
            )).first
        )

        // Kits: no crear, sí mover/editar/borrar
        XCTAssertFalse(AuthorizationService.allowed(.create, on: .kit, for: log))
        XCTAssertTrue (AuthorizationService.allowed(.update, on: .kit, for: log))
        XCTAssertTrue (AuthorizationService.allowed(.delete, on: .kit, for: log))

        // Users: NO crear NI eliminar; sí leer/editar
        XCTAssertFalse(AuthorizationService.allowed(.create, on: .user, for: log))
        XCTAssertFalse(AuthorizationService.allowed(.delete, on: .user, for: log))
        XCTAssertTrue (AuthorizationService.allowed(.read,   on: .user, for: log))
        XCTAssertTrue (AuthorizationService.allowed(.update, on: .user, for: log))
    }

    func testProgrammerIsAdmin() throws {
        let prog = try XCTUnwrap(
            try context.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.username == "programmer" }
            )).first
        )

        for a in ActionKind.allCases {
            for e in EntityKind.allCases {
                XCTAssertTrue(AuthorizationService.allowed(a, on: e, for: prog),
                              "Programmer should be allowed \(a) on \(e)")
            }
        }
    }
}
