//
//  SyncFlowTests.swift
//  AmbuKitTests
//

import Testing
@testable import AmbuKit
import Foundation

@MainActor
@Suite(.tags(.firebase, .integration, .slow), .timeLimit(.minutes(3)))
final class SyncFlowTests {

    private let kitService: KitService
    private let baseService: BaseService
    private let vehicleService: VehicleService
    private let userService: UserService
    private let policyService: PolicyService

    private let programmerUser: UserFS?
    private let programmerRole: RoleFS?

    private var createdKitIds: [String] = []

    init() async throws {
        self.kitService = KitService.shared
        self.baseService = BaseService.shared
        self.vehicleService = VehicleService.shared
        self.userService = UserService.shared
        self.policyService = PolicyService.shared

        kitService.clearCache()
        baseService.clearCache()
        vehicleService.clearCache()
        userService.clearCache()
        policyService.clearCache()

        let roles = await policyService.getAllRoles()
        let role = roles.first(where: { $0.kind == .programmer })
        self.programmerRole = role

        if let role {
            self.programmerUser = UserFS(
                id: "sync_test_user_\(UUID().uuidString.prefix(6))",
                uid: "sync_uid_\(UUID().uuidString.prefix(6))",
                username: "sync_tester",
                fullName: "Sync Test User",
                email: "sync@test.com",
                active: true,
                roleId: role.id
            )
        } else {
            self.programmerUser = nil
        }
    }

    deinit {
        let svc = kitService
        let actor = programmerUser
        let ids = createdKitIds
        Task { @MainActor in
            guard let actor else { return }
            for kitId in ids {
                try? await svc.deleteKit(kitId: kitId, actor: actor)
            }
        }
    }

    // MARK: - Offline/Online Simulation Tests

    @Test func offlineDataAvailability() async throws {
        let kits = await kitService.getAllKits()
        let bases = await baseService.getAllBases()
        let vehicles = await vehicleService.getAllVehicles()

        let cachedKits = await kitService.getAllKits()
        let cachedBases = await baseService.getAllBases()
        let cachedVehicles = await vehicleService.getAllVehicles()

        #expect(cachedKits.count == kits.count)
        #expect(cachedBases.count == bases.count)
        #expect(cachedVehicles.count == vehicles.count)
    }

    @Test func cacheConsistency() async throws {
        guard let actor = programmerUser else { return }

        let prefix = UUID().uuidString.prefix(6)
        let kit = try await kitService.createKit(
            code: "SYNC-\(prefix)",
            name: "Sync Test Kit",
            type: .custom,
            status: "active",
            actor: actor
        )
        let kitId = try #require(kit.id)
        createdKitIds.append(kitId)

        let cachedKit1 = await kitService.getKit(id: kitId)
        #expect(cachedKit1 != nil)
        #expect(cachedKit1?.name == "Sync Test Kit")

        var updatedKit = kit
        updatedKit.name = "Updated Sync Kit"
        try await kitService.updateKit(kit: updatedKit, actor: actor)

        let cachedKit2 = await kitService.getKit(id: kitId)
        #expect(cachedKit2?.name == "Updated Sync Kit")

        kitService.clearCache()

        let freshKit = await kitService.getKit(id: kitId)
        #expect(freshKit?.name == "Updated Sync Kit")
    }

    @Test func reconnectionSync() async throws {
        guard let actor = programmerUser else { return }

        let initialKits = await kitService.getAllKits()
        let initialCount = initialKits.count

        let prefix = UUID().uuidString.prefix(6)

        kitService.clearCache()

        let newKit = try await kitService.createKit(
            code: "SYNC-NEW-\(prefix)",
            name: "New Kit After Reconnect",
            type: .custom,
            status: "active",
            actor: actor
        )
        let newKitId = try #require(newKit.id)
        createdKitIds.append(newKitId)

        kitService.clearCache()

        let syncedKits = await kitService.getAllKits()
        #expect(syncedKits.count >= initialCount)
        #expect(syncedKits.contains(where: { $0.id == newKitId }))
    }

    // MARK: - Conflict Resolution Tests

    @Test func conflictScenario() async throws {
        guard let actor = programmerUser else { return }

        let prefix = UUID().uuidString.prefix(6)

        let kit = try await kitService.createKit(
            code: "CONFLICT-\(prefix)",
            name: "Original Name",
            type: .custom,
            status: "active",
            actor: actor
        )
        let kitId = try #require(kit.id)
        createdKitIds.append(kitId)

        var kitUserA = kit
        kitUserA.name = "Modified by User A"
        try await kitService.updateKit(kit: kitUserA, actor: actor)

        kitService.clearCache()

        let kitUserB = await kitService.getKit(id: kitId)
        #expect(kitUserB?.name == "Modified by User A")

        var kitModifiedByB = try #require(kitUserB)
        kitModifiedByB.name = "Modified by User B"
        try await kitService.updateKit(kit: kitModifiedByB, actor: actor)

        kitService.clearCache()
        let finalKit = await kitService.getKit(id: kitId)
        #expect(finalKit?.name == "Modified by User B")
    }

    @Test func queuedOperations() async throws {
        guard let actor = programmerUser else { return }

        let prefix = UUID().uuidString.prefix(6)

        let kit = try await kitService.createKit(
            code: "QUEUE-\(prefix)",
            name: "Queue Test Kit",
            type: .custom,
            status: "active",
            actor: actor
        )
        let kitId = try #require(kit.id)
        createdKitIds.append(kitId)

        var op1Kit = kit
        op1Kit.name = "After Op 1"
        try await kitService.updateKit(kit: op1Kit, actor: actor)

        var op2Kit = op1Kit
        op2Kit.status = .maintenance
        try await kitService.updateKit(kit: op2Kit, actor: actor)

        var op3Kit = op2Kit
        op3Kit.name = "After Op 3"
        try await kitService.updateKit(kit: op3Kit, actor: actor)

        var op4Kit = op3Kit
        op4Kit.status = .active
        try await kitService.updateKit(kit: op4Kit, actor: actor)

        var op5Kit = op4Kit
        op5Kit.name = "Final Name After Queue"
        try await kitService.updateKit(kit: op5Kit, actor: actor)

        kitService.clearCache()

        let finalKit = await kitService.getKit(id: kitId)
        #expect(finalKit != nil)
        #expect(finalKit?.name == "Final Name After Queue")
        #expect(finalKit?.status == .active)
    }

    // MARK: - Data Integrity Tests

    @Test func dataIntegrity() async throws {
        guard let actor = programmerUser else { return }

        let prefix = UUID().uuidString.prefix(6)

        let originalKit = try await kitService.createKit(
            code: "INTEGRITY-\(prefix)",
            name: "Integrity Test Kit",
            type: .custom,
            status: "active",
            vehicleId: nil,
            actor: actor
        )
        let kitId = try #require(originalKit.id)
        createdKitIds.append(kitId)

        for _ in 1...5 {
            kitService.clearCache()

            let reloadedKit = await kitService.getKit(id: kitId)

            #expect(reloadedKit != nil)
            #expect(reloadedKit?.code == originalKit.code)
            #expect(reloadedKit?.name == originalKit.name)
            #expect(reloadedKit?.type == originalKit.type)
            #expect(reloadedKit?.status == originalKit.status)
        }
    }

    @Test func crossServiceConsistency() async throws {
        let kits = await kitService.getAllKits()
        let vehicles = await vehicleService.getAllVehicles()

        let assignedKits = kits.filter { $0.isAssigned }

        for kit in assignedKits {
            guard let vehicleId = kit.vehicleId else { continue }
            let vehicle = vehicles.first(where: { $0.id == vehicleId })
            #expect(vehicle != nil, "Vehículo \(vehicleId) referenciado por kit \(kit.id ?? "") debería existir")
        }
    }

    // MARK: - Performance Under Sync Tests

    @Test func performanceUnderLoad() async throws {
        guard let actor = programmerUser else { return }

        let prefix = UUID().uuidString.prefix(6)

        var kits: [KitFS] = []

        for i in 1...5 {
            let kit = try await kitService.createKit(
                code: "PERF-\(prefix)-\(i)",
                name: "Performance Kit \(i)",
                type: .custom,
                status: "active",
                actor: actor
            )
            kits.append(kit)
            if let id = kit.id { createdKitIds.append(id) }
        }

        #expect(kits.count == 5)

        kitService.clearCache()

        let start = Date()

        for kit in kits {
            let kitId = try #require(kit.id)
            let loaded = await kitService.getKit(id: kitId)
            #expect(loaded != nil)
        }

        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 10.0)
    }
}
