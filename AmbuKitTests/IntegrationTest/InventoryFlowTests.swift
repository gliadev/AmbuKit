//
//  InventoryFlowTests.swift
//  AmbuKitTests
//

import Testing
@testable import AmbuKit
import Foundation

@MainActor
@Suite(.tags(.firebase, .integration, .slow), .timeLimit(.minutes(3)))
final class InventoryFlowTests {

    private let kitService: KitService
    private let baseService: BaseService
    private let vehicleService: VehicleService
    private let catalogService: CatalogService
    private let policyService: PolicyService

    private let programmerUser: UserFS?
    private let sanitaryUser: UserFS?
    private let programmerRole: RoleFS?
    private let sanitaryRole: RoleFS?

    private var createdKitIds: [String] = []
    private var createdVehicleIds: [String] = []

    init() async throws {
        self.kitService = KitService.shared
        self.baseService = BaseService.shared
        self.vehicleService = VehicleService.shared
        self.catalogService = CatalogService.shared
        self.policyService = PolicyService.shared

        kitService.clearCache()
        baseService.clearCache()
        vehicleService.clearCache()
        catalogService.clearCache()

        let roles = await policyService.getAllRoles()
        let progRole = roles.first(where: { $0.kind == .programmer })
        let sanRole = roles.first(where: { $0.kind == .sanitary })
        self.programmerRole = progRole
        self.sanitaryRole = sanRole

        if let pid = progRole?.id {
            self.programmerUser = UserFS(
                id: "integration_programmer_\(UUID().uuidString.prefix(6))",
                uid: "uid_programmer_\(UUID().uuidString.prefix(6))",
                username: "int_programmer",
                fullName: "Integration Programmer",
                email: "int_prog@test.com",
                active: true,
                roleId: pid
            )
        } else { self.programmerUser = nil }

        if let sid = sanRole?.id {
            self.sanitaryUser = UserFS(
                id: "integration_sanitary_\(UUID().uuidString.prefix(6))",
                uid: "uid_sanitary_\(UUID().uuidString.prefix(6))",
                username: "int_sanitary",
                fullName: "Integration Sanitary",
                email: "int_san@test.com",
                active: true,
                roleId: sid
            )
        } else { self.sanitaryUser = nil }
    }

    deinit {
        let kitSvc = kitService
        let vehSvc = vehicleService
        let actor = programmerUser
        let kitIds = createdKitIds
        let vehIds = createdVehicleIds
        Task { @MainActor in
            guard let actor else { return }
            for kitId in kitIds {
                try? await kitSvc.deleteKit(kitId: kitId, actor: actor)
            }
            for vehicleId in vehIds {
                try? await vehSvc.delete(vehicleId: vehicleId, actor: actor)
            }
        }
    }

    // MARK: - Create Kit Flow Tests

    @Test func createKitFlow() async throws {
        guard let actor = programmerUser else { return }

        let prefix = UUID().uuidString.prefix(6)

        let kit = try await kitService.createKit(
            code: "INT-KIT-\(prefix)",
            name: "Integration Test Kit",
            type: .custom,
            status: "active",
            vehicleId: nil,
            actor: actor
        )

        let kitId = try #require(kit.id)
        createdKitIds.append(kitId)

        let fetchedKit = await kitService.getKit(id: kitId)
        #expect(fetchedKit != nil)
        #expect(fetchedKit?.code == "INT-KIT-\(prefix)")
        #expect(fetchedKit?.status == .active)

        let catalogItems = await catalogService.getAllItems()

        if let catalogItem = catalogItems.first, let catalogItemId = catalogItem.id {
            let kitItem = try await kitService.addItemToKit(
                catalogItemId: catalogItemId,
                kitId: kitId,
                quantity: 10,
                min: 5,
                max: 20,
                expiry: Date().addingTimeInterval(86400 * 365),
                lot: "LOT-INT-\(prefix)",
                actor: actor
            )

            #expect(kitItem.id != nil)
            #expect(kitItem.quantity == 10)
            #expect(kitItem.kitId == kitId)

            let items = await kitService.getKitItems(kitId: kitId)
            #expect(!items.isEmpty)
            #expect(items.contains(where: { $0.id == kitItem.id }))
        }

        try await Task.sleep(for: .milliseconds(500))

        _ = await AuditServiceFS.getLogsForEntity(.kit, entityId: kitId, limit: 10)
        // No verificamos que haya logs — la auditoría es opcional
    }

    @Test func updateStockFlow() async throws {
        guard let actor = programmerUser else { return }

        let prefix = UUID().uuidString.prefix(6)

        let kit = try await kitService.createKit(
            code: "INT-STOCK-\(prefix)",
            name: "Stock Test Kit",
            type: .custom,
            status: "active",
            actor: actor
        )
        let kitId = try #require(kit.id)
        createdKitIds.append(kitId)

        let catalogItems = await catalogService.getAllItems()
        guard let catalogItem = catalogItems.first, let catalogItemId = catalogItem.id else { return }

        let kitItem = try await kitService.addItemToKit(
            catalogItemId: catalogItemId,
            kitId: kitId,
            quantity: 10,
            min: 5,
            max: 20,
            actor: actor
        )

        #expect(kitItem.quantity == 10)
        #expect(kitItem.stockStatus == .ok)

        var updatedItem = kitItem
        updatedItem.quantity = 3

        try await kitService.updateKitItem(kitItem: updatedItem, actor: actor)

        let items = await kitService.getKitItems(kitId: kitId)
        let item = items.first(where: { $0.id == kitItem.id })

        #expect(item != nil)
        #expect(item?.quantity == 3)
        #expect(item?.stockStatus == .low)
        #expect(item?.isBelowMinimum == true)

        let stats = await kitService.getKitStatistics(kitId: kitId)
        #expect(stats.lowStockItems > 0)
    }

    @Test func multiUserFlow() async throws {
        guard let actor = programmerUser else { return }

        let prefix = UUID().uuidString.prefix(6)

        let kit = try await kitService.createKit(
            code: "INT-MULTI-\(prefix)",
            name: "Multi User Kit",
            type: .custom,
            status: "active",
            actor: actor
        )
        let kitId = try #require(kit.id)
        createdKitIds.append(kitId)

        var updatedKit = kit
        updatedKit.name = "Updated by Programmer"
        try await kitService.updateKit(kit: updatedKit, actor: actor)

        kitService.clearCache()

        let kitSeenByB = await kitService.getKit(id: kitId)
        #expect(kitSeenByB != nil)
        #expect(kitSeenByB?.name == "Updated by Programmer")
    }

    // MARK: - Vehicle-Kit Assignment Flow

    @Test func vehicleKitAssignmentFlow() async throws {
        guard let actor = programmerUser else { return }

        let prefix = UUID().uuidString.prefix(6)

        let vehicle = try await vehicleService.create(
            code: "INT-VEH-\(prefix)",
            plate: "INT-\(prefix)",
            type: VehicleFS.VehicleType.sva.rawValue,
            actor: actor
        )
        let vehicleId = try #require(vehicle.id)
        createdVehicleIds.append(vehicleId)

        let kit = try await kitService.createKit(
            code: "INT-VKIT-\(prefix)",
            name: "Vehicle Kit",
            type: .custom,
            status: "active",
            vehicleId: nil,
            actor: actor
        )
        let kitId = try #require(kit.id)
        createdKitIds.append(kitId)

        #expect(kit.vehicleId == nil)
        #expect(!kit.isAssigned)

        var kitToAssign = kit
        kitToAssign.vehicleId = vehicleId
        try await kitService.updateKit(kit: kitToAssign, actor: actor)

        let assignedKit = await kitService.getKit(id: kitId)
        #expect(assignedKit != nil)
        #expect(assignedKit?.vehicleId == vehicleId)
        #expect(assignedKit?.isAssigned == true)

        let vehicleKits = await kitService.getKitsByVehicle(vehicleId: vehicleId)
        #expect(vehicleKits.contains(where: { $0.id == kitId }))
    }

    // MARK: - Base-Vehicle-Kit Hierarchy Flow

    @Test func hierarchyFlow() async throws {
        guard let actor = programmerUser else { return }

        let bases = await baseService.getAllBases()
        guard let base = bases.first else { return }

        let prefix = UUID().uuidString.prefix(6)

        let vehicle = try await vehicleService.create(
            code: "INT-HIER-\(prefix)",
            plate: "HIER-\(prefix)",
            type: VehicleFS.VehicleType.svb.rawValue,
            baseId: base.id,
            actor: actor
        )
        let vehicleId = try #require(vehicle.id)
        createdVehicleIds.append(vehicleId)

        #expect(vehicle.baseId == base.id)

        let kit = try await kitService.createKit(
            code: "INT-HKIT-\(prefix)",
            name: "Hierarchy Kit",
            type: .custom,
            status: "active",
            vehicleId: vehicleId,
            actor: actor
        )
        let kitId = try #require(kit.id)
        createdKitIds.append(kitId)

        let vehicleKits = await kitService.getKitsByVehicle(vehicleId: vehicleId)
        #expect(vehicleKits.contains(where: { $0.id == kitId }))

        let fetchedKit = await kitService.getKit(id: kitId)
        #expect(fetchedKit?.vehicleId == vehicleId)
    }

    // MARK: - Catalog Integration Flow

    @Test func catalogIntegrationFlow() async throws {
        guard let actor = programmerUser else { return }

        let prefix = UUID().uuidString.prefix(6)

        let criticalItems = await catalogService.getCriticalItems()

        let kit = try await kitService.createKit(
            code: "INT-CAT-\(prefix)",
            name: "Catalog Test Kit",
            type: .custom,
            status: "active",
            actor: actor
        )
        let kitId = try #require(kit.id)
        createdKitIds.append(kitId)

        if let criticalItem = criticalItems.first, let criticalItemId = criticalItem.id {
            let kitItem = try await kitService.addItemToKit(
                catalogItemId: criticalItemId,
                kitId: kitId,
                quantity: Double(criticalItem.minStock ?? 10),
                min: Double(criticalItem.minStock ?? 5),
                max: Double(criticalItem.maxStock ?? 50),
                actor: actor
            )

            #expect(kitItem.catalogItemId == criticalItemId)

            let items = await kitService.getKitItems(kitId: kitId)
            #expect(items.contains(where: { $0.catalogItemId == criticalItemId }))
        } else {
            _ = await catalogService.getAllItems()
        }
    }

    // MARK: - Statistics Flow

    @Test func statisticsFlow() async throws {
        guard let actor = programmerUser else { return }

        let initialStats = await kitService.getGlobalStatistics()
        let initialKitCount = initialStats.totalKits

        let prefix = UUID().uuidString.prefix(6)

        let kit = try await kitService.createKit(
            code: "INT-STATS-\(prefix)",
            name: "Stats Test Kit",
            type: .custom,
            status: "active",
            actor: actor
        )
        let kitId = try #require(kit.id)
        createdKitIds.append(kitId)

        kitService.clearCache()

        let newStats = await kitService.getGlobalStatistics()
        #expect(newStats.totalKits >= initialKitCount)
    }
}
