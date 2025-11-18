//
//  UserServiceTests..swift
//  AmbuKit
//
//  Created by Adolfo on 16/11/25.
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
    
    // Roles de prueba
    var programmerRole: RoleFS!
    var logisticsRole: RoleFS!
    var sanitaryRole: RoleFS!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Configurar Firebase para tests
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        service = UserService.shared
        db = Firestore.firestore()
        
        // Crear roles de prueba
        try await createTestRoles()
        
        // Crear usuarios de prueba
        try await createTestUsers()
    }
    
    override func tearDown() async throws {
        // Limpiar datos de prueba
        await cleanupTestData()
        
        // Limpiar cache
        service.clearCache()
        
        try await super.tearDown()
    }
    
    // MARK: - Setup Helpers
    
    private func createTestRoles() async throws {
        // Crear rol Programmer
        programmerRole = try await PolicyService.shared.createRole(
            kind: .programmer,
            displayName: "Programador Test"
        )
        
        // Crear rol Logistics
        logisticsRole = try await PolicyService.shared.createRole(
            kind: .logistics,
            displayName: "Logística Test"
        )
        
        // Crear rol Sanitary
        sanitaryRole = try await PolicyService.shared.createRole(
            kind: .sanitary,
            displayName: "Sanitario Test"
        )
        
        // Crear policies para cada rol
        try await createPoliciesForRole(programmerRole.id!, kind: .programmer)
        try await createPoliciesForRole(logisticsRole.id!, kind: .logistics)
        try await createPoliciesForRole(sanitaryRole.id!, kind: .sanitary)
    }
    
    private func createPoliciesForRole(_ roleId: String, kind: RoleKind) async throws {
        // Programmer tiene acceso total
        let hasFull = kind == .programmer
        
        for entity in EntityKind.allCases {
            var canCreate = hasFull
            var canUpdate = hasFull
            var canDelete = hasFull
            let canRead = true // Todos pueden leer
            
            // Lógica específica para Logistics
            if kind == .logistics {
                canCreate = entity != .kit && entity != .user
                canUpdate = entity != .user
                canDelete = entity != .user
            }
            
            // Lógica específica para Sanitary
            if kind == .sanitary {
                canCreate = false
                canUpdate = entity == .kitItem // Solo actualizar stock
                canDelete = false
            }
            
            _ = try await PolicyService.shared.createPolicy(
                roleId: roleId,
                entity: entity,
                canCreate: canCreate,
                canRead: canRead,
                canUpdate: canUpdate,
                canDelete: canDelete
            )
        }
    }
    
    private func createTestUsers() async throws {
        // Crear usuario Programmer (actor para otros tests)
        programmer = UserFS(
            id: "test_programmer_id",
            uid: "test_programmer_uid",
            username: "test_programmer",
            fullName: "Test Programmer",
            email: "programmer@test.com",
            active: true,
            roleId: programmerRole.id
        )
        
        // Guardar en Firestore manualmente para tests
        try db.collection(UserFS.collectionName)
            .document(programmer.id!)
            .setData(from: programmer)
        
        // Los otros usuarios se crearán en los tests
    }
    
    private func cleanupTestData() async {
        // Eliminar usuarios de prueba
        let testUsernames = ["test_programmer", "test_logistics", "test_sanitary", "test_new_user"]
        
        for username in testUsernames {
            do {
                let snapshot = try await db.collection(UserFS.collectionName)
                    .whereField("username", isEqualTo: username)
                    .getDocuments()
                
                for document in snapshot.documents {
                    try await document.reference.delete()
                }
            } catch {
                print("⚠️ Error limpiando usuario '\(username)': \(error)")
            }
        }
        
        // Eliminar roles de prueba
        if let id = programmerRole?.id {
            try? await db.collection(RoleFS.collectionName).document(id).delete()
        }
        if let id = logisticsRole?.id {
            try? await db.collection(RoleFS.collectionName).document(id).delete()
        }
        if let id = sanitaryRole?.id {
            try? await db.collection(RoleFS.collectionName).document(id).delete()
        }
    }
    
    // MARK: - Tests - Create
    
    func testCreateUser_WithPermissions_Succeeds() async throws {
        // Given: Un programador (con permisos)
        let email = "newuser@test.com"
        let password = "Test1234!"
        let username = "test_new_user"
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
        sanitary = UserFS(
            id: "test_sanitary_id",
            uid: "test_sanitary_uid",
            username: "test_sanitary",
            fullName: "Test Sanitary",
            email: "sanitary@test.com",
            active: true,
            roleId: sanitaryRole.id
        )
        
        // When/Then: Intentar crear usuario debe fallar
        do {
            _ = try await service.create(
                email: "fail@test.com",
                password: "Test1234!",
                username: "fail_user",
                fullName: "Fail User",
                roleId: logisticsRole.id!,
                actor: sanitary
            )
            XCTFail("Debería haber lanzado error de autorización")
        } catch UserServiceError.unauthorized {
            // Esperado
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
    }
    
    func testCreateUser_DuplicateUsername_Fails() async throws {
        // Given: Un username que ya existe
        let duplicateUsername = "test_programmer"
        
        // When/Then: Intentar crear con username duplicado debe fallar
        do {
            _ = try await service.create(
                email: "duplicate@test.com",
                password: "Test1234!",
                username: duplicateUsername,
                fullName: "Duplicate User",
                roleId: logisticsRole.id!,
                actor: programmer
            )
            XCTFail("Debería haber lanzado error de username duplicado")
        } catch UserServiceError.usernameTaken(let username) {
            XCTAssertEqual(username, duplicateUsername)
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
    }
    
    // MARK: - Tests - Read
    
    func testGetUserById_ExistingUser_ReturnsUser() async throws {
        // Given: Un usuario existente
        let userId = programmer.id!
        
        // When: Obtener usuario por ID
        let user = await service.getUser(id: userId)
        
        // Then: Usuario encontrado
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.id, userId)
        XCTAssertEqual(user?.username, programmer.username)
    }
    
    func testGetUserById_NonExistingUser_ReturnsNil() async throws {
        // Given: Un ID que no existe
        let fakeId = "fake_id_12345"
        
        // When: Obtener usuario por ID
        let user = await service.getUser(id: fakeId)
        
        // Then: No se encuentra usuario
        XCTAssertNil(user)
    }
    
    func testGetUserByUid_ExistingUser_ReturnsUser() async throws {
        // Given: Un usuario existente
        let uid = programmer.uid
        
        // When: Obtener usuario por UID
        let user = await service.getUser(uid: uid)
        
        // Then: Usuario encontrado
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.uid, uid)
        XCTAssertEqual(user?.username, programmer.username)
    }
    
    func testGetAllUsers_ReturnsActiveUsers() async throws {
        // Given: Usuarios en la base de datos
        // When: Obtener todos los usuarios
        let users = await service.getAllUsers()
        
        // Then: Se devuelven usuarios activos
        XCTAssertFalse(users.isEmpty)
        XCTAssertTrue(users.allSatisfy { $0.active })
    }
    
    func testGetUsersByRole_ReturnsUsersWithRole() async throws {
        // Given: Un rol específico
        let roleId = programmerRole.id!
        
        // When: Obtener usuarios por rol
        let users = await service.getUsersByRole(roleId: roleId)
        
        // Then: Todos los usuarios tienen ese rol
        XCTAssertFalse(users.isEmpty)
        XCTAssertTrue(users.allSatisfy { $0.roleId == roleId })
    }
    
    // MARK: - Tests - Update
    
    func testUpdateUser_WithPermissions_Succeeds() async throws {
        // Given: Un usuario a actualizar
        var userToUpdate = programmer!
        let newFullName = "Updated Name"
        let newUsername = "updated_username"
        
        userToUpdate.fullName = newFullName
        userToUpdate.username = newUsername
        
        // When: Actualizar usuario
        try await service.update(user: userToUpdate, actor: programmer)
        
        // Then: Usuario actualizado
        let updatedUser = await service.getUser(id: programmer.id)
        XCTAssertNotNil(updatedUser)
        XCTAssertEqual(updatedUser?.fullName, newFullName)
        XCTAssertEqual(updatedUser?.username, newUsername)
    }
    
    func testUpdateUser_WithoutPermissions_Fails() async throws {
        // Given: Un sanitario (sin permisos para actualizar usuarios)
        sanitary = UserFS(
            id: "test_sanitary_id",
            uid: "test_sanitary_uid",
            username: "test_sanitary",
            fullName: "Test Sanitary",
            email: "sanitary@test.com",
            active: true,
            roleId: sanitaryRole.id
        )
        
        var userToUpdate = programmer!
        userToUpdate.fullName = "Hacked Name"
        
        // When/Then: Intentar actualizar debe fallar
        do {
            try await service.update(user: userToUpdate, actor: sanitary)
            XCTFail("Debería haber lanzado error de autorización")
        } catch UserServiceError.unauthorized {
            // Esperado
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
    }
    
    func testUpdateUser_DuplicateUsername_Fails() async throws {
        // Given: Crear otro usuario
        let anotherUser = try await service.create(
            email: "another@test.com",
            password: "Test1234!",
            username: "another_user",
            fullName: "Another User",
            roleId: logisticsRole.id!,
            actor: programmer
        )
        
        // Intentar cambiar username al del programmer
        var userToUpdate = anotherUser
        userToUpdate.username = programmer.username
        
        // When/Then: Actualizar con username duplicado debe fallar
        do {
            try await service.update(user: userToUpdate, actor: programmer)
            XCTFail("Debería haber lanzado error de username duplicado")
        } catch UserServiceError.usernameTaken {
            // Esperado
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
    }
    
    // MARK: - Tests - Delete
    
    func testDeleteUser_WithPermissions_Succeeds() async throws {
        // Given: Crear un usuario para eliminar
        let userToDelete = try await service.create(
            email: "todelete@test.com",
            password: "Test1234!",
            username: "to_delete",
            fullName: "To Delete",
            roleId: logisticsRole.id!,
            actor: programmer
        )
        
        let userId = userToDelete.id!
        
        // When: Eliminar usuario
        try await service.delete(userId: userId, actor: programmer)
        
        // Then: Usuario marcado como inactivo
        let deletedUser = await service.getUser(id: userId)
        XCTAssertNotNil(deletedUser)
        XCTAssertFalse(deletedUser!.active)
    }
    
    func testDeleteUser_WithoutPermissions_Fails() async throws {
        // Given: Un sanitario (sin permisos)
        sanitary = UserFS(
            id: "test_sanitary_id",
            uid: "test_sanitary_uid",
            username: "test_sanitary",
            fullName: "Test Sanitary",
            email: "sanitary@test.com",
            active: true,
            roleId: sanitaryRole.id
        )
        
        // When/Then: Intentar eliminar debe fallar
        do {
            try await service.delete(userId: programmer.id!, actor: sanitary)
            XCTFail("Debería haber lanzado error de autorización")
        } catch UserServiceError.unauthorized {
            // Esperado
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
    }
    
    func testDeleteUser_Self_Fails() async throws {
        // Given: Un usuario intentando eliminarse a sí mismo
        // When/Then: Debe fallar
        do {
            try await service.delete(userId: programmer.id!, actor: programmer)
            XCTFail("Debería haber lanzado error de auto-eliminación")
        } catch UserServiceError.cannotDeleteSelf {
            // Esperado
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
    }
    
    // MARK: - Tests - Cache
    
    func testCache_StoresUsers() async throws {
        // Given: Cache limpio
        service.clearCache()
        
        // When: Obtener usuario (primera vez, desde Firestore)
        let user1 = await service.getUser(id: programmer.id)
        
        // Then: Usuario en cache
        XCTAssertNotNil(user1)
        
        // When: Obtener usuario (segunda vez, desde cache)
        let user2 = await service.getUser(id: programmer.id)
        
        // Then: Mismo usuario
        XCTAssertNotNil(user2)
        XCTAssertEqual(user1?.id, user2?.id)
    }
    
    func testClearCache_RemovesUsers() async throws {
        // Given: Usuario en cache
        _ = await service.getUser(id: programmer.id)
        
        // When: Limpiar cache
        service.clearCache()
        
        // Then: Cache vacío (esto se puede verificar con debug helpers)
        // En producción, el cache se llenará automáticamente en la próxima consulta
        #if DEBUG
        service.printCacheStatus()
        #endif
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
        let email = "newemail@test.com"
        
        // When: Verificar si está en uso
        let isTaken = await service.isEmailTaken(email)
        
        // Then: No está en uso
        XCTAssertFalse(isTaken)
    }
    
    func testGetUserCount_ReturnsCorrectCount() async throws {
        // Given: Usuarios en la base de datos
        let initialCount = await service.getUserCount()
        
        // When: Crear un nuevo usuario
        _ = try await service.create(
            email: "count@test.com",
            password: "Test1234!",
            username: "count_user",
            fullName: "Count User",
            roleId: logisticsRole.id!,
            actor: programmer
        )
        
        // Then: El conteo aumenta
        let newCount = await service.getUserCount()
        XCTAssertEqual(newCount, initialCount + 1)
    }
}

// MARK: - Performance Tests

extension UserServiceTests {
    func testPerformance_GetAllUsers() async throws {
        measure {
            Task {
                _ = await service.getAllUsers()
            }
        }
    }
    
    func testPerformance_GetUserWithCache() async throws {
        // Calentar cache
        _ = await service.getUser(id: programmer.id)
        
        measure {
            Task {
                _ = await service.getUser(id: programmer.id)
            }
        }
    }
}
