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

// MARK: - Tests Actualizados para TAREA 16.1

@MainActor
final class AuthorizationServiceFS_TAREA16_Tests: XCTestCase {
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        PolicyService.shared.clearCache()
    }
    
    override func tearDown() async throws {
        PolicyService.shared.clearCache()
        try await super.tearDown()
    }
    
    // MARK: - canCreateKits Tests (ACTUALIZADO)
    
    /// Verifica canCreateKits helper - ACTUALIZADO TAREA 16.1
    /// CAMBIO: Logística ahora SÍ puede crear kits
    func testCanCreateKitsHelper_TAREA16() async throws {
        let programmer = createTestUser(role: .programmer)
        let logistics = createTestUser(role: .logistics)
        let sanitary = createTestUser(role: .sanitary)
        
        let programmerCan = await AuthorizationServiceFS.canCreateKits(programmer)
        let logisticsCan = await AuthorizationServiceFS.canCreateKits(logistics)
        let sanitaryCan = await AuthorizationServiceFS.canCreateKits(sanitary)
        
        XCTAssertTrue(programmerCan, "Programmer debería poder crear kits")
        XCTAssertTrue(logisticsCan, "Logistics AHORA debería poder crear kits (TAREA 16.1)")  // ← CAMBIO
        XCTAssertFalse(sanitaryCan, "Sanitary no debería poder crear kits")
    }
    
    // MARK: - canCreateVehicles Tests (NUEVO)
    
    /// Verifica canCreateVehicles helper - NUEVO TAREA 16.1
    func testCanCreateVehiclesHelper_TAREA16() async throws {
        let programmer = createTestUser(role: .programmer)
        let logistics = createTestUser(role: .logistics)
        let sanitary = createTestUser(role: .sanitary)
        
        let programmerCan = await AuthorizationServiceFS.canCreateVehicles(programmer)
        let logisticsCan = await AuthorizationServiceFS.canCreateVehicles(logistics)
        let sanitaryCan = await AuthorizationServiceFS.canCreateVehicles(sanitary)
        
        XCTAssertTrue(programmerCan, "Programmer debería poder crear vehículos")
        XCTAssertTrue(logisticsCan, "Logistics debería poder crear vehículos (TAREA 16.1)")
        XCTAssertFalse(sanitaryCan, "Sanitary no debería poder crear vehículos")
    }
    
    // MARK: - Logistics Specific Tests (NUEVOS)
    
    /// Verifica que Logística SÍ puede crear kits - NUEVO TAREA 16.1
    func testLogisticsCanCreateKits_TAREA16() async throws {
        let logistics = createTestUser(role: .logistics)
        
        let canCreate = await AuthorizationServiceFS.canCreateKits(logistics)
        
        XCTAssertTrue(canCreate, "Logística AHORA puede crear kits (TAREA 16.1)")
    }
    
    /// Verifica que Logística SÍ puede crear vehículos - NUEVO TAREA 16.1
    func testLogisticsCanCreateVehicles_TAREA16() async throws {
        let logistics = createTestUser(role: .logistics)
        
        let canCreate = await AuthorizationServiceFS.canCreateVehicles(logistics)
        
        XCTAssertTrue(canCreate, "Logística puede crear vehículos (TAREA 16.1)")
    }
    
    /// Verifica que Logística sigue sin poder gestionar usuarios
    func testLogisticsCannotManageUsers_TAREA16() async throws {
        let logistics = createTestUser(role: .logistics)
        
        let canManage = await AuthorizationServiceFS.canManageUsers(logistics)
        
        XCTAssertFalse(canManage, "Logística NO debería poder gestionar usuarios")
    }
    
    // MARK: - Sanitary Tests (Sin cambios)
    
    /// Verifica que Sanitario NO puede crear kits
    func testSanitaryCannotCreateKits_TAREA16() async throws {
        let sanitary = createTestUser(role: .sanitary)
        
        let canCreate = await AuthorizationServiceFS.canCreateKits(sanitary)
        
        XCTAssertFalse(canCreate, "Sanitario NO debería poder crear kits")
    }
    
    /// Verifica que Sanitario NO puede crear vehículos
    func testSanitaryCannotCreateVehicles_TAREA16() async throws {
        let sanitary = createTestUser(role: .sanitary)
        
        let canCreate = await AuthorizationServiceFS.canCreateVehicles(sanitary)
        
        XCTAssertFalse(canCreate, "Sanitario NO debería poder crear vehículos")
    }
    
    /// Verifica que Sanitario SÍ puede actualizar stock
    func testSanitaryCanUpdateStock_TAREA16() async throws {
        let sanitary = createTestUser(role: .sanitary)
        
        let canUpdate = await AuthorizationServiceFS.canUpdateStock(sanitary)
        
        XCTAssertTrue(canUpdate, "Sanitario SÍ debería poder actualizar stock")
    }
    
    // MARK: - UIPermissionsFS Compatibility Tests (ACTUALIZADO)
    
    /// Verifica que UIPermissionsFS refleja los nuevos permisos
    func testUIPermissionsFSCompatibility_TAREA16() async throws {
        let logistics = createTestUser(role: .logistics)
        
        let canCreateKits = await UIPermissionsFS.canCreateKits(logistics)
        let canCreateVehicles = await UIPermissionsFS.canCreateVehicles(logistics)
        let canEditThresholds = await UIPermissionsFS.canEditThresholds(logistics)
        let userMgmt = await UIPermissionsFS.userMgmt(logistics)
        
        // CAMBIOS TAREA 16.1
        XCTAssertTrue(canCreateKits, "UIPermissionsFS: Logistics puede crear kits")
        XCTAssertTrue(canCreateVehicles, "UIPermissionsFS: Logistics puede crear vehículos")
        XCTAssertTrue(canEditThresholds, "UIPermissionsFS: Logistics puede editar umbrales")
        
        // Sin cambios
        XCTAssertFalse(userMgmt.create, "UIPermissionsFS: Logistics no puede crear usuarios")
        XCTAssertTrue(userMgmt.read, "UIPermissionsFS: Logistics puede leer usuarios")
        XCTAssertTrue(userMgmt.update, "UIPermissionsFS: Logistics puede actualizar usuarios")
        XCTAssertFalse(userMgmt.delete, "UIPermissionsFS: Logistics no puede eliminar usuarios")
    }
    
    // MARK: - Programmer Tests (Sin cambios - sigue teniendo todo)
    
    /// Verifica que Programador sigue teniendo acceso total
    func testProgrammerHasFullAccess_TAREA16() async throws {
        let programmer = createTestUser(role: .programmer)
        
        let canCreateKits = await AuthorizationServiceFS.canCreateKits(programmer)
        let canCreateVehicles = await AuthorizationServiceFS.canCreateVehicles(programmer)
        let canEditThresholds = await AuthorizationServiceFS.canEditThresholds(programmer)
        let canManageUsers = await AuthorizationServiceFS.canManageUsers(programmer)
        let canUpdateStock = await AuthorizationServiceFS.canUpdateStock(programmer)
        
        XCTAssertTrue(canCreateKits, "Programmer puede crear kits")
        XCTAssertTrue(canCreateVehicles, "Programmer puede crear vehículos")
        XCTAssertTrue(canEditThresholds, "Programmer puede editar umbrales")
        XCTAssertTrue(canManageUsers, "Programmer puede gestionar usuarios")
        XCTAssertTrue(canUpdateStock, "Programmer puede actualizar stock")
    }
    
    // MARK: - Helper Methods
    
    /// Crea un usuario de prueba con el rol especificado
    /// NOTA: Para tests unitarios, usamos IDs de rol conocidos
    private func createTestUser(role: RoleKind) -> UserFS {
        // Los IDs de rol deben coincidir con los del seed
        let roleId: String
        switch role {
        case .programmer:
            roleId = "role_programmer"
        case .logistics:
            roleId = "role_logistics"
        case .sanitary:
            roleId = "role_sanitary"
        }
        
        return UserFS(
            id: "test-user-\(role.rawValue)",
            uid: "firebase-uid-\(role.rawValue)",
            username: "test_\(role.rawValue)",
            fullName: "Test \(role.rawValue.capitalized)",
            email: "test.\(role.rawValue)@ambukit.test",
            active: true,
            roleId: roleId,
            baseId: nil
        )
    }
}

// MARK: - Resumen de Cambios TAREA 16.1

/*
 ┌─────────────────────────────────────────────────────────────────┐
 │                    CAMBIOS EN PERMISOS                          │
 ├─────────────────────────────────────────────────────────────────┤
 │                                                                 │
 │  ANTES (Pre-TAREA 16.1):                                       │
 │  ├─ canCreateKits:     Solo Programador                        │
 │  └─ canCreateVehicles: No existía (implícito solo Programador) │
 │                                                                 │
 │  DESPUÉS (TAREA 16.1):                                         │
 │  ├─ canCreateKits:     Programador + Logística ✅              │
 │  └─ canCreateVehicles: Programador + Logística ✅ (NUEVO)      │
 │                                                                 │
 │  SIN CAMBIOS:                                                  │
 │  ├─ canEditThresholds: Programador + Logística                 │
 │  ├─ canManageUsers:    Solo Programador                        │
 │  └─ canUpdateStock:    Todos los roles                         │
 │                                                                 │
 └─────────────────────────────────────────────────────────────────┘
 */
