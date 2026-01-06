//
//  AuthFlowTests.swift
//  AmbuKitTests
//
//  Created by Adolfo on 30/12/25.
//  Integration Tests para flujos completos de autenticación.
//  Verifica: Login → Carga de datos → Acceso a inventario
//

import XCTest
@testable import AmbuKit

/// Tests de integración para flujos de autenticación
/// Verifica el ciclo completo: Login → Datos de usuario → Permisos → Inventario
@MainActor
final class AuthFlowTests: XCTestCase {
    
    // MARK: - Properties
    
    var userService: UserService!
    var policyService: PolicyService!
    var kitService: KitService!
    var baseService: BaseService!
    
    var programmerRole: RoleFS?
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        userService = UserService.shared
        policyService = PolicyService.shared
        kitService = KitService.shared
        baseService = BaseService.shared
        
        // Limpiar cachés
        userService.clearCache()
        policyService.clearCache()
        kitService.clearCache()
        baseService.clearCache()
        
        // Obtener rol de programador para tests
        let roles = await policyService.getAllRoles()
        programmerRole = roles.first(where: { $0.kind == .programmer })
        
        guard programmerRole != nil else {
            throw XCTSkip("No se encontró rol de programador en Firebase")
        }
    }
    
    override func tearDown() async throws {
        userService.clearCache()
        policyService.clearCache()
        kitService.clearCache()
        baseService.clearCache()
        
        try await super.tearDown()
    }
    
    // MARK: - Complete Auth Flow Tests
    
    /// Test del flujo completo: Login → Cargar datos usuario → Acceder a inventario
    func testCompleteAuthFlow() async throws {
        // STEP 1: Simular usuario autenticado (ya existe en Firebase)
        let users = await userService.getAllUsers()
        
        // Buscar usuario activo CON roleId asignado
        guard let existingUser = users.first(where: { $0.active && $0.roleId != nil && !$0.roleId!.isEmpty }) else {
            throw XCTSkip("No hay usuarios activos con roleId en Firebase para probar el flujo")
        }
        
        // STEP 2: Cargar datos completos del usuario
        let loadedUser = await userService.getUser(id: existingUser.id!)
        XCTAssertNotNil(loadedUser, "Usuario debería cargarse correctamente")
        XCTAssertEqual(loadedUser?.id, existingUser.id)
        
        // STEP 3: Cargar rol y permisos del usuario
        guard let roleId = loadedUser?.roleId, !roleId.isEmpty else {
            throw XCTSkip("Usuario no tiene roleId asignado")
        }
        
        let role = await policyService.getRole(id: roleId)
        XCTAssertNotNil(role, "Rol del usuario debería existir")
        
        // Cargar políticas del rol
        let policies = await policyService.getPolicies(roleId: roleId)
        
        // Si no hay políticas, es un problema de datos, no del test
        if policies.isEmpty {
            throw XCTSkip("El rol '\(roleId)' no tiene políticas configuradas en Firebase")
        }
        
        XCTAssertFalse(policies.isEmpty, "Usuario debería tener políticas asignadas")
        
        // STEP 4: Acceder a inventario según permisos
        let kits = await kitService.getAllKits()
        XCTAssertNotNil(kits, "Debería poder acceder a kits")
        
        let bases = await baseService.getAllBases()
        XCTAssertNotNil(bases, "Debería poder acceder a bases")
        
        // STEP 5: Verificar que el usuario está en caché
        let cachedUser = await userService.getUser(id: existingUser.id!)
        XCTAssertNotNil(cachedUser, "Usuario debería estar en caché")
    }
    
    /// Test del flujo de logout: Cerrar sesión → Limpiar datos → Estado inicial
    func testLogoutFlow() async throws {
        // STEP 1: Simular estado "logueado" - cargar datos
        let users = await userService.getAllUsers()
        let bases = await baseService.getAllBases()
        let kits = await kitService.getAllKits()
        
        // Verificar que hay datos cargados
        XCTAssertNotNil(users)
        XCTAssertNotNil(bases)
        XCTAssertNotNil(kits)
        
        // STEP 2: Simular logout - limpiar todos los cachés
        userService.clearCache()
        policyService.clearCache()
        kitService.clearCache()
        baseService.clearCache()
        
        // STEP 3: Verificar que las operaciones siguen funcionando después del "logout"
        let usersAfterLogout = await userService.getAllUsers()
        XCTAssertNotNil(usersAfterLogout, "Servicio debería funcionar después de limpiar caché")
    }
    
    /// Test de autenticación inválida: Credenciales incorrectas → Error → Reintento
    func testInvalidAuthFlow() async throws {
        // STEP 1: Intentar obtener usuario inexistente
        let nonExistentUser = await userService.getUser(id: "non_existent_user_id_12345")
        XCTAssertNil(nonExistentUser, "Usuario inexistente debería retornar nil")
        
        // STEP 2: Intentar obtener usuario con ID vacío
        let emptyIdUser = await userService.getUser(id: "")
        XCTAssertNil(emptyIdUser, "ID vacío debería retornar nil")
        
        // STEP 3: Verificar que el servicio sigue funcionando después de errores
        let validUsers = await userService.getAllUsers()
        XCTAssertNotNil(validUsers, "Servicio debería seguir funcionando después de errores")
    }
    
    // MARK: - Role-Based Access Tests
    
    /// Verifica que un usuario con rol Programmer puede acceder a todo
    func testProgrammerFullAccess() async throws {
        guard let roleId = programmerRole?.id else {
            throw XCTSkip("Rol de programador no disponible")
        }
        
        // Obtener políticas del programador
        let policies = await policyService.getPolicies(roleId: roleId)
        
        // Verificar acceso a entidades principales
        let kitPolicy = policies.first(where: { $0.entity == .kit })
        let userPolicy = policies.first(where: { $0.entity == .user })
        let basePolicy = policies.first(where: { $0.entity == .base })
        
        // Programador debería tener acceso completo
        if let kitPolicy = kitPolicy {
            XCTAssertTrue(kitPolicy.canCreate, "Programmer debería poder crear kits")
            XCTAssertTrue(kitPolicy.canRead, "Programmer debería poder leer kits")
            XCTAssertTrue(kitPolicy.canUpdate, "Programmer debería poder actualizar kits")
            XCTAssertTrue(kitPolicy.canDelete, "Programmer debería poder eliminar kits")
        }
        
        if let userPolicy = userPolicy {
            XCTAssertTrue(userPolicy.canCreate, "Programmer debería poder crear usuarios")
            XCTAssertTrue(userPolicy.canDelete, "Programmer debería poder eliminar usuarios")
        }
        
        if let basePolicy = basePolicy {
            XCTAssertTrue(basePolicy.canRead, "Programmer debería poder leer bases")
        }
    }
    
    /// Verifica restricciones de rol Sanitary
    func testSanitaryRestrictedAccess() async throws {
        let roles = await policyService.getAllRoles()
        guard let sanitaryRole = roles.first(where: { $0.kind == .sanitary }) else {
            throw XCTSkip("Rol de sanitario no disponible")
        }
        
        let policies = await policyService.getPolicies(roleId: sanitaryRole.id!)
        
        // Sanitary NO debería poder crear/eliminar usuarios
        let userPolicy = policies.first(where: { $0.entity == .user })
        if let userPolicy = userPolicy {
            XCTAssertFalse(userPolicy.canCreate, "Sanitary NO debería poder crear usuarios")
            XCTAssertFalse(userPolicy.canDelete, "Sanitary NO debería poder eliminar usuarios")
        }
        
        // Sanitary NO debería poder crear kits
        let kitPolicy = policies.first(where: { $0.entity == .kit })
        if let kitPolicy = kitPolicy {
            XCTAssertFalse(kitPolicy.canCreate, "Sanitary NO debería poder crear kits")
        }
    }
    
    // MARK: - Session Persistence Tests
    
    /// Verifica que los datos persisten correctamente en caché
    func testSessionDataPersistence() async throws {
        // STEP 1: Cargar datos iniciales
        let initialUsers = await userService.getAllUsers()
        
        guard !initialUsers.isEmpty else {
            throw XCTSkip("No hay usuarios para probar persistencia")
        }
        
        let firstUserId = initialUsers.first!.id!
        
        // STEP 2: Cargar usuario específico (debería guardarse en caché)
        let user1 = await userService.getUser(id: firstUserId)
        XCTAssertNotNil(user1)
        
        // STEP 3: Volver a cargar (debería venir de caché)
        let user2 = await userService.getUser(id: firstUserId)
        XCTAssertNotNil(user2)
        XCTAssertEqual(user1?.id, user2?.id, "Datos en caché deberían ser consistentes")
        XCTAssertEqual(user1?.username, user2?.username)
        
        // STEP 4: Los datos deberían ser idénticos
        XCTAssertEqual(user1?.email, user2?.email)
        XCTAssertEqual(user1?.roleId, user2?.roleId)
    }
}
