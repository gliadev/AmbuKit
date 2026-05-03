//
//  CatalogServiceTests.swift
//  AmbuKitTests
//

import Testing
@testable import AmbuKit
import Foundation
import FirebaseFirestore

@MainActor
@Suite(.tags(.firebase, .slow), .timeLimit(.minutes(2)))
final class CatalogServiceTests {

    private let service: CatalogService
    private let testProgrammerUser: UserFS?
    private let testLogisticsUser: UserFS?
    private let testSanitaryUser: UserFS?

    private let testCategory: CategoryFS?
    private let testUOM: UnitOfMeasureFS?

    init() async throws {
        self.service = CatalogService.shared
        service.clearCache()

        let roles = await PolicyService.shared.getAllRoles()
        let progRole = roles.first(where: { $0.kind == .programmer })
        let logRole = roles.first(where: { $0.kind == .logistics })
        let sanRole = roles.first(where: { $0.kind == .sanitary })

        let categories = await service.getAllCategories()
        self.testCategory = categories.first

        let uoms = await service.getAllUOMs()
        self.testUOM = uoms.first

        if let pid = progRole?.id {
            testProgrammerUser = UserFS(
                id: "test_prog_user_\(UUID().uuidString.prefix(6))",
                uid: "firebase_uid_programmer_\(UUID().uuidString.prefix(6))",
                username: "programmer_\(UUID().uuidString.prefix(6))",
                fullName: "Test Programmer",
                email: "prog_\(UUID().uuidString.prefix(6))@test.com",
                active: true,
                roleId: pid
            )
        } else { testProgrammerUser = nil }

        if let lid = logRole?.id {
            testLogisticsUser = UserFS(
                id: "test_log_user_\(UUID().uuidString.prefix(6))",
                uid: "firebase_uid_logistics_\(UUID().uuidString.prefix(6))",
                username: "logistics_\(UUID().uuidString.prefix(6))",
                fullName: "Test Logistics",
                email: "log_\(UUID().uuidString.prefix(6))@test.com",
                active: true,
                roleId: lid
            )
        } else { testLogisticsUser = nil }

        if let sid = sanRole?.id {
            testSanitaryUser = UserFS(
                id: "test_san_user_\(UUID().uuidString.prefix(6))",
                uid: "firebase_uid_sanitary_\(UUID().uuidString.prefix(6))",
                username: "sanitary_\(UUID().uuidString.prefix(6))",
                fullName: "Test Sanitary",
                email: "san_\(UUID().uuidString.prefix(6))@test.com",
                active: true,
                roleId: sid
            )
        } else { testSanitaryUser = nil }
    }

    deinit {
        let svc = service
        let actor = testProgrammerUser
        Task { @MainActor in
            guard let actor else { return }
            let items = await svc.getAllItems()
            for item in items where item.code.hasPrefix("TEST-") {
                if let id = item.id {
                    try? await svc.deleteItem(itemId: id, actor: actor)
                }
            }
            let categories = await svc.getAllCategories()
            for category in categories where category.code.hasPrefix("TEST-") {
                if let id = category.id {
                    try? await svc.deleteCategory(categoryId: id, actor: actor)
                }
            }
            let uoms = await svc.getAllUOMs()
            for uom in uoms where uom.symbol.hasPrefix("TEST-") {
                if let id = uom.id {
                    try? await svc.deleteUOM(uomId: id, actor: actor)
                }
            }
        }
    }

    // MARK: - CatalogItem CREATE Tests

    @Test func createItem_AsProgrammer_Success() async throws {
        guard let actor = testProgrammerUser else { return }

        let code = "TEST-ITEM-PROG-\(UUID().uuidString.prefix(6))"
        let name = "Test Item Programmer"

        let item = try await service.createItem(
            code: code,
            name: name,
            description: "Test description",
            critical: true,
            minStock: 10,
            maxStock: 50,
            actor: actor
        )

        #expect(item.id != nil)
        #expect(item.code == code)
        #expect(item.name == name)
        #expect(item.critical)
        #expect(item.minStock == 10)
        #expect(item.maxStock == 50)

        let itemId = try #require(item.id)
        let fetched = await service.getItem(id: itemId)
        #expect(fetched != nil)
        #expect(fetched?.code == code)
    }

    @Test func createItem_AsLogistics_CurrentlyUnauthorized() async throws {
        guard let actor = testLogisticsUser else { return }

        let code = "TEST-ITEM-LOG-\(UUID().uuidString.prefix(6))"

        do {
            _ = try await service.createItem(
                code: code,
                name: "Test Item Logistics",
                critical: false,
                actor: actor
            )
            Issue.record("⚠️ Logistics ahora PUEDE crear items - actualizar test")
        } catch let error as CatalogServiceError {
            if case .unauthorized = error {
                // ok
            } else {
                Issue.record("Error inesperado: \(error)")
            }
        }
    }

    @Test func createItem_AsSanitary_Unauthorized() async throws {
        guard let actor = testSanitaryUser else { return }

        let code = "TEST-ITEM-SAN-\(UUID().uuidString.prefix(6))"

        await #expect(throws: CatalogServiceError.self) {
            _ = try await self.service.createItem(
                code: code,
                name: "Test Item",
                actor: actor
            )
        }
    }

    @Test func createItem_DuplicateCode_ThrowsError() async throws {
        guard let actor = testProgrammerUser else { return }

        let code = "TEST-ITEM-DUP-\(UUID().uuidString.prefix(6))"
        _ = try await service.createItem(
            code: code,
            name: "First Item",
            actor: actor
        )

        await #expect(throws: CatalogServiceError.self) {
            _ = try await self.service.createItem(
                code: code,
                name: "Second Item",
                actor: actor
            )
        }
    }

    @Test func createItem_EmptyCode_ThrowsError() async throws {
        guard let actor = testProgrammerUser else { return }

        await #expect(throws: CatalogServiceError.self) {
            _ = try await self.service.createItem(
                code: "",
                name: "Test Item",
                actor: actor
            )
        }
    }

    @Test func createItem_WithCategoryAndUOM_Success() async throws {
        guard let actor = testProgrammerUser,
              let categoryId = testCategory?.id,
              let uomId = testUOM?.id else { return }

        let code = "TEST-ITEM-CAT-\(UUID().uuidString.prefix(6))"

        let item = try await service.createItem(
            code: code,
            name: "Test Item With Relations",
            categoryId: categoryId,
            uomId: uomId,
            actor: actor
        )

        #expect(item.categoryId == categoryId)
        #expect(item.uomId == uomId)
    }

    // MARK: - CatalogItem UPDATE Tests

    @Test func updateItem_Success() async throws {
        guard let actor = testProgrammerUser else { return }

        let code = "TEST-ITEM-UPD-\(UUID().uuidString.prefix(6))"
        var item = try await service.createItem(
            code: code,
            name: "Original Name",
            critical: false,
            actor: actor
        )

        item.name = "Updated Name"
        item.critical = true
        try await service.updateItem(item: item, actor: actor)

        let itemId = try #require(item.id)
        let updated = await service.getItem(id: itemId)
        #expect(updated?.name == "Updated Name")
        #expect(updated?.critical == true)
    }

    // MARK: - CatalogItem DELETE Tests

    @Test func deleteItem_AsProgrammer_Success() async throws {
        guard let actor = testProgrammerUser else { return }

        let code = "TEST-ITEM-DEL-\(UUID().uuidString.prefix(6))"
        let item = try await service.createItem(
            code: code,
            name: "Item To Delete",
            actor: actor
        )

        let itemId = try #require(item.id)

        try await service.deleteItem(itemId: itemId, actor: actor)

        let deleted = await service.getItem(id: itemId)
        #expect(deleted == nil)
    }

    @Test func deleteItem_AsLogistics_Unauthorized() async throws {
        guard let progActor = testProgrammerUser, let logActor = testLogisticsUser else { return }

        let code = "TEST-ITEM-DEL-LOG-\(UUID().uuidString.prefix(6))"
        let item = try await service.createItem(
            code: code,
            name: "Item",
            actor: progActor
        )
        let itemId = try #require(item.id)

        await #expect(throws: CatalogServiceError.self) {
            try await self.service.deleteItem(itemId: itemId, actor: logActor)
        }
    }

    // MARK: - CatalogItem QUERY Tests

    @Test func getAllItems_Success() async throws {
        guard let actor = testProgrammerUser else { return }

        let prefix = UUID().uuidString.prefix(6)
        _ = try await service.createItem(code: "TEST-ALL-\(prefix)-001", name: "Item 1", actor: actor)
        _ = try await service.createItem(code: "TEST-ALL-\(prefix)-002", name: "Item 2", actor: actor)

        service.clearCache()
        try await Task.sleep(for: .milliseconds(500))

        let items = await service.getAllItems()
        let testItems = items.filter { $0.code.hasPrefix("TEST-ALL-\(prefix)") }
        #expect(testItems.count >= 2)
    }

    @Test func getItemsByCategory_Success() async throws {
        guard let actor = testProgrammerUser, let categoryId = testCategory?.id else { return }

        let prefix = UUID().uuidString.prefix(6)
        _ = try await service.createItem(
            code: "TEST-CAT-\(prefix)-001",
            name: "Item Cat 1",
            categoryId: categoryId,
            actor: actor
        )
        _ = try await service.createItem(
            code: "TEST-CAT-\(prefix)-002",
            name: "Item Cat 2",
            categoryId: categoryId,
            actor: actor
        )

        service.clearCache()
        try await Task.sleep(for: .milliseconds(500))

        let items = await service.getItemsByCategory(categoryId: categoryId)
        let testItems = items.filter { $0.code.hasPrefix("TEST-CAT-\(prefix)") }
        #expect(testItems.count == 2)
    }

    @Test func getCriticalItems_Success() async throws {
        guard let actor = testProgrammerUser else { return }

        let prefix = UUID().uuidString.prefix(6)
        _ = try await service.createItem(
            code: "TEST-CRIT-\(prefix)-001",
            name: "Critical Item",
            critical: true,
            actor: actor
        )
        _ = try await service.createItem(
            code: "TEST-CRIT-\(prefix)-002",
            name: "Non-Critical Item",
            critical: false,
            actor: actor
        )

        service.clearCache()
        try await Task.sleep(for: .milliseconds(500))

        let criticalItems = await service.getCriticalItems()
        let testCritical = criticalItems.filter { $0.code.hasPrefix("TEST-CRIT-\(prefix)") }
        #expect(testCritical.count == 1)
        #expect(testCritical.first?.critical == true)
    }

    @Test func searchItems_Success() async throws {
        guard let actor = testProgrammerUser else { return }

        let prefix = UUID().uuidString.prefix(6)
        _ = try await service.createItem(
            code: "TEST-SEARCH-\(prefix)",
            name: "Adrenalina Test",
            actor: actor
        )

        service.clearCache()
        try await Task.sleep(for: .milliseconds(500))

        let results = await service.searchItems(by: "Adrenalina")
        let testResults = results.filter { $0.code.hasPrefix("TEST-SEARCH-\(prefix)") }
        #expect(testResults.count >= 1)
    }

    // MARK: - Category CREATE Tests

    @Test func createCategory_Success() async throws {
        guard let actor = testProgrammerUser else { return }

        let code = "TEST-CAT-\(UUID().uuidString.prefix(6))"
        let name = "Test Category"
        let icon = "folder.fill"

        let category = try await service.createCategory(
            code: code,
            name: name,
            icon: icon,
            actor: actor
        )

        #expect(category.id != nil)
        #expect(category.code == code)
        #expect(category.name == name)
        #expect(category.icon == icon)
    }

    @Test func createCategory_DuplicateCode_ThrowsError() async throws {
        guard let actor = testProgrammerUser else { return }

        let code = "TEST-CAT-DUP-\(UUID().uuidString.prefix(6))"
        _ = try await service.createCategory(
            code: code,
            name: "First",
            actor: actor
        )

        await #expect(throws: CatalogServiceError.self) {
            _ = try await self.service.createCategory(
                code: code,
                name: "Second",
                actor: actor
            )
        }
    }

    @Test func getAllCategories_Success() async throws {
        let categories = await service.getAllCategories()
        #expect(categories.count >= 0)
    }

    // MARK: - UnitOfMeasure CREATE Tests

    @Test func createUOM_Success() async throws {
        guard let actor = testProgrammerUser else { return }

        let symbol = "TEST-\(UUID().uuidString.prefix(4))"
        let name = "Test Unit"

        let uom = try await service.createUOM(
            symbol: symbol,
            name: name,
            actor: actor
        )

        #expect(uom.id != nil)
        #expect(uom.symbol == symbol)
        #expect(uom.name == name)
    }

    @Test func createUOM_DuplicateSymbol_ThrowsError() async throws {
        guard let actor = testProgrammerUser else { return }

        let symbol = "TEST-DUP-\(UUID().uuidString.prefix(4))"
        _ = try await service.createUOM(
            symbol: symbol,
            name: "First",
            actor: actor
        )

        await #expect(throws: CatalogServiceError.self) {
            _ = try await self.service.createUOM(
                symbol: symbol,
                name: "Second",
                actor: actor
            )
        }
    }

    @Test func getAllUOMs_Success() async throws {
        let uoms = await service.getAllUOMs()
        #expect(uoms.count >= 0)
    }

    // MARK: - Statistics Tests

    @Test func getStatistics_Success() async throws {
        guard let actor = testProgrammerUser else { return }

        let prefix = UUID().uuidString.prefix(6)
        _ = try await service.createItem(
            code: "TEST-STAT-\(prefix)-001",
            name: "Item 1",
            critical: true,
            actor: actor
        )
        _ = try await service.createItem(
            code: "TEST-STAT-\(prefix)-002",
            name: "Item 2",
            critical: false,
            actor: actor
        )

        service.clearCache()
        try await Task.sleep(for: .milliseconds(500))

        let stats = await service.getStatistics()
        #expect(stats.totalItems >= 2)
        #expect(stats.criticalItems >= 1)
    }
}
