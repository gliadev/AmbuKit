//
//  PolicyServiceTests.swift
//  AmbuKitTests
//
//  Tests para PolicyService - Gestión de roles y políticas en Firestore
//  ⚠️ Estos tests usan Firebase REAL
//

import Testing
@testable import AmbuKit
import Foundation

@MainActor
@Suite(.tags(.firebase, .slow), .timeLimit(.minutes(2)))
struct PolicyServiceTests {

    private var sut: PolicyService { PolicyService.shared }

    init() async throws {
        sut.clearCache()
    }

    // MARK: - Roles Tests

    @Test func getAllRolesReturnsThreeRoles() async throws {
        let roles = await sut.getAllRoles()
        #expect(roles.count >= 3, "Deberían existir al menos 3 roles base")
    }

    @Test("Existe rol", arguments: [RoleKind.programmer, .logistics, .sanitary])
    func roleExists(_ kind: RoleKind) async throws {
        let roles = await sut.getAllRoles()
        let role = roles.first(where: { $0.kind == kind })
        #expect(role != nil, "Debería existir el rol \(kind)")
        #expect(role?.kind == kind)
    }

    @Test func getRoleWithValidIdReturnsRole() async throws {
        let roles = await sut.getAllRoles()
        guard let firstRole = roles.first, let roleId = firstRole.id else { return }

        let role = await sut.getRole(id: roleId)
        #expect(role != nil)
        #expect(role?.id == roleId)
    }

    @Test func getRoleWithInvalidIdReturnsNil() async throws {
        let role = await sut.getRole(id: "invalid_role_id_that_does_not_exist_12345")
        #expect(role == nil)
    }

    @Test func getRoleWithNilIdReturnsNil() async throws {
        let role = await sut.getRole(id: nil)
        #expect(role == nil)
    }

    @Test func getRoleWithEmptyIdReturnsNil() async throws {
        let role = await sut.getRole(id: "")
        #expect(role == nil)
    }

    // MARK: - Policies Tests

    @Test func getPoliciesForValidRoleReturnsPolicies() async throws {
        let roles = await sut.getAllRoles()
        guard let logisticsRole = roles.first(where: { $0.kind == .logistics }),
              let roleId = logisticsRole.id else { return }

        let policies = await sut.getPolicies(roleId: roleId)
        #expect(!policies.isEmpty)
    }

    @Test func getPoliciesForInvalidRoleReturnsEmpty() async throws {
        let policies = await sut.getPolicies(roleId: "invalid_role_id_xyz")
        #expect(policies.isEmpty)
    }

    @Test func getPoliciesWithNilRoleIdReturnsEmpty() async throws {
        let policies = await sut.getPolicies(roleId: nil)
        #expect(policies.isEmpty)
    }

    @Test func getPolicyForSpecificEntityReturnsPolicy() async throws {
        let roles = await sut.getAllRoles()
        guard let logisticsRole = roles.first(where: { $0.kind == .logistics }),
              let roleId = logisticsRole.id else { return }

        let policy = await sut.getPolicy(roleId: roleId, entity: .kit)
        #expect(policy != nil)
        #expect(policy?.entity == .kit)
    }

    // MARK: - Cache Tests

    @Test func cacheWorksForRoles() async throws {
        let roles1 = await sut.getAllRoles()
        let roles2 = await sut.getAllRoles()

        #expect(roles1.count == roles2.count)

        let ids1 = Set(roles1.compactMap { $0.id })
        let ids2 = Set(roles2.compactMap { $0.id })
        #expect(ids1 == ids2)
    }

    @Test func clearCacheWorks() async throws {
        _ = await sut.getAllRoles()
        sut.clearCache()
        let roles = await sut.getAllRoles()
        #expect(!roles.isEmpty)
    }

    @Test func clearCacheForSpecificRoleWorks() async throws {
        let roles = await sut.getAllRoles()
        guard let firstRole = roles.first, let roleId = firstRole.id else { return }

        _ = await sut.getRole(id: roleId)
        sut.clearCache(forRole: roleId)
        let role = await sut.getRole(id: roleId)
        #expect(role != nil)
    }

    // MARK: - Helper Methods Tests

    @Test("isProgrammer/isLogistics/isSanitary helpers", arguments: [RoleKind.programmer, .logistics, .sanitary])
    func helperByKind(_ kind: RoleKind) async throws {
        let roles = await sut.getAllRoles()
        guard let role = roles.first(where: { $0.kind == kind }),
              let roleId = role.id else { return }

        let user = UserFS(
            uid: "test-\(kind)",
            username: "test_\(kind)",
            fullName: "Test \(kind)",
            email: "\(kind)@test.com",
            roleId: roleId
        )

        switch kind {
        case .programmer:
            #expect(await sut.isProgrammer(user))
        case .logistics:
            #expect(await sut.isLogistics(user))
        case .sanitary:
            #expect(await sut.isSanitary(user))
        }
    }

    @Test func getRoleKindHelper() async throws {
        let roles = await sut.getAllRoles()
        guard let programmerRole = roles.first(where: { $0.kind == .programmer }),
              let roleId = programmerRole.id else { return }

        let user = UserFS(
            uid: "test-user",
            username: "test_user",
            fullName: "Test User",
            email: "user@test.com",
            roleId: roleId
        )

        let kind = await sut.getRoleKind(for: user)
        #expect(kind == .programmer)
    }

    @Test func getRoleKindForUserWithoutRoleReturnsNil() async throws {
        let user = UserFS(
            uid: "test-user",
            username: "test_user",
            fullName: "Test User",
            email: "user@test.com",
            roleId: nil
        )

        let kind = await sut.getRoleKind(for: user)
        #expect(kind == nil)
    }
}
