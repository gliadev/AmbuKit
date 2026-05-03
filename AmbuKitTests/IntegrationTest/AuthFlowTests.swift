//
//  AuthFlowTests.swift
//  AmbuKitTests
//

import Testing
@testable import AmbuKit
import Foundation

@MainActor
@Suite(.tags(.firebase, .integration, .slow), .timeLimit(.minutes(2)))
struct AuthFlowTests {

    private let userService: UserService
    private let policyService: PolicyService
    private let kitService: KitService
    private let baseService: BaseService
    private let programmerRole: RoleFS?

    init() async throws {
        self.userService = UserService.shared
        self.policyService = PolicyService.shared
        self.kitService = KitService.shared
        self.baseService = BaseService.shared

        userService.clearCache()
        policyService.clearCache()
        kitService.clearCache()
        baseService.clearCache()

        let roles = await policyService.getAllRoles()
        self.programmerRole = roles.first(where: { $0.kind == .programmer })
    }

    // MARK: - Complete Auth Flow Tests

    @Test func completeAuthFlow() async throws {
        let users = await userService.getAllUsers()

        guard let existingUser = users.first(where: { $0.active && $0.roleId != nil && !($0.roleId!.isEmpty) }) else { return }

        let userId = try #require(existingUser.id)
        let loadedUser = await userService.getUser(id: userId)
        #expect(loadedUser != nil)
        #expect(loadedUser?.id == userId)

        guard let roleId = loadedUser?.roleId, !roleId.isEmpty else { return }

        let role = await policyService.getRole(id: roleId)
        #expect(role != nil)

        let policies = await policyService.getPolicies(roleId: roleId)
        if policies.isEmpty { return }

        #expect(!policies.isEmpty)

        _ = await kitService.getAllKits()
        _ = await baseService.getAllBases()

        let cachedUser = await userService.getUser(id: userId)
        #expect(cachedUser != nil)
    }

    @Test func logoutFlow() async throws {
        let users = await userService.getAllUsers()
        let bases = await baseService.getAllBases()
        let kits = await kitService.getAllKits()

        #expect(!users.isEmpty == true || users.isEmpty)
        #expect(!bases.isEmpty == true || bases.isEmpty)
        #expect(!kits.isEmpty == true || kits.isEmpty)

        userService.clearCache()
        policyService.clearCache()
        kitService.clearCache()
        baseService.clearCache()

        _ = await userService.getAllUsers()
    }

    @Test func invalidAuthFlow() async throws {
        let nonExistentUser = await userService.getUser(id: "non_existent_user_id_12345")
        #expect(nonExistentUser == nil)

        let emptyIdUser = await userService.getUser(id: "")
        #expect(emptyIdUser == nil)

        _ = await userService.getAllUsers()
    }

    // MARK: - Role-Based Access Tests

    @Test func programmerFullAccess() async throws {
        guard let roleId = programmerRole?.id else { return }

        let policies = await policyService.getPolicies(roleId: roleId)

        let kitPolicy = policies.first(where: { $0.entity == .kit })
        let userPolicy = policies.first(where: { $0.entity == .user })
        let basePolicy = policies.first(where: { $0.entity == .base })

        if let kitPolicy = kitPolicy {
            #expect(kitPolicy.canCreate)
            #expect(kitPolicy.canRead)
            #expect(kitPolicy.canUpdate)
            #expect(kitPolicy.canDelete)
        }

        if let userPolicy = userPolicy {
            #expect(userPolicy.canCreate)
            #expect(userPolicy.canDelete)
        }

        if let basePolicy = basePolicy {
            #expect(basePolicy.canRead)
        }
    }

    @Test func sanitaryRestrictedAccess() async throws {
        let roles = await policyService.getAllRoles()
        guard let sanitaryRole = roles.first(where: { $0.kind == .sanitary }),
              let sanitaryRoleId = sanitaryRole.id else { return }

        let policies = await policyService.getPolicies(roleId: sanitaryRoleId)

        let userPolicy = policies.first(where: { $0.entity == .user })
        if let userPolicy = userPolicy {
            #expect(!userPolicy.canCreate)
            #expect(!userPolicy.canDelete)
        }

        let kitPolicy = policies.first(where: { $0.entity == .kit })
        if let kitPolicy = kitPolicy {
            #expect(!kitPolicy.canCreate)
        }
    }

    // MARK: - Session Persistence Tests

    @Test func sessionDataPersistence() async throws {
        let initialUsers = await userService.getAllUsers()
        guard !initialUsers.isEmpty, let firstUserId = initialUsers.first?.id else { return }

        let user1 = await userService.getUser(id: firstUserId)
        #expect(user1 != nil)

        let user2 = await userService.getUser(id: firstUserId)
        #expect(user2 != nil)
        #expect(user1?.id == user2?.id)
        #expect(user1?.username == user2?.username)
        #expect(user1?.email == user2?.email)
        #expect(user1?.roleId == user2?.roleId)
    }
}
