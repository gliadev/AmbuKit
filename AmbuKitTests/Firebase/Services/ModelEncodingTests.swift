//
//  ModelEncodingTests.swift
//  AmbuKitTests
//
//  Created by Adolfo on 20/12/25.
//
//  Tests para verificar que todos los modelos Firebase (FS) se pueden
//  codificar y decodificar correctamente.
//
//  Estos tests son 100% seguros - NO tocan Firebase, solo validan modelos.
//

import XCTest
import FirebaseFirestore
@testable import AmbuKit

/// Tests de codificación/decodificación para modelos Firebase
/// Verifica que todos los modelos conforman Codable correctamente
@MainActor
final class ModelEncodingTests: XCTestCase {
    
    // MARK: - UserFS Tests
    
    /// Verifica codificación/decodificación de UserFS
    func testUserFSEncodingDecoding() throws {
        // Given
        let user = UserFS(
            uid: "test_uid_123",
            username: "testuser",
            fullName: "Test User Full Name",
            email: "test@example.com",
            active: true,
            roleId: "role_test",
            baseId: "base_test"
        )
        
        // When: Codificar a JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(user)
        
        // Then: Decodificar
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserFS.self, from: data)
        
        XCTAssertEqual(user.uid, decoded.uid)
        XCTAssertEqual(user.username, decoded.username)
        XCTAssertEqual(user.fullName, decoded.fullName)
        XCTAssertEqual(user.email, decoded.email)
        XCTAssertEqual(user.active, decoded.active)
        XCTAssertEqual(user.roleId, decoded.roleId)
        XCTAssertEqual(user.baseId, decoded.baseId)
    }
    
    /// Verifica que UserFS maneja valores opcionales correctamente
    func testUserFSWithOptionalValues() throws {
        // Given: Usuario sin base ni rol
        let user = UserFS(
            uid: "test_uid",
            username: "minimal",
            fullName: "Minimal User",
            email: "minimal@test.com",
            active: false,
            roleId: nil,
            baseId: nil
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(user)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserFS.self, from: data)
        
        // Then
        XCTAssertNil(decoded.roleId)
        XCTAssertNil(decoded.baseId)
        XCTAssertFalse(decoded.active)
    }
    
    // MARK: - RoleFS Tests
    
    /// Verifica codificación/decodificación de RoleFS
    func testRoleFSEncodingDecoding() throws {
        // Given
        let role = RoleFS(
            kind: .programmer,
            displayName: "Programador"
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(role)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RoleFS.self, from: data)
        
        // Then
        XCTAssertEqual(role.kind, decoded.kind)
        XCTAssertEqual(role.displayName, decoded.displayName)
    }
    
    /// Verifica todos los tipos de RoleKind
    func testAllRoleKindsEncodingDecoding() throws {
        let kinds: [RoleKind] = [.programmer, .logistics, .sanitary]
        
        for kind in kinds {
            let role = RoleFS(kind: kind, displayName: "Test \(kind.rawValue)")
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(role)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(RoleFS.self, from: data)
            
            XCTAssertEqual(kind, decoded.kind, "Fallo en RoleKind: \(kind)")
        }
    }
    
    // MARK: - PolicyFS Tests
    
    /// Verifica codificación/decodificación de PolicyFS
    func testPolicyFSEncodingDecoding() throws {
        // Given
        let policy = PolicyFS(
            entity: .kit,
            canCreate: true,
            canRead: true,
            canUpdate: false,
            canDelete: false,
            roleId: "role_test"
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(policy)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PolicyFS.self, from: data)
        
        // Then
        XCTAssertEqual(policy.entity, decoded.entity)
        XCTAssertEqual(policy.canCreate, decoded.canCreate)
        XCTAssertEqual(policy.canRead, decoded.canRead)
        XCTAssertEqual(policy.canUpdate, decoded.canUpdate)
        XCTAssertEqual(policy.canDelete, decoded.canDelete)
        XCTAssertEqual(policy.roleId, decoded.roleId)
    }
    
    /// Verifica computed properties de PolicyFS
    func testPolicyFSComputedProperties() {
        // Given: Policy con acceso completo
        let fullAccess = PolicyFS(
            entity: .kit,
            canCreate: true,
            canRead: true,
            canUpdate: true,
            canDelete: true,
            roleId: "test"
        )
        
        // Given: Policy de solo lectura
        let readOnly = PolicyFS(
            entity: .user,
            canCreate: false,
            canRead: true,
            canUpdate: false,
            canDelete: false,
            roleId: "test"
        )
        
        // Then
        XCTAssertTrue(fullAccess.hasFullAccess)
        XCTAssertFalse(fullAccess.isReadOnly)
        
        XCTAssertFalse(readOnly.hasFullAccess)
        XCTAssertTrue(readOnly.isReadOnly)
        
        // Verificar hasPermission
        XCTAssertTrue(fullAccess.hasPermission(for: .create))
        XCTAssertTrue(fullAccess.hasPermission(for: .delete))
        XCTAssertFalse(readOnly.hasPermission(for: .create))
        XCTAssertTrue(readOnly.hasPermission(for: .read))
    }
    
    // MARK: - BaseFS Tests
    
    /// Verifica codificación/decodificación de BaseFS
    func testBaseFSEncodingDecoding() throws {
        // Given
        let base = BaseFS(
            code: "TEST001",
            name: "Test Base",
            address: "123 Test Street",
            active: true,
            vehicleIds: ["v1", "v2"]
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(base)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BaseFS.self, from: data)
        
        // Then
        XCTAssertEqual(base.code, decoded.code)
        XCTAssertEqual(base.name, decoded.name)
        XCTAssertEqual(base.address, decoded.address)
        XCTAssertEqual(base.active, decoded.active)
        XCTAssertEqual(base.vehicleIds, decoded.vehicleIds)
    }
    
    // MARK: - VehicleFS Tests
    
    /// Verifica codificación/decodificación de VehicleFS
    func testVehicleFSEncodingDecoding() throws {
        // Given
        let vehicle = VehicleFS(
            code: "AMB001",
            plate: "1234ABC",
            type: .sva,
            baseId: "base_1",
            kitIds: ["kit1", "kit2"]
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(vehicle)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VehicleFS.self, from: data)
        
        // Then
        XCTAssertEqual(vehicle.code, decoded.code)
        XCTAssertEqual(vehicle.plate, decoded.plate)
        XCTAssertEqual(vehicle.vehicleType, decoded.vehicleType)
        XCTAssertEqual(vehicle.baseId, decoded.baseId)
        XCTAssertEqual(vehicle.kitIds, decoded.kitIds)
    }
    
    /// Verifica todos los tipos de vehículo
    func testAllVehicleTypesEncodingDecoding() throws {
        let types: [VehicleFS.VehicleType] = [.svb, .sva, .svae, .tsnu, .vir, .helicopter]
        
        for vehicleType in types {
            let vehicle = VehicleFS(
                code: "TEST",
                plate: nil,
                type: vehicleType,
                baseId: nil,
                kitIds: []
            )
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(vehicle)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(VehicleFS.self, from: data)
            
            XCTAssertEqual(vehicleType, decoded.vehicleType, "Fallo en VehicleType: \(vehicleType)")
        }
    }
    
    // MARK: - KitFS Tests
    
    /// Verifica codificación/decodificación de KitFS
    func testKitFSEncodingDecoding() throws {
        // Given
        let kit = KitFS(
            code: "KIT-TEST",
            name: "Test Kit",
            type: "SVA",
            status: .active,
            lastAudit: Date(),
            vehicleId: "vehicle_1",
            itemIds: ["item1", "item2"]
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(kit)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(KitFS.self, from: data)
        
        // Then
        XCTAssertEqual(kit.code, decoded.code)
        XCTAssertEqual(kit.name, decoded.name)
        XCTAssertEqual(kit.type, decoded.type)
        XCTAssertEqual(kit.status, decoded.status)
        XCTAssertEqual(kit.vehicleId, decoded.vehicleId)
        XCTAssertEqual(kit.itemIds, decoded.itemIds)
    }
    
    /// Verifica computed properties de KitFS
    func testKitFSComputedProperties() {
        // Given: Kit asignado
        let assignedKit = KitFS(
            code: "K001",
            name: "Assigned",
            type: "SVA",
            vehicleId: "vehicle_1"
        )
        
        // Given: Kit sin asignar
        let unassignedKit = KitFS(
            code: "K002",
            name: "Unassigned",
            type: "SVB",
            vehicleId: nil
        )
        
        // Then
        XCTAssertTrue(assignedKit.isAssigned)
        XCTAssertFalse(unassignedKit.isAssigned)
    }
    
    /// Verifica todos los estados de kit
    func testAllKitStatusesEncodingDecoding() throws {
        let statuses: [KitFS.Status] = [.active, .inactive, .maintenance, .expired]
        
        for status in statuses {
            let kit = KitFS(
                code: "TEST",
                name: "Test",
                type: "SVA",
                status: status
            )
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(kit)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(KitFS.self, from: data)
            
            XCTAssertEqual(status, decoded.status, "Fallo en KitFS.Status: \(status)")
        }
    }
    
    // MARK: - KitItemFS Tests
    
    /// Verifica codificación/decodificación de KitItemFS
    func testKitItemFSEncodingDecoding() throws {
        // Given
        let item = KitItemFS(
            quantity: 10,
            min: 5,
            max: 50,
            expiry: Date().addingTimeInterval(86400 * 180), // 6 meses
            lot: "LOT123456",
            notes: "Test notes",
            catalogItemId: "cat_1",
            kitId: "kit_1"
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(item)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(KitItemFS.self, from: data)
        
        // Then
        XCTAssertEqual(item.quantity, decoded.quantity)
        XCTAssertEqual(item.min, decoded.min)
        XCTAssertEqual(item.max, decoded.max)
        XCTAssertEqual(item.lot, decoded.lot)
        XCTAssertEqual(item.notes, decoded.notes)
        XCTAssertEqual(item.catalogItemId, decoded.catalogItemId)
        XCTAssertEqual(item.kitId, decoded.kitId)
    }
    
    /// Verifica computed properties de KitItemFS
    func testKitItemFSStockStatus() {
        // Given: Stock OK
        let okItem = KitItemFS(quantity: 20, min: 10, max: 50)
        
        // Given: Stock bajo
        let lowItem = KitItemFS(quantity: 3, min: 10, max: 50)
        
        // Given: Stock alto
        let highItem = KitItemFS(quantity: 60, min: 10, max: 50)
        
        // Then
        XCTAssertEqual(okItem.stockStatus, .ok)
        XCTAssertFalse(okItem.isBelowMinimum)
        XCTAssertFalse(okItem.isAboveMaximum)
        
        XCTAssertEqual(lowItem.stockStatus, .low)
        XCTAssertTrue(lowItem.isBelowMinimum)
        
        XCTAssertEqual(highItem.stockStatus, .high)
        XCTAssertTrue(highItem.isAboveMaximum)
    }
    
    /// Verifica lógica de caducidad de KitItemFS
    func testKitItemFSExpiryLogic() {
        // Given: Item caducado
        let expiredItem = KitItemFS(
            quantity: 10,
            min: 5,
            expiry: Date().addingTimeInterval(-86400) // Ayer
        )
        
        // Given: Item próximo a caducar
        let expiringItem = KitItemFS(
            quantity: 10,
            min: 5,
            expiry: Date().addingTimeInterval(86400 * 15) // 15 días
        )
        
        // Given: Item sin caducidad
        let noExpiryItem = KitItemFS(
            quantity: 10,
            min: 5,
            expiry: nil
        )
        
        // Then
        XCTAssertTrue(expiredItem.isExpired)
        XCTAssertFalse(expiredItem.isExpiringSoon)
        
        XCTAssertFalse(expiringItem.isExpired)
        XCTAssertTrue(expiringItem.isExpiringSoon)
        
        XCTAssertFalse(noExpiryItem.isExpired)
        XCTAssertFalse(noExpiryItem.isExpiringSoon)
        XCTAssertFalse(noExpiryItem.hasExpiry)
    }
    
    // MARK: - CatalogItemFS Tests
    
    /// Verifica codificación/decodificación de CatalogItemFS
    func testCatalogItemFSEncodingDecoding() throws {
        // Given
        let item = CatalogItemFS(
            code: "ADRE1MG",
            name: "Adrenalina 1mg",
            description: "Ampolla de adrenalina",
            critical: true,
            minStock: 10,
            maxStock: 50,
            categoryId: "cat_pharmacy",
            uomId: "uom_unit"
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(item)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CatalogItemFS.self, from: data)
        
        // Then
        XCTAssertEqual(item.code, decoded.code)
        XCTAssertEqual(item.name, decoded.name)
        XCTAssertEqual(item.critical, decoded.critical)
        XCTAssertEqual(item.minStock, decoded.minStock)
        XCTAssertEqual(item.maxStock, decoded.maxStock)
    }
    
    // MARK: - Enum Tests
    
    /// Verifica codificación de RoleKind
    func testRoleKindCodable() throws {
        let kinds: [RoleKind] = [.programmer, .logistics, .sanitary]
        
        for kind in kinds {
            let encoded = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(RoleKind.self, from: encoded)
            XCTAssertEqual(kind, decoded, "Fallo en RoleKind: \(kind)")
        }
    }
    
    /// Verifica codificación de EntityKind
    func testEntityKindCodable() throws {
        for entity in EntityKind.allCases {
            let encoded = try JSONEncoder().encode(entity)
            let decoded = try JSONDecoder().decode(EntityKind.self, from: encoded)
            XCTAssertEqual(entity, decoded, "Fallo en EntityKind: \(entity)")
        }
    }
    
    /// Verifica codificación de ActionKind
    func testActionKindCodable() throws {
        for action in ActionKind.allCases {
            let encoded = try JSONEncoder().encode(action)
            let decoded = try JSONDecoder().decode(ActionKind.self, from: encoded)
            XCTAssertEqual(action, decoded, "Fallo en ActionKind: \(action)")
        }
    }
    
    /// Verifica codificación de KitType
    func testKitTypeCodable() throws {
        for kitType in KitType.allCases {
            let encoded = try JSONEncoder().encode(kitType)
            let decoded = try JSONDecoder().decode(KitType.self, from: encoded)
            XCTAssertEqual(kitType, decoded, "Fallo en KitType: \(kitType)")
        }
    }
    
    // MARK: - Sendable Conformance Tests
    
    /// Verifica que todos los modelos conforman Sendable
    /// Si este test compila, los modelos son Sendable
    func testAllModelsSendable() {
        func checkSendable<T: Sendable>(_: T.Type) {}
        
        // Auth models
        checkSendable(UserFS.self)
        checkSendable(RoleFS.self)
        checkSendable(PolicyFS.self)
        
        // Inventory models
        checkSendable(BaseFS.self)
        checkSendable(VehicleFS.self)
        checkSendable(KitFS.self)
        
        // Enums
        checkSendable(RoleKind.self)
        checkSendable(EntityKind.self)
        checkSendable(ActionKind.self)
        checkSendable(KitType.self)
        
        // Si llegamos aquí sin error de compilación, todos son Sendable ✅
        XCTAssertTrue(true, "Todos los modelos conforman Sendable")
    }
    
    // MARK: - Collection Name Tests
    
    /// Verifica que todos los modelos tienen collectionName definido
    func testAllModelsHaveCollectionName() {
        XCTAssertFalse(UserFS.collectionName.isEmpty)
        XCTAssertFalse(RoleFS.collectionName.isEmpty)
        XCTAssertFalse(PolicyFS.collectionName.isEmpty)
        XCTAssertFalse(BaseFS.collectionName.isEmpty)
        XCTAssertFalse(VehicleFS.collectionName.isEmpty)
        XCTAssertFalse(KitFS.collectionName.isEmpty)
        XCTAssertFalse(KitItemFS.collectionName.isEmpty)
        XCTAssertFalse(CatalogItemFS.collectionName.isEmpty)
        
        // Verificar nombres esperados
        XCTAssertEqual(UserFS.collectionName, "users")
        XCTAssertEqual(RoleFS.collectionName, "roles")
        XCTAssertEqual(PolicyFS.collectionName, "policies")
        XCTAssertEqual(BaseFS.collectionName, "bases")
        XCTAssertEqual(VehicleFS.collectionName, "vehicles")
        XCTAssertEqual(KitFS.collectionName, "kits")
        XCTAssertEqual(KitItemFS.collectionName, "kitItems")
        XCTAssertEqual(CatalogItemFS.collectionName, "catalogItems")
    }
}
