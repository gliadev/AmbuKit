//
//  ModelEncodingTests.swift
//  AmbuKitTests
//
//  Created by Adolfo on 20/12/25.
//
//  Tests para verificar que todos los modelos Firebase (FS) se pueden
//  codificar y decodificar correctamente.
//
//  NOTA: Los tests de JSONEncoder se eliminaron porque @DocumentID
//  solo puede codificarse con Firestore.Encoder (limitación de Firebase).
//

import XCTest
@testable import AmbuKit

/// Tests de validación para modelos Firebase
@MainActor
final class ModelEncodingTests: XCTestCase {
    
    // MARK: - PolicyFS Tests
    
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
    
    // MARK: - KitFS Tests
    
    /// Verifica computed properties de KitFS
    func testKitFSComputedProperties() {
        // Given: Kit asignado a vehículo
        let assignedKit = KitFS(
            code: "KIT001",
            name: "Kit Asignado",
            type: "SVA",
            status: .active,
            vehicleId: "vehicle_1"
        )
        
        // Given: Kit sin asignar
        let unassignedKit = KitFS(
            code: "KIT002",
            name: "Kit Sin Asignar",
            type: "SVB",
            status: .active,
            vehicleId: nil
        )
        
        // Then
        XCTAssertTrue(assignedKit.isAssigned)
        XCTAssertFalse(unassignedKit.isAssigned)
    }
    
    // MARK: - KitItemFS Tests
    
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
    
    // MARK: - Enum Codable Tests
    
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
