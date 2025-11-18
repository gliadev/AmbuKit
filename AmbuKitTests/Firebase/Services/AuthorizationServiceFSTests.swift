//
//  AuthorizationServiceFSTests.swift
//  AmbuKit
//
//  Created by Adolfo on 15/11/25.
//

import XCTest
@testable import AmbuKit

/// Tests para verificar que AuthorizationServiceFS funciona correctamente
/// Estos tests verifican que la lógica de permisos sea idéntica a AuthorizationService
@MainActor
final class AuthorizationServiceFSTests: XCTestCase {
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Limpiar caché antes de cada test
        PolicyService.shared.clearCache()
    }
    
    override func tearDown() async throws {
        // Limpiar caché después de cada test
        PolicyService.shared.clearCache()
        
        try await super.tearDown()
    }
    
    // MARK: - Programmer Tests
    
    /// Verifica que Programador tiene acceso TOTAL a todo
    func testProgrammerHasFullAccess() async throws {
        // Given: Un usuario con rol Programador
        let programmer = try await createTestUser(role: .programmer)
        
        // When/Then: Debe tener todos los permisos en todas las entidades
        for entity in EntityKind.allCases {
            for action in ActionKind.allCases {
                let hasPermission = await AuthorizationServiceFS.allowed(
                    action,
                    on: entity,
                    for: programmer
                )
                
                XCTAssertTrue(
                    hasPermission,
                    "Programador debería tener permiso \(action) en \(entity)"
                )
            }
        }
    }
    
    /// Verifica helper isProgrammer
    func testIsProgrammerHelper() async throws {
        let programmer = try await createTestUser(role: .programmer)
        let logistics = try await createTestUser(role: .logistics)
        
        let isProgrammer = await AuthorizationServiceFS.isProgrammer(programmer)
        let isLogisticsProgrammer = await AuthorizationServiceFS.isProgrammer(logistics)
        
        XCTAssertTrue(isProgrammer, "Programmer debería ser detectado como programador")
        XCTAssertFalse(isLogisticsProgrammer, "Logistics no debería ser detectado como programador")
    }
    
    // MARK: - Logistics Tests
    
    /// Verifica que Logística NO puede crear kits
    func testLogisticsCannotCreateKits() async throws {
        // Given: Un usuario con rol Logística
        let logistics = try await createTestUser(role: .logistics)
        
        // When: Intenta crear un kit
        let canCreate = await AuthorizationServiceFS.allowed(
            .create,
            on: .kit,
            for: logistics
        )
        
        // Then: No debería poder
        XCTAssertFalse(canCreate, "Logística NO debería poder crear kits")
    }
    
    /// Verifica que Logística SÍ puede actualizar kits
    func testLogisticsCanUpdateKits() async throws {
        let logistics = try await createTestUser(role: .logistics)
        
        let canUpdate = await AuthorizationServiceFS.allowed(
            .update,
            on: .kit,
            for: logistics
        )
        
        XCTAssertTrue(canUpdate, "Logística SÍ debería poder actualizar kits")
    }
    
    /// Verifica que Logística NO puede crear usuarios
    func testLogisticsCannotCreateUsers() async throws {
        let logistics = try await createTestUser(role: .logistics)
        
        let canCreate = await AuthorizationServiceFS.allowed(
            .create,
            on: .user,
            for: logistics
        )
        
        XCTAssertFalse(canCreate, "Logística NO debería poder crear usuarios")
    }
    
    /// Verifica que Logística NO puede eliminar usuarios
    func testLogisticsCannotDeleteUsers() async throws {
        let logistics = try await createTestUser(role: .logistics)
        
        let canDelete = await AuthorizationServiceFS.allowed(
            .delete,
            on: .user,
            for: logistics
        )
        
        XCTAssertFalse(canDelete, "Logística NO debería poder eliminar usuarios")
    }
    
    /// Verifica que Logística SÍ puede actualizar usuarios
    func testLogisticsCanUpdateUsers() async throws {
        let logistics = try await createTestUser(role: .logistics)
        
        let canUpdate = await AuthorizationServiceFS.allowed(
            .update,
            on: .user,
            for: logistics
        )
        
        XCTAssertTrue(canUpdate, "Logística SÍ debería poder actualizar usuarios")
    }
    
    /// Verifica que Logística puede gestionar KitItems
    func testLogisticsCanManageKitItems() async throws {
        let logistics = try await createTestUser(role: .logistics)
        
        // Debería poder crear, leer, actualizar y eliminar KitItems
        let canCreate = await AuthorizationServiceFS.canCreate(.kitItem, user: logistics)
        let canRead = await AuthorizationServiceFS.canRead(.kitItem, user: logistics)
        let canUpdate = await AuthorizationServiceFS.canUpdate(.kitItem, user: logistics)
        let canDelete = await AuthorizationServiceFS.canDelete(.kitItem, user: logistics)
        
        XCTAssertTrue(canCreate)
        XCTAssertTrue(canRead)
        XCTAssertTrue(canUpdate)
        XCTAssertTrue(canDelete)
    }
    
    /// Verifica helper canEditThresholds para Logística
    func testLogisticsCanEditThresholds() async throws {
        let logistics = try await createTestUser(role: .logistics)
        
        let canEdit = await AuthorizationServiceFS.canEditThresholds(logistics)
        
        XCTAssertTrue(canEdit, "Logística debería poder editar umbrales")
    }
    
    // MARK: - Sanitary Tests
    
    /// Verifica que Sanitario solo tiene lectura en kits
    func testSanitaryReadOnlyKits() async throws {
        let sanitary = try await createTestUser(role: .sanitary)
        
        let canRead = await AuthorizationServiceFS.canRead(.kit, user: sanitary)
        let canCreate = await AuthorizationServiceFS.canCreate(.kit, user: sanitary)
        let canUpdate = await AuthorizationServiceFS.canUpdate(.kit, user: sanitary)
        let canDelete = await AuthorizationServiceFS.canDelete(.kit, user: sanitary)
        
        XCTAssertTrue(canRead, "Sanitario debería poder LEER kits")
        XCTAssertFalse(canCreate, "Sanitario NO debería poder CREAR kits")
        XCTAssertFalse(canUpdate, "Sanitario NO debería poder ACTUALIZAR kits")
        XCTAssertFalse(canDelete, "Sanitario NO debería poder ELIMINAR kits")
    }
    
    /// Verifica que Sanitario SÍ puede actualizar stock (KitItem)
    func testSanitaryCanUpdateStock() async throws {
        let sanitary = try await createTestUser(role: .sanitary)
        
        let canUpdate = await AuthorizationServiceFS.allowed(
            .update,
            on: .kitItem,
            for: sanitary
        )
        
        XCTAssertTrue(canUpdate, "Sanitario SÍ debería poder actualizar stock")
    }
    
    /// Verifica que Sanitario NO puede crear KitItems
    func testSanitaryCannotCreateKitItems() async throws {
        let sanitary = try await createTestUser(role: .sanitary)
        
        let canCreate = await AuthorizationServiceFS.canCreate(.kitItem, user: sanitary)
        
        XCTAssertFalse(canCreate, "Sanitario NO debería poder crear KitItems")
    }
    
    /// Verifica que Sanitario NO puede eliminar KitItems
    func testSanitaryCannotDeleteKitItems() async throws {
        let sanitary = try await createTestUser(role: .sanitary)
        
        let canDelete = await AuthorizationServiceFS.canDelete(.kitItem, user: sanitary)
        
        XCTAssertFalse(canDelete, "Sanitario NO debería poder eliminar KitItems")
    }
    
    /// Verifica que Sanitario NO tiene acceso a usuarios
    func testSanitaryCannotAccessUsers() async throws {
        let sanitary = try await createTestUser(role: .sanitary)
        
        let permissions = await AuthorizationServiceFS.permissions(for: .user, user: sanitary)
        
        XCTAssertFalse(permissions.canCreate)
        XCTAssertFalse(permissions.canRead)
        XCTAssertFalse(permissions.canUpdate)
        XCTAssertFalse(permissions.canDelete)
    }
    
    /// Verifica que Sanitario NO puede editar umbrales
    func testSanitaryCannotEditThresholds() async throws {
        let sanitary = try await createTestUser(role: .sanitary)
        
        let canEdit = await AuthorizationServiceFS.canEditThresholds(sanitary)
        
        XCTAssertFalse(canEdit, "Sanitario NO debería poder editar umbrales")
    }
    
    // MARK: - Edge Cases
    
    /// Verifica que usuario nil no tiene permisos
    func testNilUserHasNoPermissions() async {
        let hasPermission = await AuthorizationServiceFS.allowed(
            .read,
            on: .kit,
            for: nil
        )
        
        XCTAssertFalse(hasPermission, "Usuario nil no debería tener permisos")
    }
    
    /// Verifica que usuario sin rol no tiene permisos
    func testUserWithoutRoleHasNoPermissions() async {
        var user = UserFS(
            uid: "test-uid",
            username: "test",
            fullName: "Test User",
            email: "test@test.com"
        )
        user.roleId = nil // Sin rol
        
        let hasPermission = await AuthorizationServiceFS.allowed(
            .read,
            on: .kit,
            for: user
        )
        
        XCTAssertFalse(hasPermission, "Usuario sin rol no debería tener permisos")
    }
    
    /// Verifica que usuario con rol inválido no tiene permisos
    func testUserWithInvalidRoleHasNoPermissions() async {
        var user = UserFS(
            uid: "test-uid",
            username: "test",
            fullName: "Test User",
            email: "test@test.com"
        )
        user.roleId = "invalid-role-id"
        
        let hasPermission = await AuthorizationServiceFS.allowed(
            .read,
            on: .kit,
            for: user
        )
        
        XCTAssertFalse(hasPermission, "Usuario con rol inválido no debería tener permisos")
    }
    
    // MARK: - Batch Permission Tests
    
    /// Verifica el método permissions() para obtener todos los permisos
    func testBatchPermissionsMethod() async throws {
        let logistics = try await createTestUser(role: .logistics)
        
        let permissions = await AuthorizationServiceFS.permissions(
            for: .kit,
            user: logistics
        )
        
        XCTAssertFalse(permissions.canCreate, "Logística no puede crear kits")
        XCTAssertTrue(permissions.canRead, "Logística puede leer kits")
        XCTAssertTrue(permissions.canUpdate, "Logística puede actualizar kits")
        XCTAssertTrue(permissions.canDelete, "Logística puede eliminar kits")
    }
    
    // MARK: - Cache Tests
    
    /// Verifica que el caché funciona (segunda llamada más rápida)
    func testCacheImprovsPerformance() async throws {
        let user = try await createTestUser(role: .programmer)
        
        // Primera llamada (consulta Firestore)
        let start1 = Date()
        _ = await AuthorizationServiceFS.allowed(.read, on: .kit, for: user)
        let time1 = Date().timeIntervalSince(start1)
        
        // Segunda llamada (usa caché)
        let start2 = Date()
        _ = await AuthorizationServiceFS.allowed(.read, on: .kit, for: user)
        let time2 = Date().timeIntervalSince(start2)
        
        // La segunda llamada debería ser más rápida
        XCTAssertLessThan(time2, time1, "Caché debería mejorar performance")
    }
    
    /// Verifica que clearCache() limpia el caché
    func testClearCacheWorks() async throws {
        let user = try await createTestUser(role: .programmer)
        
        // Cargar en caché
        _ = await AuthorizationServiceFS.allowed(.read, on: .kit, for: user)
        
        // Limpiar caché
        PolicyService.shared.clearCache()
        
        // La siguiente llamada debería consultar Firestore de nuevo
        // (no podemos verificar directamente, pero no debería fallar)
        let result = await AuthorizationServiceFS.allowed(.read, on: .kit, for: user)
        XCTAssertTrue(result)
    }
    
    // MARK: - Special Business Rules
    
    /// Verifica canCreateKits helper
    func testCanCreateKitsHelper() async throws {
        let programmer = try await createTestUser(role: .programmer)
        let logistics = try await createTestUser(role: .logistics)
        let sanitary = try await createTestUser(role: .sanitary)
        
        let programmerCan = await AuthorizationServiceFS.canCreateKits(programmer)
        let logisticsCan = await AuthorizationServiceFS.canCreateKits(logistics)
        let sanitaryCan = await AuthorizationServiceFS.canCreateKits(sanitary)
        
        XCTAssertTrue(programmerCan, "Programmer debería poder crear kits")
        XCTAssertFalse(logisticsCan, "Logistics no debería poder crear kits")
        XCTAssertFalse(sanitaryCan, "Sanitary no debería poder crear kits")
    }
    
    /// Verifica canUpdateStock helper
    func testCanUpdateStockHelper() async throws {
        let programmer = try await createTestUser(role: .programmer)
        let logistics = try await createTestUser(role: .logistics)
        let sanitary = try await createTestUser(role: .sanitary)
        
        // Todos deberían poder actualizar stock
        let programmerCan = await AuthorizationServiceFS.canUpdateStock(programmer)
        let logisticsCan = await AuthorizationServiceFS.canUpdateStock(logistics)
        let sanitaryCan = await AuthorizationServiceFS.canUpdateStock(sanitary)
        
        XCTAssertTrue(programmerCan, "Programmer debería poder actualizar stock")
        XCTAssertTrue(logisticsCan, "Logistics debería poder actualizar stock")
        XCTAssertTrue(sanitaryCan, "Sanitary debería poder actualizar stock")
    }
    
    /// Verifica canManageUsers helper
    func testCanManageUsersHelper() async throws {
        let programmer = try await createTestUser(role: .programmer)
        let logistics = try await createTestUser(role: .logistics)
        let sanitary = try await createTestUser(role: .sanitary)
        
        // Solo programador puede crear Y eliminar usuarios
        let programmerCan = await AuthorizationServiceFS.canManageUsers(programmer)
        let logisticsCan = await AuthorizationServiceFS.canManageUsers(logistics)
        let sanitaryCan = await AuthorizationServiceFS.canManageUsers(sanitary)
        
        XCTAssertTrue(programmerCan, "Programmer debería poder gestionar usuarios")
        XCTAssertFalse(logisticsCan, "Logistics no debería poder gestionar usuarios")
        XCTAssertFalse(sanitaryCan, "Sanitary no debería poder gestionar usuarios")
    }
    
    // MARK: - UIPermissionsFS Compatibility
    
    /// Verifica que UIPermissionsFS funciona correctamente
    func testUIPermissionsFSCompatibility() async throws {
        let logistics = try await createTestUser(role: .logistics)
        
        let canCreateKits = await UIPermissionsFS.canCreateKits(logistics)
        let canEditThresholds = await UIPermissionsFS.canEditThresholds(logistics)
        let userMgmt = await UIPermissionsFS.userMgmt(logistics)
        
        XCTAssertFalse(canCreateKits)
        XCTAssertTrue(canEditThresholds)
        XCTAssertFalse(userMgmt.create)
        XCTAssertTrue(userMgmt.read)
        XCTAssertTrue(userMgmt.update)
        XCTAssertFalse(userMgmt.delete)
    }
    
    // MARK: - Helper Methods
    
    /// Crea un usuario de prueba con el rol especificado
    /// NOTA: Este método necesita ser adaptado según cómo tengas configurado
    /// tu Firestore de testing (emulador o datos de prueba)
    private func createTestUser(role: RoleKind) async throws -> UserFS {
        // OPCIÓN 1: Si usas Firebase Emulator
        // Crear rol y policies en Firestore de testing
        
        // OPCIÓN 2: Mock simple para tests
        var user = UserFS(
            uid: "test-\(role.rawValue)",
            username: "test-\(role.rawValue)",
            fullName: "Test \(role.rawValue.capitalized)",
            email: "test-\(role.rawValue)@test.com"
        )
        
        // Aquí necesitas crear el rol y policies en Firestore de testing
        // O usar un mock service para tests
        
        // Por ahora, retornamos un usuario básico
        // Ajusta esto según tu configuración de testing
        user.roleId = "test-role-\(role.rawValue)"
        
        return user
    }
}

// MARK: - Integration Tests

/// Tests de integración que verifican el flujo completo
/// Requieren conexión a Firestore (emulador o real)
@MainActor
final class AuthorizationServiceFSIntegrationTests: XCTestCase {
    
    /// Test completo de flujo: crear rol, crear policies, verificar permisos
    func testCompleteAuthorizationFlow() async throws {
        // 1. Crear rol de Logística
        let role = try await PolicyService.shared.createRole(
            kind: .logistics,
            displayName: "Logística Test"
        )
        
        guard let roleId = role.id else {
            XCTFail("Rol creado sin ID")
            return
        }
        
        // 2. Crear policies para Logística
        _ = try await PolicyService.shared.createPolicy(
            roleId: roleId,
            entity: .kit,
            canCreate: false,  // NO crear kits
            canRead: true,
            canUpdate: true,
            canDelete: true
        )
        
        // 3. Crear usuario con este rol
        var user = UserFS(
            uid: "integration-test-user",
            username: "test-logistics",
            fullName: "Test Logistics User",
            email: "test@logistics.com"
        )
        user.roleId = roleId
        
        // 4. Verificar permisos
        let canCreate = await AuthorizationServiceFS.allowed(.create, on: .kit, for: user)
        let canUpdate = await AuthorizationServiceFS.allowed(.update, on: .kit, for: user)
        
        XCTAssertFalse(canCreate, "Logística no debería poder crear kits")
        XCTAssertTrue(canUpdate, "Logística sí debería poder actualizar kits")
        
        // 5. Limpiar (opcional)
        PolicyService.shared.clearCache()
    }
}

// MARK: - Performance Tests

/// Tests de rendimiento
@MainActor
final class AuthorizationServiceFSPerformanceTests: XCTestCase {
    
    /// Mide el tiempo de respuesta con caché caliente
    func testPerformanceWithWarmCache() async throws {
        let user = UserFS(
            uid: "perf-test",
            username: "perf",
            fullName: "Performance Test",
            email: "perf@test.com",
            roleId: "test-role"
        )
        
        // Calentar caché
        _ = await AuthorizationServiceFS.allowed(.read, on: .kit, for: user)
        
        // Medir performance
        measure {
            Task { @MainActor in
                _ = await AuthorizationServiceFS.allowed(.read, on: .kit, for: user)
            }
        }
    }
}








































































































































