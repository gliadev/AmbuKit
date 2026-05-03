//
//  KitServiceTest.swift
//  AmbuKitTests
//

import Testing
@testable import AmbuKit
import Foundation
import FirebaseFirestore

@MainActor
@Suite(.tags(.firebase, .slow), .timeLimit(.minutes(2)))
final class KitServiceTests {

    private let service: KitService
    private let mockUser: UserFS

    private var createdKitIds: [String] = []

    init() async throws {
        self.service = KitService.shared
        service.clearKitCache()
        service.clearKitItemCache()

        self.mockUser = UserFS(
            uid: "firebase_test_user",
            username: "testuser",
            fullName: "Test User",
            email: "test@ambukit.com",
            active: true,
            roleId: "role_programmer"
        )
    }

    deinit {
        let svc = service
        let actor = mockUser
        let ids = createdKitIds
        Task { @MainActor in
            for kitId in ids {
                try? await svc.deleteKit(kitId: kitId, actor: actor)
            }
        }
    }

    // MARK: - Helper

    private func createTestKit(
        code: String,
        name: String,
        type: KitType = .SVA,
        status: KitFS.Status = .active,
        vehicleId: String? = nil
    ) async throws -> KitFS {
        let kit = try await service.createKit(
            code: "test_\(code)_\(UUID().uuidString.prefix(6))",
            name: name,
            type: type,
            status: status.rawValue,
            vehicleId: vehicleId,
            actor: mockUser
        )
        if let id = kit.id { createdKitIds.append(id) }
        return kit
    }

    // MARK: - Kit CREATE Tests

    @Test func createKit_Success() async throws {
        let kit = try await createTestKit(code: "KIT-001", name: "Test Kit", type: .SVA)
        #expect(kit.id != nil)
        #expect(kit.code.contains("test_"))
        #expect(kit.name == "Test Kit")
        #expect(kit.type == KitType.SVA.rawValue)
    }

    @Test func createKit_DuplicateCode() async throws {
        let uniqueCode = "DUP-KIT-\(UUID().uuidString.prefix(6))"

        let kit1 = try await service.createKit(
            code: uniqueCode,
            name: "Duplicate Kit 1",
            type: .SVB,
            actor: mockUser
        )
        if let id = kit1.id { createdKitIds.append(id) }

        await #expect(throws: (any Error).self) {
            let kit2 = try await self.service.createKit(
                code: uniqueCode,
                name: "Duplicate Kit 2",
                type: .SVB,
                actor: self.mockUser
            )
            if let id = kit2.id { self.createdKitIds.append(id) }
        }
    }

    @Test func createKit_EmptyCode() async throws {
        await #expect(throws: (any Error).self) {
            let kit = try await self.service.createKit(
                code: "",
                name: "Invalid Kit",
                type: .SVA,
                actor: self.mockUser
            )
            if let id = kit.id { self.createdKitIds.append(id) }
        }
    }

    @Test func createKit_EmptyName() async throws {
        await #expect(throws: (any Error).self) {
            let kit = try await self.service.createKit(
                code: "test_EMPTY-\(UUID().uuidString.prefix(6))",
                name: "",
                type: .SVA,
                actor: self.mockUser
            )
            if let id = kit.id { self.createdKitIds.append(id) }
        }
    }

    // MARK: - Kit UPDATE Tests

    @Test func updateKit_Success() async throws {
        let originalKit = try await createTestKit(
            code: "UPDATE-TEST",
            name: "Original Name",
            type: .SVA,
            status: .active
        )

        let kitId = try #require(originalKit.id)

        let updatedKit = KitFS(
            id: kitId,
            code: originalKit.code,
            name: "Updated Name",
            type: originalKit.type,
            status: .maintenance,
            lastAudit: originalKit.lastAudit,
            vehicleId: originalKit.vehicleId,
            itemIds: originalKit.itemIds
        )

        try await service.updateKit(kit: updatedKit, actor: mockUser)

        let fetched = await service.getKit(id: kitId)
        #expect(fetched?.name == "Updated Name")
        #expect(fetched?.status == .maintenance)
    }

    @Test func updateKit_StatusChange() async throws {
        let kit = try await createTestKit(
            code: "STATUS-TEST",
            name: "Status Test Kit",
            status: .active
        )

        let kitId = try #require(kit.id)

        let updatedKit = KitFS(
            id: kitId,
            code: kit.code,
            name: kit.name,
            type: kit.type,
            status: .inactive,
            lastAudit: kit.lastAudit,
            vehicleId: kit.vehicleId,
            itemIds: kit.itemIds
        )

        try await service.updateKit(kit: updatedKit, actor: mockUser)

        let fetched = await service.getKit(id: kitId)
        #expect(fetched?.status == .inactive)
    }

    // MARK: - Kit DELETE Tests

    @Test func deleteKit_Success() async throws {
        let kit = try await service.createKit(
            code: "test_DELETE-\(UUID().uuidString.prefix(6))",
            name: "To Delete",
            type: .SVA,
            actor: mockUser
        )

        let kitId = try #require(kit.id)

        try await service.deleteKit(kitId: kitId, actor: mockUser)

        let deleted = await service.getKit(id: kitId)
        #expect(deleted == nil)
    }

    @Test func deleteKit_WithItems() async throws {
        let kit = try await createTestKit(code: "KIT-WITH-ITEMS", name: "Kit With Items")
        let kitId = try #require(kit.id)

        do {
            try await service.deleteKit(kitId: kitId, actor: mockUser)
            createdKitIds.removeAll { $0 == kitId }
        } catch {
            // Esperado si el kit tiene items
        }
    }

    // MARK: - Kit QUERY Tests

    @Test func getAllKits() async throws {
        _ = try await createTestKit(code: "KIT-A", name: "Kit A", type: .SVA)
        _ = try await createTestKit(code: "KIT-B", name: "Kit B", type: .SVB)

        let kits = await service.getAllKits()
        #expect(kits.count >= 2)
    }

    @Test func getKitByCode() async throws {
        let uniqueCode = "test_UNIQUE-\(UUID().uuidString.prefix(6))"
        let created = try await service.createKit(
            code: uniqueCode,
            name: "Unique Kit",
            type: .SVA,
            actor: mockUser
        )
        if let id = created.id { createdKitIds.append(id) }

        let found = await service.getKitByCode(uniqueCode)
        #expect(found != nil)
        #expect(found?.id == created.id)
        #expect(found?.name == "Unique Kit")
    }

    @Test func getKitsByVehicle() async throws {
        let kits = await service.getKitsByVehicle(vehicleId: "nonexistent-vehicle-id")
        #expect(kits.isEmpty)
    }

    // MARK: - KitItem CREATE Tests

    @Test func addItemToKit_InvalidCatalogItem() async throws {
        let kit = try await createTestKit(code: "KIT-FOR-ITEMS", name: "Kit For Items")
        let kitId = try #require(kit.id)

        await #expect(throws: (any Error).self) {
            _ = try await self.service.addItemToKit(
                catalogItemId: "fake-catalog-item-that-does-not-exist",
                kitId: kitId,
                quantity: 10,
                min: 5,
                max: 20,
                actor: self.mockUser
            )
        }
    }

    @Test func addItemToKit_NegativeQuantity() async throws {
        let kit = try await createTestKit(code: "KIT-NEG", name: "Kit Negative")
        let kitId = try #require(kit.id)

        await #expect(throws: (any Error).self) {
            _ = try await self.service.addItemToKit(
                catalogItemId: "any-item-id",
                kitId: kitId,
                quantity: -5,
                min: 5,
                actor: self.mockUser
            )
        }
    }

    @Test func addItemToKit_MaxLessThanMin() async throws {
        let kit = try await createTestKit(code: "KIT-MINMAX", name: "Kit MinMax")
        let kitId = try #require(kit.id)

        await #expect(throws: (any Error).self) {
            _ = try await self.service.addItemToKit(
                catalogItemId: "any-item-id",
                kitId: kitId,
                quantity: 10,
                min: 20,
                max: 10,
                actor: self.mockUser
            )
        }
    }

    // MARK: - KitItem QUERY Tests

    @Test func getKitItems() async throws {
        let kit = try await createTestKit(code: "KIT-ITEMS-QUERY", name: "Kit Items Query")
        let kitId = try #require(kit.id)

        let items = await service.getKitItems(kitId: kitId)
        #expect(items.isEmpty)
    }

    // MARK: - Stock Operations Tests

    @Test func getLowStockItems() async throws {
        let items = await service.getLowStockItems()
        for item in items {
            #expect(item.isBelowMinimum)
        }
    }

    @Test func getExpiringItems() async throws {
        let items = await service.getExpiringItems()
        for item in items {
            #expect(item.isExpiringSoon || item.isExpired)
        }
    }

    @Test func getExpiredItems() async throws {
        let items = await service.getExpiredItems()
        for item in items {
            #expect(item.isExpired)
        }
    }

    @Test func getLowStockItemsInKit() async throws {
        let kit = try await createTestKit(code: "KIT-LOWSTOCK", name: "Kit Low Stock")
        let kitId = try #require(kit.id)

        let items = await service.getLowStockItemsInKit(kitId: kitId)
        #expect(items.isEmpty)
    }

    // MARK: - Statistics Tests

    @Test func getKitStatistics() async throws {
        let kit = try await createTestKit(code: "KIT-STATS", name: "Kit Stats")
        let kitId = try #require(kit.id)

        let stats = await service.getKitStatistics(kitId: kitId)

        #expect(stats.totalItems == 0)
        #expect(stats.lowStockItems == 0)
        #expect(stats.expiringItems == 0)
        #expect(stats.expiredItems == 0)
    }

    @Test func getGlobalStatistics() async throws {
        let stats = await service.getGlobalStatistics()

        #expect(stats.totalKits >= 0)
        #expect(stats.assignedKits >= 0)
        #expect(stats.unassignedKits >= 0)
        #expect(stats.totalKits == stats.assignedKits + stats.unassignedKits)
    }

    @Test func isKitComplete() async throws {
        let kit = try await createTestKit(code: "KIT-COMPLETE", name: "Kit Complete")
        let kitId = try #require(kit.id)

        let isComplete = await service.isKitComplete(kitId: kitId)
        #expect(isComplete)
    }

    // MARK: - Search Tests

    @Test func searchKits() async throws {
        let searchTerm = "SEARCHABLE-\(UUID().uuidString.prefix(4))"
        _ = try await createTestKit(code: "SEARCH-TEST-1", name: "\(searchTerm) Kit")

        let results = await service.searchKits(by: searchTerm)
        #expect(results.count >= 1)

        let found = results.first { $0.name.contains(searchTerm) || $0.code.contains(searchTerm) }
        #expect(found != nil)
    }

    @Test func searchKits_NoResults() async throws {
        let results = await service.searchKits(by: "XYZNONEXISTENT99999")
        #expect(results.isEmpty)
    }

    @Test func getKitsNeedingAudit() async throws {
        _ = await service.getKitsNeedingAudit()
    }

    // MARK: - Cache Tests

    @Test func cacheFunctionality() async throws {
        let kit = try await createTestKit(code: "CACHE-TEST", name: "Cache Kit")
        let kitId = try #require(kit.id)

        let first = await service.getKit(id: kitId)
        #expect(first != nil)

        let second = await service.getKit(id: kitId)
        #expect(second != nil)

        #expect(first?.id == second?.id)
        #expect(first?.code == second?.code)
        #expect(first?.name == second?.name)
    }

    @Test func clearCache() async throws {
        _ = await service.getAllKits()
        service.clearKitCache()
        service.clearKitItemCache()
        let kits = await service.getAllKits()
        #expect(kits.count >= 0)
    }

    // MARK: - Kit Type / Status parametrized

    @Test("Crear kit con todos los tipos", arguments: [KitType.SVB, .SVA, .SVAe, .custom])
    func createKit_AllTypes(_ kitType: KitType) async throws {
        let kit = try await createTestKit(
            code: "TYPE-\(kitType.rawValue)",
            name: "Kit \(kitType.rawValue)",
            type: kitType
        )
        #expect(kit.type == kitType.rawValue)
    }

    @Test("Kit con todos los estados", arguments: [
        KitFS.Status.active,
        .inactive,
        .maintenance,
        .expired
    ])
    func kitStatus_AllValues(_ status: KitFS.Status) async throws {
        let kit = try await createTestKit(
            code: "STATUS-\(status.rawValue)",
            name: "Kit \(status.rawValue)",
            status: status
        )
        #expect(kit.status == status)
    }
}
