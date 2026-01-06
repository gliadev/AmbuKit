//
//  UserServiceTests..swift
//  AmbuKit
//
//  Created by Adolfo on 16/11/25.
//
//  Tests para UserService - Gestión de usuarios en Firestore
//  ⚠️ IMPORTANTE: Estos tests usan Firebase REAL
//  Los tests CRUD crean datos de prueba que se limpian en tearDown
//


import XCTest
@testable import AmbuKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

/// Tests para UserService
/// Verifica CRUD, permisos, auditoría y cache
@MainActor
final class UserServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    var service: UserService!
    var db: Firestore!
    
    // Usuarios de prueba
    var programmer: UserFS!
    var logistics: UserFS!
    var sanitary: UserFS!
    
    // Roles de prueba (obtenidos de Firebase, no creados)
    var programmerRole: RoleFS!
    var logisticsRole: RoleFS!
    var sanitaryRole: RoleFS!
    
    // IDs de usuarios creados para limpieza
    private var createdUserIds: [String] = []
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Configurar Firebase para tests
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        service = UserService.shared
        db = Firestore.firestore()
        service.clearCache()
        
        // Obtener roles existentes (NO crear nuevos)
        try await fetchExistingRoles()
        
        // Crear usuario programmer de prueba
        try await createProgrammerTestUser()
        
        createdUserIds = []
    }
    
    override func tearDown() async throws {
        // Limpiar usuarios creados durante los tests
        for userId in createdUserIds {
            try? await db.collection(UserFS.collectionName).document(userId).delete()
        }
        createdUserIds.removeAll()
        
        // Limpiar usuario programmer de prueba
        if let programmerId = programmer?.id {
            try? await db.collection(UserFS.collectionName).document(programmerId).delete()
        }
        
        // Limpiar cache
        service.clearCache()
        
        try await super.tearDown()
    }
    
    // MARK: - Setup Helpers
    
    /// Obtener roles existentes de Firebase (NO crear nuevos)
    private func fetchExistingRoles() async throws {
        let roles = await PolicyService.shared.getAllRoles()
        
        programmerRole = roles.first(where: { $0.kind == .programmer })
        logisticsRole = roles.first(where: { $0.kind == .logistics })
        sanitaryRole = roles.first(where: { $0.kind == .sanitary })
        
        guard programmerRole != nil, logisticsRole != nil, sanitaryRole != nil else {
            throw XCTSkip("No se encontraron los 3 roles base en Firebase")
        }
    }
    
    /// Crear usuario programmer de prueba para actuar como actor
    private func createProgrammerTestUser() async throws {
        let testId = "test_programmer_\(UUID().uuidString.prefix(6))"
        
        programmer = UserFS(
            id: testId,
            uid: "test_prog_uid_\(UUID().uuidString.prefix(6))",
            username: "test_programmer_\(UUID().uuidString.prefix(6))",
            fullName: "Test Programmer",
            email: "programmer_\(UUID().uuidString.prefix(6))@test.com",
            active: true,
            roleId: programmerRole.id
        )
        
        // Guardar en Firestore
        try db.collection(UserFS.collectionName)
            .document(testId)
            .setData(from: programmer)
    }
    
    /// Helper para crear usuario de prueba y registrar para limpieza
    private func createTestUser(
        username: String,
        fullName: String,
        email: String,
        roleId: String?,
        active: Bool = true
    ) -> UserFS {
        let testId = "test_user_\(UUID().uuidString.prefix(6))"
        return UserFS(
            id: testId,
            uid: "test_uid_\(UUID().uuidString.prefix(6))",
            username: username,
            fullName: fullName,
            email: email,
            active: active,
            roleId: roleId
        )
    }
    
    // MARK: - Tests - Create
    
    func testCreateUser_WithPermissions_Succeeds() async throws {
        // Given: Un programador (con permisos)
        let uniqueSuffix = UUID().uuidString.prefix(6)
        let email = "newuser_\(uniqueSuffix)@test.com"
        let password = "Test1234!"
        let username = "test_new_user_\(uniqueSuffix)"
        let fullName = "New Test User"
        
        // When: Crear un nuevo usuario
        let newUser = try await service.create(
            email: email,
            password: password,
            username: username,
            fullName: fullName,
            roleId: logisticsRole.id!,
            actor: programmer
        )
        
        // Registrar para limpieza
        if let id = newUser.id {
            createdUserIds.append(id)
        }
        
        // Then: Usuario creado correctamente
        XCTAssertNotNil(newUser.id)
        XCTAssertEqual(newUser.username, username)
        XCTAssertEqual(newUser.email, email)
        XCTAssertEqual(newUser.fullName, fullName)
        XCTAssertTrue(newUser.active)
        XCTAssertEqual(newUser.roleId, logisticsRole.id)
        
        // Verificar que se guardó en Firestore
        let savedUser = await service.getUser(id: newUser.id)
        XCTAssertNotNil(savedUser)
        XCTAssertEqual(savedUser?.username, username)
    }
    
    func testCreateUser_WithoutPermissions_Fails() async throws {
        // Given: Un sanitario (sin permisos para crear usuarios)
        sanitary = createTestUser(
            username: "test_sanitary_\(UUID().uuidString.prefix(6))",
            fullName: "Test Sanitary",
            email: "sanitary_\(UUID().uuidString.prefix(6))@test.com",
            roleId: sanitaryRole.id
        )
        
        // When/Then: Intentar crear usuario debe fallar
        do {
            let user = try await service.create(
                email: "fail_\(UUID().uuidString.prefix(6))@test.com",
                password: "Test1234!",
                username: "fail_user_\(UUID().uuidString.prefix(6))",
                fullName: "Fail User",
                roleId: logisticsRole.id!,
                actor: sanitary
            )
            if let id = user.id {
                createdUserIds.append(id)
            }
            XCTFail("Debería haber lanzado error de autorización")
        } catch {
            // Error esperado - cualquier error de autorización es válido
            XCTAssertTrue(
                error.localizedDescription.lowercased().contains("autoriz") ||
                error.localizedDescription.lowercased().contains("permiso") ||
                error.localizedDescription.lowercased().contains("unauthorized") ||
                error is UserServiceError,
                "Error debería ser de autorización: \(error)"
            )
        }
    }
    
    func testCreateUser_DuplicateUsername_Fails() async throws {
        // Given: Crear un usuario primero
        let uniqueSuffix = UUID().uuidString.prefix(6)
        let duplicateUsername = "test_dup_\(uniqueSuffix)"
        
        let firstUser = try await service.create(
            email: "first_\(uniqueSuffix)@test.com",
            password: "Test1234!",
            username: duplicateUsername,
            fullName: "First User",
            roleId: logisticsRole.id!,
            actor: programmer
        )
        if let id = firstUser.id {
            createdUserIds.append(id)
        }
        
        // When/Then: Intentar crear con username duplicado debe fallar
        do {
            let user = try await service.create(
                email: "duplicate_\(uniqueSuffix)@test.com",
                password: "Test1234!",
                username: duplicateUsername, // Mismo username
                fullName: "Duplicate User",
                roleId: logisticsRole.id!,
                actor: programmer
            )
            if let id = user.id {
                createdUserIds.append(id)
            }
            XCTFail("Debería haber lanzado error de username duplicado")
        } catch {
            // Error esperado
            XCTAssertTrue(
                error.localizedDescription.lowercased().contains("username") ||
                error.localizedDescription.lowercased().contains("duplicado") ||
                error.localizedDescription.lowercased().contains("existe") ||
                error is UserServiceError,
                "Error debería mencionar username duplicado: \(error)"
            )
        }
    }
    
    // MARK: - Tests - Read
    
    func testGetUser_ExistingUser_ReturnsUser() async throws {
        // Given: Un usuario existente
        let userId = programmer.id!
        
        // When: Obtener usuario
        let user = await service.getUser(id: userId)
        
        // Then: Usuario encontrado
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.id, userId)
    }
    
    func testGetUser_NonExistingUser_ReturnsNil() async throws {
        // Given: Un ID que no existe
        let fakeId = "nonexistent_user_id_12345"
        
        // When: Obtener usuario
        let user = await service.getUser(id: fakeId)
        
        // Then: No encontrado
        XCTAssertNil(user)
    }
    
    func testGetAllUsers_ReturnsUsers() async throws {
        // When: Obtener todos los usuarios
        let users = await service.getAllUsers()
        
        // Then: Hay usuarios (al menos el de prueba)
        XCTAssertFalse(users.isEmpty)
    }
    
    /// getAllUsers() ya filtra por usuarios activos internamente
    func testGetAllUsers_ReturnsOnlyActiveUsers() async throws {
        // When: Obtener todos los usuarios (getAllUsers filtra por active=true)
        let users = await service.getAllUsers()
        
        // Then: Todos están activos (porque getAllUsers ya filtra)
        XCTAssertTrue(users.allSatisfy { $0.active })
    }
    
    func testGetUsersByRole_ReturnsUsersWithRole() async throws {
        // Given: Un rol específico
        guard let roleId = programmerRole.id else {
            throw XCTSkip("Programmer role no tiene ID")
        }
        
        // When: Obtener usuarios por rol
        let users = await service.getUsersByRole(roleId: roleId)
        
        // Then: Todos los usuarios tienen ese rol
        for user in users {
            XCTAssertEqual(user.roleId, roleId)
        }
    }
    
    // MARK: - Tests - Update
    
    func testUpdateUser_WithPermissions_Succeeds() async throws {
        // Given: Crear un usuario para actualizar
        let uniqueSuffix = UUID().uuidString.prefix(6)
        let originalUser = try await service.create(
            email: "update_\(uniqueSuffix)@test.com",
            password: "Test1234!",
            username: "update_user_\(uniqueSuffix)",
            fullName: "Original Name",
            roleId: logisticsRole.id!,
            actor: programmer
        )
        
        guard let userId = originalUser.id else {
            XCTFail("Usuario debería tener ID")
            return
        }
        createdUserIds.append(userId)
        
        // Crear nuevo UserFS con valores actualizados
        // (fullName y username son let, así que creamos nuevo objeto)
        let updatedUser = UserFS(
            id: userId,
            uid: originalUser.uid,
            username: "updated_user_\(uniqueSuffix)",  // Nuevo username
            fullName: "Updated Name",                   // Nuevo nombre
            email: originalUser.email,
            active: originalUser.active,
            roleId: originalUser.roleId,
            baseId: originalUser.baseId,
            createdAt: originalUser.createdAt,
            updatedAt: Date()
        )
        
        // When: Actualizar usuario (con label user:)
        try await service.update(user: updatedUser, actor: programmer)
        
        // Then: Usuario actualizado
        let fetched = await service.getUser(id: userId)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.fullName, "Updated Name")
        XCTAssertEqual(fetched?.username, "updated_user_\(uniqueSuffix)")
    }
    
    func testUpdateUser_WithoutPermissions_Fails() async throws {
        // Given: Un sanitario (sin permisos para actualizar usuarios)
        sanitary = createTestUser(
            username: "test_san_\(UUID().uuidString.prefix(6))",
            fullName: "Test Sanitary",
            email: "san_\(UUID().uuidString.prefix(6))@test.com",
            roleId: sanitaryRole.id
        )
        
        // Crear nuevo UserFS con valores "actualizados"
        let hackedUser = UserFS(
            id: programmer.id,
            uid: programmer.uid,
            username: programmer.username,
            fullName: "Hacked Name",  // Intento de cambio
            email: programmer.email,
            active: programmer.active,
            roleId: programmer.roleId,
            baseId: programmer.baseId,
            createdAt: programmer.createdAt,
            updatedAt: Date()
        )
        
        // When/Then: Intentar actualizar debe fallar
        do {
            try await service.update(user: hackedUser, actor: sanitary)
            XCTFail("Debería haber lanzado error de autorización")
        } catch {
            // Error esperado
            XCTAssertTrue(
                error.localizedDescription.lowercased().contains("autoriz") ||
                error.localizedDescription.lowercased().contains("permiso") ||
                error is UserServiceError,
                "Error debería ser de autorización"
            )
        }
    }
    
    func testUpdateUser_DuplicateUsername_Fails() async throws {
        // Given: Crear dos usuarios
        let suffix1 = UUID().uuidString.prefix(6)
        let suffix2 = UUID().uuidString.prefix(6)
        
        let user1 = try await service.create(
            email: "user1_\(suffix1)@test.com",
            password: "Test1234!",
            username: "user1_\(suffix1)",
            fullName: "User 1",
            roleId: logisticsRole.id!,
            actor: programmer
        )
        if let id = user1.id { createdUserIds.append(id) }
        
        let user2 = try await service.create(
            email: "user2_\(suffix2)@test.com",
            password: "Test1234!",
            username: "user2_\(suffix2)",
            fullName: "User 2",
            roleId: logisticsRole.id!,
            actor: programmer
        )
        guard let user2Id = user2.id else {
            XCTFail("User2 debería tener ID")
            return
        }
        createdUserIds.append(user2Id)
        
        // Intentar cambiar username de user2 al de user1
        let conflictingUser = UserFS(
            id: user2Id,
            uid: user2.uid,
            username: "user1_\(suffix1)",  // Username de user1 (duplicado!)
            fullName: user2.fullName,
            email: user2.email,
            active: user2.active,
            roleId: user2.roleId,
            baseId: user2.baseId,
            createdAt: user2.createdAt,
            updatedAt: Date()
        )
        
        // When/Then: Actualizar con username duplicado debe fallar
        do {
            try await service.update(user: conflictingUser, actor: programmer)
            XCTFail("Debería haber lanzado error de username duplicado")
        } catch {
            // Error esperado
            XCTAssertTrue(
                error.localizedDescription.lowercased().contains("username") ||
                error.localizedDescription.lowercased().contains("duplicado") ||
                error is UserServiceError,
                "Error debería mencionar username duplicado"
            )
        }
    }
    
    // MARK: - Tests - Delete
    
    func testDeleteUser_WithPermissions_Succeeds() async throws {
        // Given: Crear un usuario para eliminar
        let uniqueSuffix = UUID().uuidString.prefix(6)
        let userToDelete = try await service.create(
            email: "todelete_\(uniqueSuffix)@test.com",
            password: "Test1234!",
            username: "to_delete_\(uniqueSuffix)",
            fullName: "To Delete",
            roleId: logisticsRole.id!,
            actor: programmer
        )
        
        guard let userId = userToDelete.id else {
            XCTFail("Usuario debería tener ID")
            return
        }
        // NO añadir a createdUserIds porque lo vamos a eliminar
        
        // When: Eliminar usuario
        try await service.delete(userId: userId, actor: programmer)
        
        // Then: Usuario marcado como inactivo o eliminado
        let deletedUser = await service.getUser(id: userId)
        // Puede ser nil (eliminado) o active=false (soft delete)
        if let user = deletedUser {
            XCTAssertFalse(user.active, "Usuario debería estar inactivo")
        }
        // Si es nil, fue hard delete - también válido
    }
    
    func testDeleteUser_WithoutPermissions_Fails() async throws {
        // Given: Un sanitario (sin permisos)
        sanitary = createTestUser(
            username: "test_san_\(UUID().uuidString.prefix(6))",
            fullName: "Test Sanitary",
            email: "san_\(UUID().uuidString.prefix(6))@test.com",
            roleId: sanitaryRole.id
        )
        
        // When/Then: Intentar eliminar debe fallar
        do {
            try await service.delete(userId: programmer.id!, actor: sanitary)
            XCTFail("Debería haber lanzado error de autorización")
        } catch {
            // Error esperado
            XCTAssertTrue(true)
        }
    }
    
    func testDeleteUser_Self_Fails() async throws {
        // Given: Un usuario intentando eliminarse a sí mismo
        // When/Then: Debe fallar
        do {
            try await service.delete(userId: programmer.id!, actor: programmer)
            XCTFail("Debería haber lanzado error de auto-eliminación")
        } catch {
            // Error esperado - no puede eliminarse a sí mismo
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Tests - Cache
    
    func testCache_StoresUsers() async throws {
        // Given: Cache limpio
        service.clearCache()
        
        // When: Obtener usuario (primera vez, desde Firestore)
        let user1 = await service.getUser(id: programmer.id)
        
        // Then: Usuario encontrado
        XCTAssertNotNil(user1)
        
        // When: Obtener usuario (segunda vez, desde cache)
        let user2 = await service.getUser(id: programmer.id)
        
        // Then: Mismo usuario
        XCTAssertNotNil(user2)
        XCTAssertEqual(user1?.id, user2?.id)
    }
    
    func testClearCache_Works() async throws {
        // Given: Usuario en cache
        _ = await service.getUser(id: programmer.id)
        
        // When: Limpiar cache
        service.clearCache()
        
        // Then: Podemos obtener usuarios de nuevo sin problemas
        let user = await service.getUser(id: programmer.id)
        XCTAssertNotNil(user)
    }
    
    // MARK: - Tests - Helpers
    
    func testIsEmailTaken_ExistingEmail_ReturnsTrue() async throws {
        // Given: Un email existente
        let email = programmer.email
        
        // When: Verificar si está en uso
        let isTaken = await service.isEmailTaken(email)
        
        // Then: Está en uso
        XCTAssertTrue(isTaken)
    }
    
    func testIsEmailTaken_NewEmail_ReturnsFalse() async throws {
        // Given: Un email nuevo
        let email = "newemail_\(UUID().uuidString.prefix(8))@test.com"
        
        // When: Verificar si está en uso
        let isTaken = await service.isEmailTaken(email)
        
        // Then: No está en uso
        XCTAssertFalse(isTaken)
    }
    
    func testGetUserCount_ReturnsPositiveNumber() async throws {
        // When: Obtener conteo
        let count = await service.getUserCount()
        
        // Then: Hay al menos 1 usuario (el de prueba)
        XCTAssertGreaterThanOrEqual(count, 1)
    }
}








































