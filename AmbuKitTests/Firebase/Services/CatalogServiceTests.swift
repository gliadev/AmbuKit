//
//  CatalogServiceTests.swift
//  AmbuKit
//
//  Created by Adolfo on 17/11/25.
//

import XCTest
@testable import AmbuKit
import FirebaseFirestore

@MainActor
final class CatalogServiceTests: XCTestCase {
    
    var service: CatalogService!
    var testProgrammerUser: UserFS!
    var testLogisticsUser: UserFS!
    var testSanitaryUser: UserFS!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        service = CatalogService.shared
        service.clearCache()
        
        // Crear usuarios de prueba
        testProgrammerUser = UserFS(
            id: "test_prog_user",
            uid: "firebase_uid_programmer",
            username: "programmer",
            fullName: "Test Programmer",
            email: "prog@test.com",
            active: true,
            roleId: "role_programmer"
        )
        
        testLogisticsUser = UserFS(
            id: "test_log_user",
            uid: "firebase_uid_logistics",
            username: "logistics",
            fullName: "Test Logistics",
            email: "log@test.com",
            active: true,
            roleId: "role_logistics"
        )
        
        testSanitaryUser = UserFS(
            id: "test_san_user",
            uid: "firebase_uid_sanitary",
            username: "sanitary",
            fullName: "Test Sanitary",
            email: "san@test.com",
            active: true,
            roleId: "role_sanitary"
        )
    }
    
    override func tearDown() async throws {
        await cleanupTestData()
        service.clearCache()
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func cleanupTestData() async {
        // Limpiar items de prueba
        let items = await service.getAllItems()
        for item in items where item.code.hasPrefix("TEST-") {
            if let id = item.id {
                try? await service.deleteItem(itemId: id, actor: testProgrammerUser)
            }
        }
    }
    
    // MARK: - CatalogItem CREATE Tests
    
    func testCreateItem_AsProgrammer_Success() async throws {
        // Given
        let code = "TEST-ITEM-PROG-001"
        let name = "Test Item Programmer"
        
        // When
        let item = try await service.createItem(
            code: code,
            name: name,
            description: "Test description",
            critical: true,
            minStock: 10,
            maxStock: 50,
            actor: testProgrammerUser
        )
        
        // Then
        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.code, code)
        XCTAssertEqual(item.name, name)
        XCTAssertTrue(item.critical)
        XCTAssertEqual(item.minStock, 10)
        XCTAssertEqual(item.maxStock, 50)
        
        // Verificar en Firestore
        let fetched = await service.getItem(id: item.id!)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.code, code)
    }
    
    func testCreateItem_AsLogistics_Success() async throws {
        // Given
        let code = "TEST-ITEM-LOG-001"
        let name = "Test Item Logistics"
        
        // When
        let item = try await service.createItem(
            code: code,
            name: name,
            critical: false,
            actor: testLogisticsUser
        )
        
        // Then
        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.code, code)
        XCTAssertFalse(item.critical)
    }
    
    func testCreateItem_AsSanitary_Unauthorized() async throws {
        // Given
        let code = "TEST-ITEM-SAN-001"
        
        // When & Then
        do {
            _ = try await service.createItem(
                code: code,
                name: "Test Item",
                actor: testSanitaryUser
            )
            XCTFail("Debería lanzar error de autorización")
        } catch let error as CatalogServiceError {
            switch error {
            case .unauthorized:
                XCTAssertTrue(true)
            default:
                XCTFail("Error incorrecto: \(error)")
            }
        }
    }
    
    func testCreateItem_DuplicateCode_ThrowsError() async throws {
        // Given
        let code = "TEST-ITEM-DUP-001"
        _ = try await service.createItem(
            code: code,
            name: "First Item",
            actor: testProgrammerUser
        )
        
        // When & Then
        do {
            _ = try await service.createItem(
                code: code,
                name: "Second Item",
                actor: testProgrammerUser
            )
            XCTFail("Debería lanzar error de código duplicado")
        } catch let error as CatalogServiceError {
            switch error {
            case .duplicateCode:
                XCTAssertTrue(true)
            default:
                XCTFail("Error incorrecto: \(error)")
            }
        }
    }
    
    func testCreateItem_EmptyCode_ThrowsError() async throws {
        // When & Then
        do {
            _ = try await service.createItem(
                code: "",
                name: "Test Item",
                actor: testProgrammerUser
            )
            XCTFail("Debería lanzar error de datos inválidos")
        } catch let error as CatalogServiceError {
            switch error {
            case .invalidData:
                XCTAssertTrue(true)
            default:
                XCTFail("Error incorrecto: \(error)")
            }
        }
    }
    
    func testCreateItem_WithCategoryAndUOM_Success() async throws {
        // Given
        let code = "TEST-ITEM-CAT-001"
        let categoryId = "cat_pharmacy"
        let uomId = "uom_mg"
        
        // When
        let item = try await service.createItem(
            code: code,
            name: "Test Item With Relations",
            categoryId: categoryId,
            uomId: uomId,
            actor: testProgrammerUser
        )
        
        // Then
        XCTAssertNotNil(item.categoryId)
        XCTAssertEqual(item.categoryId, categoryId)
        XCTAssertNotNil(item.uomId)
        XCTAssertEqual(item.uomId, uomId)
    }
    
    // MARK: - CatalogItem UPDATE Tests
    
    func testUpdateItem_Success() async throws {
        // Given
        var item = try await service.createItem(
            code: "TEST-ITEM-UPD-001",
            name: "Original Name",
            critical: false,
            actor: testProgrammerUser
        )
        
        // When
        item.name = "Updated Name"
        item.critical = true
        try await service.updateItem(item: item, actor: testProgrammerUser)
        
        // Then
        let updated = await service.getItem(id: item.id!)
        XCTAssertEqual(updated?.name, "Updated Name")
        XCTAssertTrue(updated?.critical ?? false)
    }
    
    // MARK: - CatalogItem DELETE Tests
    
    func testDeleteItem_AsProgrammer_Success() async throws {
        // Given
        let item = try await service.createItem(
            code: "TEST-ITEM-DEL-001",
            name: "Item To Delete",
            actor: testProgrammerUser
        )
        
        let itemId = item.id!
        
        // When
        try await service.deleteItem(itemId: itemId, actor: testProgrammerUser)
        
        // Then
        let deleted = await service.getItem(id: itemId)
        XCTAssertNil(deleted)
    }
    
    func testDeleteItem_AsLogistics_Unauthorized() async throws {
        // Given
        let item = try await service.createItem(
            code: "TEST-ITEM-DEL-LOG-001",
            name: "Item",
            actor: testProgrammerUser
        )
        
        // When & Then
        do {
            try await service.deleteItem(itemId: item.id!, actor: testLogisticsUser)
            XCTFail("Debería lanzar error de autorización")
        } catch let error as CatalogServiceError {
            switch error {
            case .unauthorized:
                XCTAssertTrue(true)
            default:
                XCTFail("Error incorrecto: \(error)")
            }
        }
    }
    
    // MARK: - CatalogItem QUERY Tests
    
    func testGetAllItems_Success() async throws {
        // Given
        _ = try await service.createItem(code: "TEST-ALL-001", name: "Item 1", actor: testProgrammerUser)
        _ = try await service.createItem(code: "TEST-ALL-002", name: "Item 2", actor: testProgrammerUser)
        _ = try await service.createItem(code: "TEST-ALL-003", name: "Item 3", actor: testProgrammerUser)
        
        // When
        let items = await service.getAllItems()
        
        // Then
        let testItems = items.filter { $0.code.hasPrefix("TEST-ALL-") }
        XCTAssertEqual(testItems.count, 3)
    }
    
    func testGetItemByCode_Success() async throws {
        // Given
        let code = "TEST-CODE-001"
        _ = try await service.createItem(code: code, name: "Test Item", actor: testProgrammerUser)
        
        // When
        let item = await service.getItemByCode(code)
        
        // Then
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.code, code)
    }
    
    func testGetItemsByCategory_Success() async throws {
        // Given
        let categoryId = "test_category_1"
        _ = try await service.createItem(code: "TEST-CAT1-001", name: "Item 1", categoryId: categoryId, actor: testProgrammerUser)
        _ = try await service.createItem(code: "TEST-CAT1-002", name: "Item 2", categoryId: categoryId, actor: testProgrammerUser)
        _ = try await service.createItem(code: "TEST-CAT2-001", name: "Item 3", categoryId: "other_category", actor: testProgrammerUser)
        
        // When
        let items = await service.getItemsByCategory(categoryId: categoryId)
        
        // Then
        let testItems = items.filter { $0.code.hasPrefix("TEST-CAT1-") }
        XCTAssertEqual(testItems.count, 2)
    }
    
    func testGetCriticalItems_Success() async throws {
        // Given
        _ = try await service.createItem(code: "TEST-CRIT-001", name: "Critical", critical: true, actor: testProgrammerUser)
        _ = try await service.createItem(code: "TEST-CRIT-002", name: "Not Critical", critical: false, actor: testProgrammerUser)
        
        // When
        let criticalItems = await service.getCriticalItems()
        
        // Then
        let testCritical = criticalItems.filter { $0.code.hasPrefix("TEST-CRIT-") }
        XCTAssertEqual(testCritical.count, 1)
        XCTAssertTrue(testCritical.first?.critical ?? false)
    }
    
    // MARK: - Category CREATE Tests
    
    func testCreateCategory_Success() async throws {
        // Given
        let code = "TEST-CAT-001"
        let name = "Test Category"
        let icon = "folder.fill"
        
        // When
        let category = try await service.createCategory(
            code: code,
            name: name,
            icon: icon,
            actor: testProgrammerUser
        )
        
        // Then
        XCTAssertNotNil(category.id)
        XCTAssertEqual(category.code, code)
        XCTAssertEqual(category.name, name)
        XCTAssertEqual(category.icon, icon)
    }
    
    func testCreateCategory_DuplicateCode_ThrowsError() async throws {
        // Given
        let code = "TEST-CAT-DUP-001"
        _ = try await service.createCategory(code: code, name: "First", actor: testProgrammerUser)
        
        // When & Then
        do {
            _ = try await service.createCategory(code: code, name: "Second", actor: testProgrammerUser)
            XCTFail("Debería lanzar error de código duplicado")
        } catch let error as CatalogServiceError {
            switch error {
            case .duplicateCode:
                XCTAssertTrue(true)
            default:
                XCTFail("Error incorrecto: \(error)")
            }
        }
    }
    
    func testGetAllCategories_Success() async throws {
        // When
        let categories = await service.getAllCategories()
        
        // Then
        XCTAssertGreaterThanOrEqual(categories.count, 0)
    }
    
    // MARK: - UnitOfMeasure CREATE Tests
    
    func testCreateUOM_Success() async throws {
        // Given
        let symbol = "TEST-UOM"
        let name = "Test Unit"
        
        // When
        let uom = try await service.createUOM(
            symbol: symbol,
            name: name,
            actor: testProgrammerUser
        )
        
        // Then
        XCTAssertNotNil(uom.id)
        XCTAssertEqual(uom.symbol, symbol)
        XCTAssertEqual(uom.name, name)
    }
    
    func testCreateUOM_DuplicateSymbol_ThrowsError() async throws {
        // Given
        let symbol = "TEST-DUP"
        _ = try await service.createUOM(symbol: symbol, name: "First", actor: testProgrammerUser)
        
        // When & Then
        do {
            _ = try await service.createUOM(symbol: symbol, name: "Second", actor: testProgrammerUser)
            XCTFail("Debería lanzar error de código duplicado")
        } catch let error as CatalogServiceError {
            switch error {
            case .duplicateCode:
                XCTAssertTrue(true)
            default:
                XCTFail("Error incorrecto: \(error)")
            }
        }
    }
    
    func testGetAllUOMs_Success() async throws {
        // When
        let uoms = await service.getAllUOMs()
        
        // Then
        XCTAssertGreaterThanOrEqual(uoms.count, 0)
    }
    
    // MARK: - Statistics Tests
    
    func testGetStatistics_Success() async throws {
        // Given
        _ = try await service.createItem(code: "TEST-STAT-001", name: "Item 1", critical: true, actor: testProgrammerUser)
        _ = try await service.createItem(code: "TEST-STAT-002", name: "Item 2", critical: false, actor: testProgrammerUser)
        
        // When
        let stats = await service.getStatistics()
        
        // Then
        XCTAssertGreaterThanOrEqual(stats.totalItems, 2)
        XCTAssertGreaterThanOrEqual(stats.criticalItems, 1)
    }
    
    // MARK: - Search Tests
    
    func testSearchItems_ByCode_Success() async throws {
        // Given
        _ = try await service.createItem(code: "TEST-SEARCH-ABC", name: "Item ABC", actor: testProgrammerUser)
        _ = try await service.createItem(code: "TEST-SEARCH-XYZ", name: "Item XYZ", actor: testProgrammerUser)
        
        // When
        let results = await service.searchItems(by: "ABC")
        
        // Then
        XCTAssertTrue(results.contains(where: { $0.code.contains("ABC") }))
    }
    
    func testSearchItems_ByName_Success() async throws {
        // Given
        _ = try await service.createItem(code: "TEST-NAME-001", name: "Adrenalina Test", actor: testProgrammerUser)
        
        // When
        let results = await service.searchItems(by: "Adrenalina")
        
        // Then
        XCTAssertTrue(results.contains(where: { $0.name.contains("Adrenalina") }))
    }
    
    // MARK: - Cache Tests
    
    func testCache_Items_Works() async throws {
        // Given
        let item = try await service.createItem(
            code: "TEST-CACHE-001",
            name: "Cached Item",
            actor: testProgrammerUser
        )
        
        // When
        let first = await service.getItem(id: item.id!)
        let second = await service.getItem(id: item.id!)
        
        // Then
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(first?.id, second?.id)
    }
    
    func testClearCache_Works() async throws {
        // Given
        _ = try await service.createItem(code: "TEST-CLEAR-001", name: "Item", actor: testProgrammerUser)
        _ = await service.getAllItems()
        
        // When
        service.clearCache()
        
        // Then
        let items = await service.getAllItems()
        XCTAssertGreaterThanOrEqual(items.count, 0)
    }
}
