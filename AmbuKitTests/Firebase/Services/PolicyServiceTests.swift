//
//  PolicyServiceTests.swift
//  AmbuKitTests
//
//  Created by Adolfo on 15/12/25.
//  Tests para PolicyService - Gestión de roles y políticas en Firestore
//  ⚠️ IMPORTANTE: Estos tests usan Firebase REAL (sin emulator)
//  Los datos se obtienen de Firestore de producción
//

import XCTest
@testable import AmbuKit

/// Tests para verificar el funcionamiento de PolicyService
/// Incluye tests de roles, políticas y caché
@MainActor
final class PolicyServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Referencia al servicio (singleton)
    private var sut: PolicyService { PolicyService.shared }
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        // Limpiar caché antes de cada test para estado limpio
        sut.clearCache()
    }
    
    override func tearDown() async throws {
        // Limpiar caché después de cada test
        sut.clearCache()
        try await super.tearDown()
    }
    
    // MARK: - Roles Tests
    
    /// Verifica que getAllRoles devuelve los 3 roles base
    func testGetAllRolesReturnsThreeRoles() async throws {
        // When
        let roles = await sut.getAllRoles()
        
        // Then
        XCTAssertGreaterThanOrEqual(
            roles.count, 3,
            "Deberían existir al menos 3 roles (programmer, logistics, sanitary)"
        )
    }
    
    /// Verifica que existe el rol Programmer
    func testGetRoleProgrammerExists() async throws {
        // Given
        let roles = await sut.getAllRoles()
        let programmerRole = roles.first(where: { $0.kind == .programmer })
        
        // Then
        XCTAssertNotNil(programmerRole, "Debería existir el rol Programmer")
        XCTAssertEqual(programmerRole?.kind, .programmer)
    }
    
    /// Verifica que existe el rol Logistics
    func testGetRoleLogisticsExists() async throws {
        // Given
        let roles = await sut.getAllRoles()
        let logisticsRole = roles.first(where: { $0.kind == .logistics })
        
        // Then
        XCTAssertNotNil(logisticsRole, "Debería existir el rol Logistics")
        XCTAssertEqual(logisticsRole?.kind, .logistics)
    }
    
    /// Verifica que existe el rol Sanitary
    func testGetRoleSanitaryExists() async throws {
        // Given
        let roles = await sut.getAllRoles()
        let sanitaryRole = roles.first(where: { $0.kind == .sanitary })
        
        // Then
        XCTAssertNotNil(sanitaryRole, "Debería existir el rol Sanitary")
        XCTAssertEqual(sanitaryRole?.kind, .sanitary)
    }
    
    /// Verifica que getRole con ID válido devuelve el rol
    func testGetRoleWithValidIdReturnsRole() async throws {
        // Given: Obtener un rol existente
        let roles = await sut.getAllRoles()
        guard let firstRole = roles.first, let roleId = firstRole.id else {
            throw XCTSkip("No hay roles disponibles en Firebase")
        }
        
        // When
        let role = await sut.getRole(id: roleId)
        
        // Then
        XCTAssertNotNil(role)
        XCTAssertEqual(role?.id, roleId)
    }
    
    /// Verifica que getRole con ID inválido devuelve nil
    func testGetRoleWithInvalidIdReturnsNil() async throws {
        // When
        let role = await sut.getRole(id: "invalid_role_id_that_does_not_exist_12345")
        
        // Then
        XCTAssertNil(role, "Debería devolver nil para ID inválido")
    }
    
    /// Verifica que getRole con nil devuelve nil
    func testGetRoleWithNilIdReturnsNil() async throws {
        // When
        let role = await sut.getRole(id: nil)
        
        // Then
        XCTAssertNil(role, "Debería devolver nil para ID nil")
    }
    
    /// Verifica que getRole con string vacío devuelve nil
    func testGetRoleWithEmptyIdReturnsNil() async throws {
        // When
        let role = await sut.getRole(id: "")
        
        // Then
        XCTAssertNil(role, "Debería devolver nil para ID vacío")
    }
    
    // MARK: - Policies Tests
    
    /// Verifica que getPolicies devuelve políticas para un rol válido
    func testGetPoliciesForValidRoleReturnsPolicies() async throws {
        // Given: Obtener rol de Logistics (tiene políticas definidas)
        let roles = await sut.getAllRoles()
        guard let logisticsRole = roles.first(where: { $0.kind == .logistics }),
              let roleId = logisticsRole.id else {
            throw XCTSkip("No se encontró el rol Logistics")
        }
        
        // When
        let policies = await sut.getPolicies(roleId: roleId)
        
        // Then
        XCTAssertFalse(policies.isEmpty, "Logistics debería tener políticas definidas")
    }
    
    /// Verifica que getPolicies para rol inválido devuelve array vacío
    func testGetPoliciesForInvalidRoleReturnsEmpty() async throws {
        // When
        let policies = await sut.getPolicies(roleId: "invalid_role_id_xyz")
        
        // Then
        XCTAssertTrue(policies.isEmpty, "Debería devolver array vacío para rol inválido")
    }
    
    /// Verifica que getPolicies con nil devuelve array vacío
    func testGetPoliciesWithNilRoleIdReturnsEmpty() async throws {
        // When
        let policies = await sut.getPolicies(roleId: nil)
        
        // Then
        XCTAssertTrue(policies.isEmpty, "Debería devolver array vacío para roleId nil")
    }
    
    /// Verifica que getPolicy devuelve política específica
    func testGetPolicyForSpecificEntityReturnsPolicy() async throws {
        // Given: Obtener rol de Logistics
        let roles = await sut.getAllRoles()
        guard let logisticsRole = roles.first(where: { $0.kind == .logistics }),
              let roleId = logisticsRole.id else {
            throw XCTSkip("No se encontró el rol Logistics")
        }
        
        // When: Buscar política para entity .kit
        let policy = await sut.getPolicy(roleId: roleId, entity: .kit)
        
        // Then
        XCTAssertNotNil(policy, "Debería existir política de kit para Logistics")
        XCTAssertEqual(policy?.entity, .kit)
    }
    
    // MARK: - Cache Tests
    
    /// Verifica que el caché funciona (segunda llamada usa caché)
    func testCacheWorksForRoles() async throws {
        // Given: Primera llamada (sin caché)
        let roles1 = await sut.getAllRoles()
        
        // When: Segunda llamada (debería usar caché)
        let roles2 = await sut.getAllRoles()
        
        // Then: Ambas deberían devolver los mismos datos
        XCTAssertEqual(roles1.count, roles2.count)
        
        // Verificar que los IDs coinciden
        let ids1 = Set(roles1.compactMap { $0.id })
        let ids2 = Set(roles2.compactMap { $0.id })
        XCTAssertEqual(ids1, ids2, "Los roles del caché deberían coincidir")
    }
    
    /// Verifica que clearCache funciona correctamente
    func testClearCacheWorks() async throws {
        // Given: Cargar datos en caché
        _ = await sut.getAllRoles()
        
        // When: Limpiar caché
        sut.clearCache()
        
        // Then: Debería poder obtener roles de nuevo (desde Firestore)
        let roles = await sut.getAllRoles()
        XCTAssertFalse(roles.isEmpty, "Debería poder obtener roles después de limpiar caché")
    }
    
    /// Verifica que clearCache para rol específico funciona
    func testClearCacheForSpecificRoleWorks() async throws {
        // Given: Cargar un rol en caché
        let roles = await sut.getAllRoles()
        guard let firstRole = roles.first, let roleId = firstRole.id else {
            throw XCTSkip("No hay roles disponibles")
        }
        
        _ = await sut.getRole(id: roleId)
        
        // When: Limpiar caché solo de ese rol
        sut.clearCache(forRole: roleId)
        
        // Then: Debería poder obtener el rol de nuevo
        let role = await sut.getRole(id: roleId)
        XCTAssertNotNil(role)
    }
    
    // MARK: - Helper Methods Tests
    
    /// Verifica helper isProgrammer
    func testIsProgrammerHelper() async throws {
        // Given: Obtener rol Programmer
        let roles = await sut.getAllRoles()
        guard let programmerRole = roles.first(where: { $0.kind == .programmer }),
              let roleId = programmerRole.id else {
            throw XCTSkip("No se encontró el rol Programmer")
        }
        
        let programmer = UserFS(
            uid: "test-prog",
            username: "test_programmer",
            fullName: "Test Programmer",
            email: "prog@test.com",
            roleId: roleId
        )
        
        // When
        let isProg = await sut.isProgrammer(programmer)
        
        // Then
        XCTAssertTrue(isProg, "Debería detectar usuario como Programmer")
    }
    
    /// Verifica helper isLogistics
    func testIsLogisticsHelper() async throws {
        // Given: Obtener rol Logistics
        let roles = await sut.getAllRoles()
        guard let logisticsRole = roles.first(where: { $0.kind == .logistics }),
              let roleId = logisticsRole.id else {
            throw XCTSkip("No se encontró el rol Logistics")
        }
        
        let logistics = UserFS(
            uid: "test-log",
            username: "test_logistics",
            fullName: "Test Logistics",
            email: "log@test.com",
            roleId: roleId
        )
        
        // When
        let isLog = await sut.isLogistics(logistics)
        
        // Then
        XCTAssertTrue(isLog, "Debería detectar usuario como Logistics")
    }
    
    /// Verifica helper isSanitary
    func testIsSanitaryHelper() async throws {
        // Given: Obtener rol Sanitary
        let roles = await sut.getAllRoles()
        guard let sanitaryRole = roles.first(where: { $0.kind == .sanitary }),
              let roleId = sanitaryRole.id else {
            throw XCTSkip("No se encontró el rol Sanitary")
        }
        
        let sanitary = UserFS(
            uid: "test-san",
            username: "test_sanitary",
            fullName: "Test Sanitary",
            email: "san@test.com",
            roleId: roleId
        )
        
        // When
        let isSan = await sut.isSanitary(sanitary)
        
        // Then
        XCTAssertTrue(isSan, "Debería detectar usuario como Sanitary")
    }
    
    /// Verifica getRoleKind helper
    func testGetRoleKindHelper() async throws {
        // Given: Obtener rol Programmer
        let roles = await sut.getAllRoles()
        guard let programmerRole = roles.first(where: { $0.kind == .programmer }),
              let roleId = programmerRole.id else {
            throw XCTSkip("No se encontró el rol Programmer")
        }
        
        let user = UserFS(
            uid: "test-user",
            username: "test_user",
            fullName: "Test User",
            email: "user@test.com",
            roleId: roleId
        )
        
        // When
        let kind = await sut.getRoleKind(for: user)
        
        // Then
        XCTAssertEqual(kind, .programmer)
    }
    
    /// Verifica que getRoleKind con usuario sin rol devuelve nil
    func testGetRoleKindForUserWithoutRoleReturnsNil() async throws {
        // Given
        let user = UserFS(
            uid: "test-user",
            username: "test_user",
            fullName: "Test User",
            email: "user@test.com",
            roleId: nil
        )
        
        // When
        let kind = await sut.getRoleKind(for: user)
        
        // Then
        XCTAssertNil(kind, "Debería devolver nil para usuario sin rol")
    }
}
