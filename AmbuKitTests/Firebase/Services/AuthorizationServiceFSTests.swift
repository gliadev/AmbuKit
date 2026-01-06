//
//  AuthorizationServiceFSTests.swift
//  AmbuKit
//
//  Created by Adolfo on 15/11/25.
//  CAMBIOS:
//  - testCanCreateKitsHelper: Logística ahora SÍ puede crear kits
//  - testCanCreateVehiclesHelper: NUEVO test para crear vehículos
//  - testLogisticsCanCreateKits: NUEVO - verifica que Logística puede crear kits
//  - testLogisticsCanCreateVehicles: NUEVO - verifica que Logística puede crear vehículos
//

import XCTest
@testable import AmbuKit

@MainActor
final class AuthorizationServiceFSTests: XCTestCase {
    
    // MARK: - Properties
    
    var programmerRoleId: String!
    var logisticsRoleId: String!
    var sanitaryRoleId: String!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        PolicyService.shared.clearCache()
        
        // Obtener IDs de roles dinámicamente
        try await fetchRoleIds()
    }
    
    override func tearDown() async throws {
        PolicyService.shared.clearCache()
        try await super.tearDown()
    }
    
    // MARK: - Setup Helpers
    
    private func fetchRoleIds() async throws {
        let roles = await PolicyService.shared.getAllRoles()
        
        programmerRoleId = roles.first(where: { $0.kind == .programmer })?.id
        logisticsRoleId = roles.first(where: { $0.kind == .logistics })?.id
        sanitaryRoleId = roles.first(where: { $0.kind == .sanitary })?.id
        
        guard programmerRoleId != nil, logisticsRoleId != nil, sanitaryRoleId != nil else {
            throw XCTSkip("No se encontraron los 3 roles en Firebase")
        }
    }
    
    // MARK: - canCreateKits Tests
    
    func testCanCreateKitsHelper() async throws {
        let programmer = createTestUser(roleId: programmerRoleId)
        let logistics = createTestUser(roleId: logisticsRoleId)
        let sanitary = createTestUser(roleId: sanitaryRoleId)
        
        let programmerCan = await AuthorizationServiceFS.canCreateKits(programmer)
        let logisticsCan = await AuthorizationServiceFS.canCreateKits(logistics)
        let sanitaryCan = await AuthorizationServiceFS.canCreateKits(sanitary)
        
        XCTAssertTrue(programmerCan, "Programmer debería poder crear kits")
        XCTAssertTrue(logisticsCan, "Logistics debería poder crear kits")
        XCTAssertFalse(sanitaryCan, "Sanitary no debería poder crear kits")
    }
    
    // MARK: - canCreateVehicles Tests
    
    func testCanCreateVehiclesHelper() async throws {
        let programmer = createTestUser(roleId: programmerRoleId)
        let logistics = createTestUser(roleId: logisticsRoleId)
        let sanitary = createTestUser(roleId: sanitaryRoleId)
        
        let programmerCan = await AuthorizationServiceFS.canCreateVehicles(programmer)
        let logisticsCan = await AuthorizationServiceFS.canCreateVehicles(logistics)
        let sanitaryCan = await AuthorizationServiceFS.canCreateVehicles(sanitary)
        
        XCTAssertTrue(programmerCan, "Programmer debería poder crear vehículos")
        XCTAssertTrue(logisticsCan, "Logistics debería poder crear vehículos")
        XCTAssertFalse(sanitaryCan, "Sanitary no debería poder crear vehículos")
    }
    
    // MARK: - Logistics Tests
    
    func testLogisticsCanCreateKits() async throws {
        let logistics = createTestUser(roleId: logisticsRoleId)
        let canCreate = await AuthorizationServiceFS.canCreateKits(logistics)
        XCTAssertTrue(canCreate, "Logística puede crear kits")
    }
    
    func testLogisticsCanCreateVehicles() async throws {
        let logistics = createTestUser(roleId: logisticsRoleId)
        let canCreate = await AuthorizationServiceFS.canCreateVehicles(logistics)
        XCTAssertTrue(canCreate, "Logística puede crear vehículos")
    }
    
    func testLogisticsCannotManageUsers() async throws {
        let logistics = createTestUser(roleId: logisticsRoleId)
        let canManage = await AuthorizationServiceFS.canManageUsers(logistics)
        XCTAssertFalse(canManage, "Logística NO puede gestionar usuarios")
    }
    
    // MARK: - Sanitary Tests
    
    func testSanitaryCannotCreateKits() async throws {
        let sanitary = createTestUser(roleId: sanitaryRoleId)
        let canCreate = await AuthorizationServiceFS.canCreateKits(sanitary)
        XCTAssertFalse(canCreate, "Sanitario NO puede crear kits")
    }
    
    func testSanitaryCannotCreateVehicles() async throws {
        let sanitary = createTestUser(roleId: sanitaryRoleId)
        let canCreate = await AuthorizationServiceFS.canCreateVehicles(sanitary)
        XCTAssertFalse(canCreate, "Sanitario NO puede crear vehículos")
    }
    
    func testSanitaryCanUpdateStock() async throws {
        let sanitary = createTestUser(roleId: sanitaryRoleId)
        let canUpdate = await AuthorizationServiceFS.canUpdateStock(sanitary)
        XCTAssertTrue(canUpdate, "Sanitario SÍ puede actualizar stock")
    }
    
    // MARK: - Programmer Tests
    
    func testProgrammerHasFullAccess() async throws {
        let programmer = createTestUser(roleId: programmerRoleId)
        
        let canCreateKits = await AuthorizationServiceFS.canCreateKits(programmer)
        let canCreateVehicles = await AuthorizationServiceFS.canCreateVehicles(programmer)
        let canEditThresholds = await AuthorizationServiceFS.canEditThresholds(programmer)
        let canManageUsers = await AuthorizationServiceFS.canManageUsers(programmer)
        let canUpdateStock = await AuthorizationServiceFS.canUpdateStock(programmer)
        
        XCTAssertTrue(canCreateKits)
        XCTAssertTrue(canCreateVehicles)
        XCTAssertTrue(canEditThresholds)
        XCTAssertTrue(canManageUsers)
        XCTAssertTrue(canUpdateStock)
    }
    
    // MARK: - UIPermissionsFS Tests
    
    func testUIPermissionsFSCompatibility() async throws {
        let logistics = createTestUser(roleId: logisticsRoleId)
        
        // Verificar helpers específicos (estos SÍ controlamos)
        let canCreateKits = await UIPermissionsFS.canCreateKits(logistics)
        let canCreateVehicles = await UIPermissionsFS.canCreateVehicles(logistics)
        let canEditThresholds = await UIPermissionsFS.canEditThresholds(logistics)
        
        XCTAssertTrue(canCreateKits, "Logistics puede crear kits")
        XCTAssertTrue(canCreateVehicles, "Logistics puede crear vehículos")
        XCTAssertTrue(canEditThresholds, "Logistics puede editar umbrales")
        
        // Permisos de usuario - solo verificamos que NO puede crear/eliminar
        let userMgmt = await UIPermissionsFS.userMgmt(logistics)
        XCTAssertFalse(userMgmt.create, "Logistics no puede crear usuarios")
        XCTAssertFalse(userMgmt.delete, "Logistics no puede eliminar usuarios")
        // read y update dependen de políticas Firebase - no verificamos
    }
    
    // MARK: - Helper Methods
    
    private func createTestUser(roleId: String) -> UserFS {
        UserFS(
            id: "test-user-\(UUID().uuidString.prefix(6))",
            uid: "firebase-uid-\(UUID().uuidString.prefix(6))",
            username: "test_user",
            fullName: "Test User",
            email: "test@ambukit.test",
            active: true,
            roleId: roleId,
            baseId: nil
        )
    }
}
