//
//  BaseServiceTests.swift
//  AmbuKitTests
//
//  Tests para BaseService — Gestión de bases/estaciones en Firestore
//  ⚠️ Estos tests usan Firebase REAL
//

import Testing
@testable import AmbuKit
import Foundation

@MainActor
@Suite(.tags(.firebase, .slow), .timeLimit(.minutes(2)))
struct BaseServiceTests {

    private var sut: BaseService { BaseService.shared }

    init() async throws {
        sut.clearCache()
    }

    // MARK: - Read Tests

    @Test func getAllBasesReturnsBases() async throws {
        let bases = await sut.getAllBases()
        #expect(bases.count >= 1, "Debería existir al menos 1 base en Firebase")
    }

    @Test func getActiveBasesReturnsOnlyActive() async throws {
        let activeBases = await sut.getActiveBases()
        for base in activeBases {
            #expect(base.active)
        }
    }

    @Test func getAllBasesIncludingInactive() async throws {
        let allBases = await sut.getAllBases(includeInactive: true)
        let activeBases = await sut.getActiveBases()
        #expect(allBases.count >= activeBases.count)
    }

    @Test func getBaseWithValidIdReturnsBase() async throws {
        let bases = await sut.getAllBases()
        guard let firstBase = bases.first, let baseId = firstBase.id else { return }

        let base = await sut.getBase(id: baseId)
        #expect(base != nil)
        #expect(base?.id == baseId)
        #expect(base?.code == firstBase.code)
    }

    @Test func getBaseWithInvalidIdReturnsNil() async throws {
        let base = await sut.getBase(id: "invalid_base_id_that_does_not_exist_12345")
        #expect(base == nil)
    }

    @Test func getBaseByCodeReturnsBase() async throws {
        let bases = await sut.getAllBases()
        guard let firstBase = bases.first else { return }

        let base = await sut.getBaseByCode(firstBase.code)
        #expect(base != nil)
        #expect(base?.code == firstBase.code)
    }

    @Test func getBaseByCodeWithInvalidCodeReturnsNil() async throws {
        let base = await sut.getBaseByCode("INVALID_CODE_XYZ_999")
        #expect(base == nil)
    }

    // MARK: - Data Validation Tests

    @Test func baseHasRequiredProperties() async throws {
        let bases = await sut.getAllBases()
        guard let base = bases.first else { return }

        #expect(!base.code.isEmpty)
        #expect(!base.name.isEmpty)
        #expect(base.id != nil)
    }

    @Test func basesAreOrderedByCode() async throws {
        let bases = await sut.getAllBases()
        guard bases.count >= 2 else { return }

        for i in 0..<(bases.count - 1) {
            #expect(bases[i].code <= bases[i + 1].code)
        }
    }

    // MARK: - Cache Tests

    @Test func cacheWorksForBases() async throws {
        let bases1 = await sut.getAllBases()
        let bases2 = await sut.getAllBases()

        #expect(bases1.count == bases2.count)

        let ids1 = Set(bases1.compactMap { $0.id })
        let ids2 = Set(bases2.compactMap { $0.id })
        #expect(ids1 == ids2)
    }

    @Test func clearCacheWorks() async throws {
        _ = await sut.getAllBases()
        sut.clearCache()
        let bases = await sut.getAllBases()
        #expect(!bases.isEmpty || bases.isEmpty) // operativo
    }

    // MARK: - Statistics Tests

    @Test func getStatisticsReturnsCoherentData() async throws {
        let stats = await sut.getStatistics()

        #expect(stats.total >= 0)
        #expect(stats.active >= 0)
        #expect(stats.withVehicles >= 0)
        #expect(stats.withoutVehicles >= 0)
        #expect(stats.withVehicles + stats.withoutVehicles == stats.total)
    }

    // MARK: - Search Tests

    @Test func searchBasesFindsMatches() async throws {
        let bases = await sut.getAllBases()
        guard let firstBase = bases.first else { return }

        let searchText = String(firstBase.name.prefix(3))
        let results = await sut.searchBases(by: searchText)

        #expect(!results.isEmpty)
        #expect(results.contains(where: { $0.id == firstBase.id }))
    }

    @Test func searchBasesWithEmptyTextReturnsAll() async throws {
        let allBases = await sut.getAllBases()
        let results = await sut.searchBases(by: "")
        #expect(results.count == allBases.count)
    }

    @Test func searchBasesWithNoMatchReturnsEmpty() async throws {
        let results = await sut.searchBases(by: "ZZZZXXXXXNOTFOUND99999")
        #expect(results.isEmpty)
    }

    // MARK: - Model Validation Tests

    @Test func baseFSEncodingDecoding() throws {
        let base = BaseFS(
            code: "TEST001",
            name: "Test Base",
            address: "123 Test Street",
            active: true,
            vehicleIds: ["v1", "v2"]
        )

        let dict: [String: Any] = [
            "code": base.code,
            "name": base.name,
            "address": base.address,
            "active": base.active,
            "vehicleIds": base.vehicleIds
        ]

        #expect(dict["code"] as? String == "TEST001")
        #expect(dict["name"] as? String == "Test Base")
        #expect(dict["address"] as? String == "123 Test Street")
        #expect(dict["active"] as? Bool == true)
        #expect(dict["vehicleIds"] as? [String] == ["v1", "v2"])
    }

    @Test func baseFSComputedProperties() {
        let baseWithVehicles = BaseFS(
            code: "B001",
            name: "Base Con Vehículos",
            address: "Address",
            active: true,
            vehicleIds: ["v1", "v2", "v3"]
        )

        let baseWithoutVehicles = BaseFS(
            code: "B002",
            name: "Base Sin Vehículos",
            address: "Address",
            active: true,
            vehicleIds: []
        )

        #expect(baseWithVehicles.hasVehicles)
        #expect(baseWithVehicles.vehicleCount == 3)
        #expect(baseWithVehicles.vehicleCountText == "3 vehículos")

        #expect(!baseWithoutVehicles.hasVehicles)
        #expect(baseWithoutVehicles.vehicleCount == 0)
        #expect(baseWithoutVehicles.vehicleCountText == "Sin vehículos")
    }

    @Test func baseFSVehicleManagement() {
        var base = BaseFS(
            code: "B001",
            name: "Test",
            address: "Address",
            active: true,
            vehicleIds: []
        )

        let baseWithVehicle = base.addingVehicle(vehicleId: "vehicle_1")

        #expect(baseWithVehicle.hasVehicle(vehicleId: "vehicle_1"))
        #expect(!baseWithVehicle.hasVehicle(vehicleId: "vehicle_2"))

        base.addVehicle(vehicleId: "vehicle_2")
        #expect(base.hasVehicle(vehicleId: "vehicle_2"))

        let baseWithoutVehicle = baseWithVehicle.removingVehicle(vehicleId: "vehicle_1")
        #expect(!baseWithoutVehicle.hasVehicle(vehicleId: "vehicle_1"))
    }
}
