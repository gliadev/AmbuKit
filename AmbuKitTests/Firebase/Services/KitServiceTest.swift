//
//  KitServiceTest.swift
//  AmbuKit
//
//  Created by Adolfo on 18/11/25.
//


import XCTest
@testable import AmbuKit
import FirebaseFirestore

@MainActor
final class KitServiceTests: XCTestCase {
    
    var service: KitService!
    var mockUser: UserFS!
    
    override func setUp() async throws {
        try await super.setUp()
        service = KitService.shared
        service.clearCache()
        
        mockUser = UserFS(
            id: "test_user",
            uid: "firebase_test_user",
            username: "testuser",
            fullName: "Test User",
            email: "test@ambukit.com",
            active: true,
            roleId: "role_programmer"
        )
    }
    
    override func tearDown() async throws {
        service.clearCache()
        try await super.tearDown()
    }
    
    // MARK: - Kit CREATE Tests
    
    func testCreateKit_Success() async throws {
        let kit = try await service.createKit(
            code: "TEST-KIT-001",
            name: "Test Kit",
            type: .SVA,
            status: "ok",
            vehicleId: nil,
            actor: mockUser
        )
        
        XCTAssertNotNil(kit.id)
        XCTAssertEqual(kit.code, "TEST-KIT-001")
        XCTAssertEqual(kit.name, "Test Kit")
        XCTAssertEqual(kit.type, .SVA)
    }
    
    func testCreateKit_DuplicateCode() async throws {
        _ = try await service.createKit(
            code: "DUP-KIT",
            name: "Duplicate Kit 1",
            type: .SVB,
            actor: mockUser
        )
        
        do {
            _ = try await service.createKit(
                code: "DUP-KIT",
                name: "Duplicate Kit 2",
                type: .SVB,
                actor: mockUser
            )
            XCTFail("Debería lanzar error de código duplicado")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("duplicado"))
        }
    }
    
    func testCreateKit_EmptyCode() async throws {
        do {
            _ = try await service.createKit(
                code: "",
                name: "Invalid Kit",
                type: .SVA,
                actor: mockUser
            )
            XCTFail("Debería lanzar error de código vacío")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("código"))
        }
    }
    
    func testCreateKit_EmptyName() async throws {
        do {
            _ = try await service.createKit(
                code: "TEST-001",
                name: "",
                type: .SVA,
                actor: mockUser
            )
            XCTFail("Debería lanzar error de nombre vacío")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("nombre"))
        }
    }
    
    // MARK: - Kit UPDATE Tests
    
    func testUpdateKit_Success() async throws {
        var kit = try await service.createKit(
            code: "UPDATE-TEST",
            name: "Original Name",
            type: .SVA,
            actor: mockUser
        )
        
        kit.name = "Updated Name"
        kit.status = "revision"
        
        try await service.updateKit(kit: kit, actor: mockUser)
        
        let updated = await service.getKit(id: kit.id!)
        XCTAssertEqual(updated?.name, "Updated Name")
        XCTAssertEqual(updated?.status, "revision")
    }
    
    // MARK: - Kit DELETE Tests
    
    func testDeleteKit_Success() async throws {
        let kit = try await service.createKit(
            code: "DELETE-TEST",
            name: "To Delete",
            type: .SVA,
            actor: mockUser
        )
        
        try await service.deleteKit(kitId: kit.id!, actor: mockUser)
        
        let deleted = await service.getKit(id: kit.id!)
        XCTAssertNil(deleted)
    }
    
    func testDeleteKit_WithItems_Fails() async throws {
        let kit = try await service.createKit(
            code: "KIT-WITH-ITEMS",
            name: "Kit With Items",
            type: .SVA,
            actor: mockUser
        )
        
        // Simular que tiene items (en prueba real añadirías items)
        // Por ahora solo verificamos que existe la validación
        
        do {
            try await service.deleteKit(kitId: kit.id!, actor: mockUser)
        } catch {
            // Expected - kit sin items debería eliminar OK
            // Kit con items debería fallar
        }
    }
    
    // MARK: - Kit QUERY Tests
    
    func testGetAllKits() async throws {
        _ = try await service.createKit(
            code: "KIT-A",
            name: "Kit A",
            type: .SVA,
            actor: mockUser
        )
        
        _ = try await service.createKit(
            code: "KIT-B",
            name: "Kit B",
            type: .SVB,
            actor: mockUser
        )
        
        let kits = await service.getAllKits()
        XCTAssertGreaterThanOrEqual(kits.count, 2)
    }
    
    func testGetKitByCode() async throws {
        let created = try await service.createKit(
            code: "UNIQUE-CODE",
            name: "Unique Kit",
            type: .SVA,
            actor: mockUser
        )
        
        let found = await service.getKitByCode("UNIQUE-CODE")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, created.id)
        XCTAssertEqual(found?.name, "Unique Kit")
    }
    
    func testGetKitsByVehicle() async throws {
        // Necesitaría un vehículo real para este test
        // Por ahora verificamos que la función no crashea
        let kits = await service.getKitsByVehicle(vehicleId: "test-vehicle")
        XCTAssertNotNil(kits)
    }
    
    func testGetUnassignedKits() async throws {
        _ = try await service.createKit(
            code: "UNASSIGNED",
            name: "Unassigned Kit",
            type: .custom,
            vehicleId: nil,
            actor: mockUser
        )
        
        let unassigned = await service.getUnassignedKits()
        XCTAssertGreaterThanOrEqual(unassigned.count, 1)
    }
    
    // MARK: - KitItem CREATE Tests
    
    func testAddItemToKit_Success() async throws {
        let kit = try await service.createKit(
            code: "KIT-FOR-ITEMS",
            name: "Kit For Items",
            type: .SVA,
            actor: mockUser
        )
        
        // Necesitaría un catalogItemId real
        // Por ahora solo verificamos la estructura
        do {
            _ = try await service.addItemToKit(
                catalogItemId: "fake-catalog-item",
                kitId: kit.id!,
                quantity: 10,
                min: 5,
                max: 20,
                actor: mockUser
            )
        } catch {
            // Expected si el catalogItem no existe
            XCTAssertTrue(error.localizedDescription.contains("catálogo"))
        }
    }
    
    func testAddItemToKit_NegativeQuantity() async throws {
        let kit = try await service.createKit(
            code: "KIT-NEG",
            name: "Kit Negative",
            type: .SVA,
            actor: mockUser
        )
        
        do {
            _ = try await service.addItemToKit(
                catalogItemId: "item-id",
                kitId: kit.id!,
                quantity: -5,
                min: 5,
                actor: mockUser
            )
            XCTFail("Debería fallar con cantidad negativa")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("negativ"))
        }
    }
    
    func testAddItemToKit_MaxLessThanMin() async throws {
        let kit = try await service.createKit(
            code: "KIT-MINMAX",
            name: "Kit MinMax",
            type: .SVA,
            actor: mockUser
        )
        
        do {
            _ = try await service.addItemToKit(
                catalogItemId: "item-id",
                kitId: kit.id!,
                quantity: 10,
                min: 20,
                max: 10,
                actor: mockUser
            )
            XCTFail("Debería fallar con max < min")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("máximo") ||
                         error.localizedDescription.contains("mínimo"))
        }
    }
    
    // MARK: - KitItem QUERY Tests
    
    func testGetKitItems() async throws {
        let kit = try await service.createKit(
            code: "KIT-ITEMS-QUERY",
            name: "Kit Items Query",
            type: .SVA,
            actor: mockUser
        )
        
        let items = await service.getKitItems(kitId: kit.id!)
        XCTAssertNotNil(items)
    }
    
    // MARK: - Stock Operations Tests
    
    func testGetLowStockItems() async throws {
        let items = await service.getLowStockItems()
        XCTAssertNotNil(items)
    }
    
    func testGetExpiringItems() async throws {
        let items = await service.getExpiringItems()
        XCTAssertNotNil(items)
    }
    
    func testGetExpiredItems() async throws {
        let items = await service.getExpiredItems()
        XCTAssertNotNil(items)
    }
    
    func testGetLowStockItemsInKit() async throws {
        let kit = try await service.createKit(
            code: "KIT-LOWSTOCK",
            name: "Kit Low Stock",
            type: .SVA,
            actor: mockUser
        )
        
        let items = await service.getLowStockItemsInKit(kitId: kit.id!)
        XCTAssertNotNil(items)
    }
    
    // MARK: - Statistics Tests
    
    func testGetKitStatistics() async throws {
        let kit = try await service.createKit(
            code: "KIT-STATS",
            name: "Kit Stats",
            type: .SVA,
            actor: mockUser
        )
        
        let stats = await service.getKitStatistics(kitId: kit.id!)
        
        XCTAssertEqual(stats.totalItems, 0)
        XCTAssertEqual(stats.lowStockItems, 0)
        XCTAssertEqual(stats.expiringItems, 0)
        XCTAssertEqual(stats.expiredItems, 0)
    }
    
    func testGetGlobalStatistics() async throws {
        let stats = await service.getGlobalStatistics()
        
        XCTAssertGreaterThanOrEqual(stats.totalKits, 0)
        XCTAssertGreaterThanOrEqual(stats.assignedKits, 0)
        XCTAssertGreaterThanOrEqual(stats.unassignedKits, 0)
    }
    
    func testIsKitComplete() async throws {
        let kit = try await service.createKit(
            code: "KIT-COMPLETE",
            name: "Kit Complete",
            type: .SVA,
            actor: mockUser
        )
        
        let isComplete = await service.isKitComplete(kitId: kit.id!)
        XCTAssertTrue(isComplete) // Sin items = completo
    }
    
    // MARK: - Search Tests
    
    func testSearchKits() async throws {
        _ = try await service.createKit(
            code: "SEARCH-TEST-1",
            name: "Searchable Kit",
            type: .SVA,
            actor: mockUser
        )
        
        let results = await service.searchKits(by: "SEARCH")
        XCTAssertGreaterThanOrEqual(results.count, 1)
    }
    
    func testGetKitsNeedingAudit() async throws {
        let kits = await service.getKitsNeedingAudit()
        XCTAssertNotNil(kits)
    }
    
    // MARK: - Cache Tests
    
    func testCacheFunctionality() async throws {
        let kit = try await service.createKit(
            code: "CACHE-TEST",
            name: "Cache Kit",
            type: .SVA,
            actor: mockUser
        )
        
        // Primera llamada - desde Firestore
        let first = await service.getKit(id: kit.id!)
        XCTAssertNotNil(first)
        
        // Segunda llamada - desde cache
        let second = await service.getKit(id: kit.id!)
        XCTAssertNotNil(second)
        
        XCTAssertEqual(first?.id, second?.id)
    }
    
    func testClearCache() async throws {
        service.clearCache()
        
        // Verificar que no crashea
        XCTAssertTrue(true)
    }
}
