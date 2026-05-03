//
//  ModelEncodingTests.swift
//  AmbuKitTests
//
//  Tests para verificar que todos los modelos Firebase (FS) se pueden
//  codificar y decodificar correctamente.
//

import Testing
@testable import AmbuKit
import Foundation

@MainActor
@Suite(.tags(.unit))
struct ModelEncodingTests {

    // MARK: - PolicyFS Tests

    @Test("PolicyFS computed properties")
    func policyFSComputedProperties() {
        let fullAccess = PolicyFS(
            entity: .kit,
            canCreate: true,
            canRead: true,
            canUpdate: true,
            canDelete: true,
            roleId: "test"
        )

        let readOnly = PolicyFS(
            entity: .user,
            canCreate: false,
            canRead: true,
            canUpdate: false,
            canDelete: false,
            roleId: "test"
        )

        #expect(fullAccess.hasFullAccess)
        #expect(!fullAccess.isReadOnly)

        #expect(!readOnly.hasFullAccess)
        #expect(readOnly.isReadOnly)

        #expect(fullAccess.hasPermission(for: .create))
        #expect(fullAccess.hasPermission(for: .delete))
        #expect(!readOnly.hasPermission(for: .create))
        #expect(readOnly.hasPermission(for: .read))
    }

    // MARK: - KitFS Tests

    @Test("KitFS computed properties")
    func kitFSComputedProperties() {
        let assignedKit = KitFS(
            code: "KIT001",
            name: "Kit Asignado",
            type: "SVA",
            status: .active,
            vehicleId: "vehicle_1"
        )

        let unassignedKit = KitFS(
            code: "KIT002",
            name: "Kit Sin Asignar",
            type: "SVB",
            status: .active,
            vehicleId: nil
        )

        #expect(assignedKit.isAssigned)
        #expect(!unassignedKit.isAssigned)
    }

    // MARK: - KitItemFS Tests

    @Test("KitItemFS stock status")
    func kitItemFSStockStatus() {
        let okItem = KitItemFS(quantity: 20, min: 10, max: 50)
        let lowItem = KitItemFS(quantity: 3, min: 10, max: 50)
        let highItem = KitItemFS(quantity: 60, min: 10, max: 50)

        #expect(okItem.stockStatus == .ok)
        #expect(!okItem.isBelowMinimum)
        #expect(!okItem.isAboveMaximum)

        #expect(lowItem.stockStatus == .low)
        #expect(lowItem.isBelowMinimum)

        #expect(highItem.stockStatus == .high)
        #expect(highItem.isAboveMaximum)
    }

    @Test("KitItemFS expiry logic")
    func kitItemFSExpiryLogic() {
        let expiredItem = KitItemFS(
            quantity: 10,
            min: 5,
            expiry: Date().addingTimeInterval(-86400)
        )

        let expiringItem = KitItemFS(
            quantity: 10,
            min: 5,
            expiry: Date().addingTimeInterval(86400 * 15)
        )

        let noExpiryItem = KitItemFS(
            quantity: 10,
            min: 5,
            expiry: nil
        )

        #expect(expiredItem.isExpired)
        #expect(!expiredItem.isExpiringSoon)

        #expect(!expiringItem.isExpired)
        #expect(expiringItem.isExpiringSoon)

        #expect(!noExpiryItem.isExpired)
        #expect(!noExpiryItem.isExpiringSoon)
        #expect(!noExpiryItem.hasExpiry)
    }

    // MARK: - Enum Codable Tests (parametrized)

    @Test("RoleKind Codable", arguments: RoleKind.allCases)
    func roleKindCodable(_ kind: RoleKind) throws {
        let encoded = try JSONEncoder().encode(kind)
        let decoded = try JSONDecoder().decode(RoleKind.self, from: encoded)
        #expect(kind == decoded)
    }

    @Test("EntityKind Codable", arguments: EntityKind.allCases)
    func entityKindCodable(_ entity: EntityKind) throws {
        let encoded = try JSONEncoder().encode(entity)
        let decoded = try JSONDecoder().decode(EntityKind.self, from: encoded)
        #expect(entity == decoded)
    }

    @Test("ActionKind Codable", arguments: ActionKind.allCases)
    func actionKindCodable(_ action: ActionKind) throws {
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(ActionKind.self, from: encoded)
        #expect(action == decoded)
    }

    @Test("KitType Codable", arguments: KitType.allCases)
    func kitTypeCodable(_ kitType: KitType) throws {
        let encoded = try JSONEncoder().encode(kitType)
        let decoded = try JSONDecoder().decode(KitType.self, from: encoded)
        #expect(kitType == decoded)
    }

    // MARK: - Collection Name Tests

    @Test("Modelos tienen collectionName definido")
    func allModelsHaveCollectionName() {
        #expect(!UserFS.collectionName.isEmpty)
        #expect(!RoleFS.collectionName.isEmpty)
        #expect(!PolicyFS.collectionName.isEmpty)
        #expect(!BaseFS.collectionName.isEmpty)
        #expect(!VehicleFS.collectionName.isEmpty)
        #expect(!KitFS.collectionName.isEmpty)
        #expect(!KitItemFS.collectionName.isEmpty)
        #expect(!CatalogItemFS.collectionName.isEmpty)

        #expect(UserFS.collectionName == "users")
        #expect(RoleFS.collectionName == "roles")
        #expect(PolicyFS.collectionName == "policies")
        #expect(BaseFS.collectionName == "bases")
        #expect(VehicleFS.collectionName == "vehicles")
        #expect(KitFS.collectionName == "kits")
        #expect(KitItemFS.collectionName == "kitItems")
        #expect(CatalogItemFS.collectionName == "catalogItems")
    }
}
