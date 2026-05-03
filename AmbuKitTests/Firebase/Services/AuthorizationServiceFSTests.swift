//
//  AuthorizationServiceFSTests.swift
//  AmbuKitTests
//

import Testing
@testable import AmbuKit
import Foundation

@MainActor
@Suite(.tags(.firebase, .slow), .timeLimit(.minutes(2)))
struct AuthorizationServiceFSTests {

    private let programmerRoleId: String?
    private let logisticsRoleId: String?
    private let sanitaryRoleId: String?

    init() async throws {
        PolicyService.shared.clearCache()

        let roles = await PolicyService.shared.getAllRoles()
        self.programmerRoleId = roles.first(where: { $0.kind == .programmer })?.id
        self.logisticsRoleId = roles.first(where: { $0.kind == .logistics })?.id
        self.sanitaryRoleId = roles.first(where: { $0.kind == .sanitary })?.id
    }

    // MARK: - canCreateKits Tests

    @Test func canCreateKitsHelper() async throws {
        guard let pid = programmerRoleId, let lid = logisticsRoleId, let sid = sanitaryRoleId else { return }

        let programmer = makeUser(roleId: pid)
        let logistics = makeUser(roleId: lid)
        let sanitary = makeUser(roleId: sid)

        #expect(await AuthorizationServiceFS.canCreateKits(programmer))
        #expect(await AuthorizationServiceFS.canCreateKits(logistics))
        #expect(!(await AuthorizationServiceFS.canCreateKits(sanitary)))
    }

    @Test func canCreateVehiclesHelper() async throws {
        guard let pid = programmerRoleId, let lid = logisticsRoleId, let sid = sanitaryRoleId else { return }

        let programmer = makeUser(roleId: pid)
        let logistics = makeUser(roleId: lid)
        let sanitary = makeUser(roleId: sid)

        #expect(await AuthorizationServiceFS.canCreateVehicles(programmer))
        #expect(await AuthorizationServiceFS.canCreateVehicles(logistics))
        #expect(!(await AuthorizationServiceFS.canCreateVehicles(sanitary)))
    }

    // MARK: - Logistics Tests

    @Test func logisticsCanCreateKits() async throws {
        guard let lid = logisticsRoleId else { return }
        let logistics = makeUser(roleId: lid)
        #expect(await AuthorizationServiceFS.canCreateKits(logistics))
    }

    @Test func logisticsCanCreateVehicles() async throws {
        guard let lid = logisticsRoleId else { return }
        let logistics = makeUser(roleId: lid)
        #expect(await AuthorizationServiceFS.canCreateVehicles(logistics))
    }

    @Test func logisticsCannotManageUsers() async throws {
        guard let lid = logisticsRoleId else { return }
        let logistics = makeUser(roleId: lid)
        #expect(!(await AuthorizationServiceFS.canManageUsers(logistics)))
    }

    // MARK: - Sanitary Tests

    @Test func sanitaryCannotCreateKits() async throws {
        guard let sid = sanitaryRoleId else { return }
        let sanitary = makeUser(roleId: sid)
        #expect(!(await AuthorizationServiceFS.canCreateKits(sanitary)))
    }

    @Test func sanitaryCannotCreateVehicles() async throws {
        guard let sid = sanitaryRoleId else { return }
        let sanitary = makeUser(roleId: sid)
        #expect(!(await AuthorizationServiceFS.canCreateVehicles(sanitary)))
    }

    @Test func sanitaryCanUpdateStock() async throws {
        guard let sid = sanitaryRoleId else { return }
        let sanitary = makeUser(roleId: sid)
        #expect(await AuthorizationServiceFS.canUpdateStock(sanitary))
    }

    // MARK: - Programmer Tests

    @Test func programmerHasFullAccess() async throws {
        guard let pid = programmerRoleId else { return }
        let programmer = makeUser(roleId: pid)

        #expect(await AuthorizationServiceFS.canCreateKits(programmer))
        #expect(await AuthorizationServiceFS.canCreateVehicles(programmer))
        #expect(await AuthorizationServiceFS.canEditThresholds(programmer))
        #expect(await AuthorizationServiceFS.canManageUsers(programmer))
        #expect(await AuthorizationServiceFS.canUpdateStock(programmer))
    }

    // MARK: - UIPermissionsFS Tests

    @Test func uiPermissionsFSCompatibility() async throws {
        guard let lid = logisticsRoleId else { return }
        let logistics = makeUser(roleId: lid)

        #expect(await UIPermissionsFS.canCreateKits(logistics))
        #expect(await UIPermissionsFS.canCreateVehicles(logistics))
        #expect(await UIPermissionsFS.canEditThresholds(logistics))

        let userMgmt = await UIPermissionsFS.userMgmt(logistics)
        #expect(!userMgmt.create)
        #expect(!userMgmt.delete)
    }

    // MARK: - Helper

    private func makeUser(roleId: String) -> UserFS {
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
