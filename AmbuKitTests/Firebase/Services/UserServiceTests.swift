//
//  UserServiceTests.swift
//  AmbuKitTests
//
//  Tests para UserService
//  ⚠️ Estos tests usan Firebase REAL
//

import Testing
@testable import AmbuKit
import Foundation
import FirebaseCore
import FirebaseFirestore

@MainActor
@Suite(.tags(.firebase, .slow), .timeLimit(.minutes(2)))
final class UserServiceTests {

    private let service: UserService
    private let db: Firestore

    private var programmer: UserFS!
    private var logistics: UserFS!
    private var sanitary: UserFS!

    private let programmerRole: RoleFS?
    private let logisticsRole: RoleFS?
    private let sanitaryRole: RoleFS?

    private var createdUserIds: [String] = []

    init() async throws {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        self.service = UserService.shared
        self.db = Firestore.firestore()
        service.clearCache()

        let roles = await PolicyService.shared.getAllRoles()
        self.programmerRole = roles.first(where: { $0.kind == .programmer })
        self.logisticsRole = roles.first(where: { $0.kind == .logistics })
        self.sanitaryRole = roles.first(where: { $0.kind == .sanitary })

        guard let programmerRoleId = programmerRole?.id else { return }

        let testId = "test_programmer_\(UUID().uuidString.prefix(6))"
        let user = UserFS(
            id: testId,
            uid: "test_prog_uid_\(UUID().uuidString.prefix(6))",
            username: "test_programmer_\(UUID().uuidString.prefix(6))",
            fullName: "Test Programmer",
            email: "programmer_\(UUID().uuidString.prefix(6))@test.com",
            active: true,
            roleId: programmerRoleId
        )

        try db.collection(UserFS.collectionName)
            .document(testId)
            .setData(from: user)

        self.programmer = user
    }

    deinit {
        let ids = createdUserIds
        let programmer = self.programmer
        let database = db
        Task { @MainActor in
            for userId in ids {
                try? await database.collection(UserFS.collectionName).document(userId).delete()
            }
            if let pid = programmer?.id {
                try? await database.collection(UserFS.collectionName).document(pid).delete()
            }
        }
    }

    // MARK: - Helper

    private func makeTestUser(
        username: String,
        fullName: String,
        email: String,
        roleId: String?,
        active: Bool = true
    ) -> UserFS {
        UserFS(
            id: "test_user_\(UUID().uuidString.prefix(6))",
            uid: "test_uid_\(UUID().uuidString.prefix(6))",
            username: username,
            fullName: fullName,
            email: email,
            active: active,
            roleId: roleId
        )
    }

    // MARK: - Create Tests

    @Test func createUser_WithPermissions_Succeeds() async throws {
        guard let logisticsRoleId = logisticsRole?.id, let actor = programmer else { return }

        let suffix = UUID().uuidString.prefix(6)
        let email = "newuser_\(suffix)@test.com"
        let username = "test_new_user_\(suffix)"
        let fullName = "New Test User"

        let newUser = try await service.create(
            email: email,
            password: "Test1234!",
            username: username,
            fullName: fullName,
            roleId: logisticsRoleId,
            actor: actor
        )

        if let id = newUser.id { createdUserIds.append(id) }

        #expect(newUser.id != nil)
        #expect(newUser.username == username)
        #expect(newUser.email == email)
        #expect(newUser.fullName == fullName)
        #expect(newUser.active)
        #expect(newUser.roleId == logisticsRoleId)

        let savedUser = await service.getUser(id: newUser.id)
        #expect(savedUser != nil)
        #expect(savedUser?.username == username)
    }

    @Test func createUser_WithoutPermissions_Fails() async throws {
        guard let sanitaryRoleId = sanitaryRole?.id,
              let logisticsRoleId = logisticsRole?.id else { return }

        sanitary = makeTestUser(
            username: "test_sanitary_\(UUID().uuidString.prefix(6))",
            fullName: "Test Sanitary",
            email: "sanitary_\(UUID().uuidString.prefix(6))@test.com",
            roleId: sanitaryRoleId
        )

        await #expect(throws: (any Error).self) {
            let user = try await self.service.create(
                email: "fail_\(UUID().uuidString.prefix(6))@test.com",
                password: "Test1234!",
                username: "fail_user_\(UUID().uuidString.prefix(6))",
                fullName: "Fail User",
                roleId: logisticsRoleId,
                actor: self.sanitary
            )
            if let id = user.id { self.createdUserIds.append(id) }
        }
    }

    @Test func createUser_DuplicateUsername_Fails() async throws {
        guard let logisticsRoleId = logisticsRole?.id, let actor = programmer else { return }

        let suffix = UUID().uuidString.prefix(6)
        let duplicateUsername = "test_dup_\(suffix)"

        let first = try await service.create(
            email: "first_\(suffix)@test.com",
            password: "Test1234!",
            username: duplicateUsername,
            fullName: "First User",
            roleId: logisticsRoleId,
            actor: actor
        )
        if let id = first.id { createdUserIds.append(id) }

        await #expect(throws: (any Error).self) {
            let user = try await self.service.create(
                email: "duplicate_\(suffix)@test.com",
                password: "Test1234!",
                username: duplicateUsername,
                fullName: "Duplicate User",
                roleId: logisticsRoleId,
                actor: actor
            )
            if let id = user.id { self.createdUserIds.append(id) }
        }
    }

    // MARK: - Read Tests

    @Test func getUser_ExistingUser_ReturnsUser() async throws {
        guard let userId = programmer?.id else { return }

        let user = await service.getUser(id: userId)
        #expect(user != nil)
        #expect(user?.id == userId)
    }

    @Test func getUser_NonExistingUser_ReturnsNil() async throws {
        let user = await service.getUser(id: "nonexistent_user_id_12345")
        #expect(user == nil)
    }

    @Test func getAllUsers_ReturnsUsers() async throws {
        let users = await service.getAllUsers()
        #expect(!users.isEmpty)
    }

    @Test func getAllUsers_ReturnsOnlyActiveUsers() async throws {
        let users = await service.getAllUsers()
        #expect(users.allSatisfy { $0.active })
    }

    @Test func getUsersByRole_ReturnsUsersWithRole() async throws {
        guard let roleId = programmerRole?.id else { return }

        let users = await service.getUsersByRole(roleId: roleId)
        for user in users {
            #expect(user.roleId == roleId)
        }
    }

    // MARK: - Update Tests

    @Test func updateUser_WithPermissions_Succeeds() async throws {
        guard let logisticsRoleId = logisticsRole?.id, let actor = programmer else { return }

        let suffix = UUID().uuidString.prefix(6)
        let originalUser = try await service.create(
            email: "update_\(suffix)@test.com",
            password: "Test1234!",
            username: "update_user_\(suffix)",
            fullName: "Original Name",
            roleId: logisticsRoleId,
            actor: actor
        )

        let userId = try #require(originalUser.id)
        createdUserIds.append(userId)

        let updatedUser = UserFS(
            id: userId,
            uid: originalUser.uid,
            username: "updated_user_\(suffix)",
            fullName: "Updated Name",
            email: originalUser.email,
            active: originalUser.active,
            roleId: originalUser.roleId,
            baseId: originalUser.baseId,
            createdAt: originalUser.createdAt,
            updatedAt: Date()
        )

        try await service.update(user: updatedUser, actor: actor)

        let fetched = await service.getUser(id: userId)
        #expect(fetched != nil)
        #expect(fetched?.fullName == "Updated Name")
        #expect(fetched?.username == "updated_user_\(suffix)")
    }

    @Test func updateUser_WithoutPermissions_Fails() async throws {
        guard let sanitaryRoleId = sanitaryRole?.id, let prog = programmer else { return }

        sanitary = makeTestUser(
            username: "test_san_\(UUID().uuidString.prefix(6))",
            fullName: "Test Sanitary",
            email: "san_\(UUID().uuidString.prefix(6))@test.com",
            roleId: sanitaryRoleId
        )

        let hackedUser = UserFS(
            id: prog.id,
            uid: prog.uid,
            username: prog.username,
            fullName: "Hacked Name",
            email: prog.email,
            active: prog.active,
            roleId: prog.roleId,
            baseId: prog.baseId,
            createdAt: prog.createdAt,
            updatedAt: Date()
        )

        await #expect(throws: (any Error).self) {
            try await self.service.update(user: hackedUser, actor: self.sanitary)
        }
    }

    @Test func updateUser_DuplicateUsername_Fails() async throws {
        guard let logisticsRoleId = logisticsRole?.id, let actor = programmer else { return }

        let suffix1 = UUID().uuidString.prefix(6)
        let suffix2 = UUID().uuidString.prefix(6)

        let user1 = try await service.create(
            email: "user1_\(suffix1)@test.com",
            password: "Test1234!",
            username: "user1_\(suffix1)",
            fullName: "User 1",
            roleId: logisticsRoleId,
            actor: actor
        )
        if let id = user1.id { createdUserIds.append(id) }

        let user2 = try await service.create(
            email: "user2_\(suffix2)@test.com",
            password: "Test1234!",
            username: "user2_\(suffix2)",
            fullName: "User 2",
            roleId: logisticsRoleId,
            actor: actor
        )
        let user2Id = try #require(user2.id)
        createdUserIds.append(user2Id)

        let conflictingUser = UserFS(
            id: user2Id,
            uid: user2.uid,
            username: "user1_\(suffix1)",
            fullName: user2.fullName,
            email: user2.email,
            active: user2.active,
            roleId: user2.roleId,
            baseId: user2.baseId,
            createdAt: user2.createdAt,
            updatedAt: Date()
        )

        await #expect(throws: (any Error).self) {
            try await self.service.update(user: conflictingUser, actor: actor)
        }
    }

    // MARK: - Delete Tests

    @Test func deleteUser_WithPermissions_Succeeds() async throws {
        guard let logisticsRoleId = logisticsRole?.id, let actor = programmer else { return }

        let suffix = UUID().uuidString.prefix(6)
        let userToDelete = try await service.create(
            email: "todelete_\(suffix)@test.com",
            password: "Test1234!",
            username: "to_delete_\(suffix)",
            fullName: "To Delete",
            roleId: logisticsRoleId,
            actor: actor
        )

        let userId = try #require(userToDelete.id)

        try await service.delete(userId: userId, actor: actor)

        let deletedUser = await service.getUser(id: userId)
        if let user = deletedUser {
            #expect(!user.active)
        }
    }

    @Test func deleteUser_WithoutPermissions_Fails() async throws {
        guard let sanitaryRoleId = sanitaryRole?.id, let actorId = programmer?.id else { return }

        sanitary = makeTestUser(
            username: "test_san_\(UUID().uuidString.prefix(6))",
            fullName: "Test Sanitary",
            email: "san_\(UUID().uuidString.prefix(6))@test.com",
            roleId: sanitaryRoleId
        )

        await #expect(throws: (any Error).self) {
            try await self.service.delete(userId: actorId, actor: self.sanitary)
        }
    }

    @Test func deleteUser_Self_Fails() async throws {
        guard let prog = programmer, let actorId = prog.id else { return }

        await #expect(throws: (any Error).self) {
            try await self.service.delete(userId: actorId, actor: prog)
        }
    }

    // MARK: - Cache Tests

    @Test func cache_StoresUsers() async throws {
        guard let userId = programmer?.id else { return }

        service.clearCache()
        let user1 = await service.getUser(id: userId)
        #expect(user1 != nil)

        let user2 = await service.getUser(id: userId)
        #expect(user2 != nil)
        #expect(user1?.id == user2?.id)
    }

    @Test func clearCache_Works() async throws {
        guard let userId = programmer?.id else { return }

        _ = await service.getUser(id: userId)
        service.clearCache()
        let user = await service.getUser(id: userId)
        #expect(user != nil)
    }

    // MARK: - Helpers

    @Test func isEmailTaken_ExistingEmail_ReturnsTrue() async throws {
        guard let email = programmer?.email else { return }

        let isTaken = await service.isEmailTaken(email)
        #expect(isTaken)
    }

    @Test func isEmailTaken_NewEmail_ReturnsFalse() async throws {
        let email = "newemail_\(UUID().uuidString.prefix(8))@test.com"
        let isTaken = await service.isEmailTaken(email)
        #expect(!isTaken)
    }

    @Test func getUserCount_ReturnsPositiveNumber() async throws {
        let count = await service.getUserCount()
        #expect(count >= 1)
    }
}
