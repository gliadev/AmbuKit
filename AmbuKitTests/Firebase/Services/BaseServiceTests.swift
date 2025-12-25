//
//  BaseServiceTests.swift
//  AmbuKitTests
//
//  Created by Adolfo on 20/12/25.
//
//
//  Tests para BaseService - Gestión de bases/estaciones en Firestore
//  ⚠️ IMPORTANTE: Estos tests usan Firebase REAL (sin emulator)
//  Los tests de LECTURA son seguros, los de ESCRITURA están comentados
//

import XCTest
@testable import AmbuKit

/// Tests para verificar el funcionamiento de BaseService
/// Incluye tests de lectura, caché y validación de datos
@MainActor
final class BaseServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Referencia al servicio (singleton)
    private var sut: BaseService { BaseService.shared }
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        // Limpiar caché antes de cada test
        sut.clearCache()
    }
    
    override func tearDown() async throws {
        // Limpiar caché después de cada test
        sut.clearCache()
        try await super.tearDown()
    }
    
    // MARK: - Read Tests (Safe)
    
    /// Verifica que getAllBases devuelve bases
    func testGetAllBasesReturnsBases() async throws {
        // When
        let bases = await sut.getAllBases()
        
        // Then
        // Según seed data debería haber al menos 5 bases (Bilbao 1,2,3, Trapaga, Ortuella)
        XCTAssertGreaterThanOrEqual(
            bases.count, 1,
            "Debería existir al menos 1 base en Firebase"
        )
    }
    
    /// Verifica que getActiveBases solo devuelve bases activas
    func testGetActiveBasesReturnsOnlyActive() async throws {
        // When
        let activeBases = await sut.getActiveBases()
        
        // Then
        for base in activeBases {
            XCTAssertTrue(base.active, "Todas las bases devueltas deberían estar activas")
        }
    }
    
    /// Verifica que getAllBases con includeInactive=true incluye todas
    func testGetAllBasesIncludingInactive() async throws {
        // When
        let allBases = await sut.getAllBases(includeInactive: true)
        let activeBases = await sut.getActiveBases()
        
        // Then
        XCTAssertGreaterThanOrEqual(
            allBases.count,
            activeBases.count,
            "getAllBases(includeInactive: true) debería devolver >= que getActiveBases()"
        )
    }
    
    /// Verifica que getBase con ID válido devuelve la base
    func testGetBaseWithValidIdReturnsBase() async throws {
        // Given: Obtener una base existente
        let bases = await sut.getAllBases()
        guard let firstBase = bases.first, let baseId = firstBase.id else {
            throw XCTSkip("No hay bases disponibles en Firebase")
        }
        
        // When
        let base = await sut.getBase(id: baseId)
        
        // Then
        XCTAssertNotNil(base)
        XCTAssertEqual(base?.id, baseId)
        XCTAssertEqual(base?.code, firstBase.code)
    }
    
    /// Verifica que getBase con ID inválido devuelve nil
    func testGetBaseWithInvalidIdReturnsNil() async throws {
        // When
        let base = await sut.getBase(id: "invalid_base_id_that_does_not_exist_12345")
        
        // Then
        XCTAssertNil(base, "Debería devolver nil para ID inválido")
    }
    
    /// Verifica que getBaseByCode funciona correctamente
    func testGetBaseByCodeReturnsBase() async throws {
        // Given: Obtener una base existente
        let bases = await sut.getAllBases()
        guard let firstBase = bases.first else {
            throw XCTSkip("No hay bases disponibles en Firebase")
        }
        
        // When
        let base = await sut.getBaseByCode(firstBase.code)
        
        // Then
        XCTAssertNotNil(base)
        XCTAssertEqual(base?.code, firstBase.code)
    }
    
    /// Verifica que getBaseByCode con código inválido devuelve nil
    func testGetBaseByCodeWithInvalidCodeReturnsNil() async throws {
        // When
        let base = await sut.getBaseByCode("INVALID_CODE_XYZ_999")
        
        // Then
        XCTAssertNil(base, "Debería devolver nil para código inválido")
    }
    
    // MARK: - Data Validation Tests
    
    /// Verifica que las bases tienen propiedades requeridas
    func testBaseHasRequiredProperties() async throws {
        // Given
        let bases = await sut.getAllBases()
        guard let base = bases.first else {
            throw XCTSkip("No hay bases disponibles en Firebase")
        }
        
        // Then
        XCTAssertFalse(base.code.isEmpty, "Base debería tener código")
        XCTAssertFalse(base.name.isEmpty, "Base debería tener nombre")
        XCTAssertNotNil(base.id, "Base debería tener ID")
    }
    
    /// Verifica que las bases están ordenadas por código
    func testBasesAreOrderedByCode() async throws {
        // When
        let bases = await sut.getAllBases()
        
        guard bases.count >= 2 else {
            throw XCTSkip("Se necesitan al menos 2 bases para verificar orden")
        }
        
        // Then: Verificar que están ordenadas
        for i in 0..<(bases.count - 1) {
            XCTAssertLessThanOrEqual(
                bases[i].code,
                bases[i + 1].code,
                "Las bases deberían estar ordenadas por código"
            )
        }
    }
    
    // MARK: - Cache Tests
    
    /// Verifica que el caché funciona para bases
    func testCacheWorksForBases() async throws {
        // Given: Primera llamada (sin caché)
        let bases1 = await sut.getAllBases()
        
        // When: Segunda llamada (debería usar caché)
        let bases2 = await sut.getAllBases()
        
        // Then
        XCTAssertEqual(bases1.count, bases2.count)
        
        let ids1 = Set(bases1.compactMap { $0.id })
        let ids2 = Set(bases2.compactMap { $0.id })
        XCTAssertEqual(ids1, ids2, "Las bases del caché deberían coincidir")
    }
    
    /// Verifica que clearCache funciona
    func testClearCacheWorks() async throws {
        // Given: Cargar datos en caché
        _ = await sut.getAllBases()
        
        // When: Limpiar caché
        sut.clearCache()
        
        // Then: Debería poder obtener bases de nuevo
        let bases = await sut.getAllBases()
        XCTAssertNotNil(bases)
    }
    
    /// Verifica que clearCache para base específica funciona
    func testClearCacheForSpecificBaseWorks() async throws {
        // Given: Cargar una base en caché
        let bases = await sut.getAllBases()
        guard let firstBase = bases.first, let baseId = firstBase.id else {
            throw XCTSkip("No hay bases disponibles")
        }
        
        _ = await sut.getBase(id: baseId)
        
        // When: Limpiar caché solo de esa base
        sut.clearCache(forBase: baseId)
        
        // Then: Debería poder obtener la base de nuevo
        let base = await sut.getBase(id: baseId)
        XCTAssertNotNil(base)
    }
    
    // MARK: - Vehicle Relationship Tests
    
    /// Verifica el método getBasesWithVehicles
    func testGetBasesWithVehicles() async throws {
        // When
        let basesWithVehicles = await sut.getBasesWithVehicles()
        
        // Then: Todas deberían tener vehículos
        for base in basesWithVehicles {
            XCTAssertTrue(
                base.hasVehicles,
                "Base '\(base.name)' debería tener vehículos"
            )
        }
    }
    
    /// Verifica el método getBasesWithoutVehicles
    func testGetBasesWithoutVehicles() async throws {
        // When
        let basesWithoutVehicles = await sut.getBasesWithoutVehicles()
        
        // Then: Ninguna debería tener vehículos
        for base in basesWithoutVehicles {
            XCTAssertFalse(
                base.hasVehicles,
                "Base '\(base.name)' no debería tener vehículos"
            )
        }
    }
    
    // MARK: - Statistics Tests
    
    /// Verifica que getStatistics devuelve datos coherentes
    func testGetStatisticsReturnsCoherentData() async throws {
        // When
        let stats = await sut.getStatistics()
        
        // Then
        XCTAssertGreaterThanOrEqual(stats.total, 0, "Total no puede ser negativo")
        XCTAssertGreaterThanOrEqual(stats.active, 0, "Active no puede ser negativo")
        XCTAssertGreaterThanOrEqual(stats.withVehicles, 0)
        XCTAssertGreaterThanOrEqual(stats.withoutVehicles, 0)
        
        // La suma de con/sin vehículos debería ser igual al total
        XCTAssertEqual(
            stats.withVehicles + stats.withoutVehicles,
            stats.total,
            "La suma de bases con y sin vehículos debería igualar el total"
        )
    }
    
    // MARK: - Search Tests
    
    /// Verifica que searchBases funciona
    func testSearchBasesFindsMatches() async throws {
        // Given: Obtener una base existente
        let bases = await sut.getAllBases()
        guard let firstBase = bases.first else {
            throw XCTSkip("No hay bases disponibles")
        }
        
        // When: Buscar por parte del nombre
        let searchText = String(firstBase.name.prefix(3))
        let results = await sut.searchBases(by: searchText)
        
        // Then
        XCTAssertFalse(results.isEmpty, "Debería encontrar resultados")
        XCTAssertTrue(
            results.contains(where: { $0.id == firstBase.id }),
            "Debería encontrar la base buscada"
        )
    }
    
    /// Verifica que searchBases con texto vacío devuelve todo
    func testSearchBasesWithEmptyTextReturnsAll() async throws {
        // Given
        let allBases = await sut.getAllBases()
        
        // When
        let results = await sut.searchBases(by: "")
        
        // Then
        XCTAssertEqual(results.count, allBases.count)
    }
    
    /// Verifica que searchBases con texto no encontrado devuelve vacío
    func testSearchBasesWithNoMatchReturnsEmpty() async throws {
        // When
        let results = await sut.searchBases(by: "ZZZZXXXXXNOTFOUND99999")
        
        // Then
        XCTAssertTrue(results.isEmpty, "No debería encontrar resultados")
    }
    
    // MARK: - Model Validation Tests
    
    /// Verifica que BaseFS se puede codificar/decodificar
    func testBaseFSEncodingDecoding() throws {
        // Given
        let base = BaseFS(
            code: "TEST001",
            name: "Test Base",
            address: "123 Test Street",
            active: true,
            vehicleIds: ["v1", "v2"]
        )
        
        // When: Codificar a JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(base)
        
        // Then: Decodificar
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BaseFS.self, from: data)
        
        XCTAssertEqual(base.code, decoded.code)
        XCTAssertEqual(base.name, decoded.name)
        XCTAssertEqual(base.address, decoded.address)
        XCTAssertEqual(base.active, decoded.active)
        XCTAssertEqual(base.vehicleIds, decoded.vehicleIds)
    }
    
    /// Verifica computed properties de BaseFS
    func testBaseFSComputedProperties() {
        // Given: Base con vehículos
        let baseWithVehicles = BaseFS(
            code: "B001",
            name: "Base Con Vehículos",
            address: "Address",
            active: true,
            vehicleIds: ["v1", "v2", "v3"]
        )
        
        // Given: Base sin vehículos
        let baseWithoutVehicles = BaseFS(
            code: "B002",
            name: "Base Sin Vehículos",
            address: "Address",
            active: true,
            vehicleIds: []
        )
        
        // Then
        XCTAssertTrue(baseWithVehicles.hasVehicles)
        XCTAssertEqual(baseWithVehicles.vehicleCount, 3)
        XCTAssertEqual(baseWithVehicles.vehicleCountText, "3 vehículos")
        
        XCTAssertFalse(baseWithoutVehicles.hasVehicles)
        XCTAssertEqual(baseWithoutVehicles.vehicleCount, 0)
        XCTAssertEqual(baseWithoutVehicles.vehicleCountText, "Sin vehículos")
    }
    
    /// Verifica métodos de gestión de vehículos en BaseFS
    func testBaseFSVehicleManagement() {
        // Given
        var base = BaseFS(
            code: "B001",
            name: "Test",
            address: "Address",
            active: true,
            vehicleIds: []
        )
        
        // When: Añadir vehículo
        let baseWithVehicle = base.addingVehicle(vehicleId: "vehicle_1")
        
        // Then
        XCTAssertTrue(baseWithVehicle.hasVehicle(vehicleId: "vehicle_1"))
        XCTAssertFalse(baseWithVehicle.hasVehicle(vehicleId: "vehicle_2"))
        
        // When: Añadir otro vehículo (mutating)
        base.addVehicle(vehicleId: "vehicle_2")
        
        // Then
        XCTAssertTrue(base.hasVehicle(vehicleId: "vehicle_2"))
        
        // When: Eliminar vehículo
        let baseWithoutVehicle = baseWithVehicle.removingVehicle(vehicleId: "vehicle_1")
        
        // Then
        XCTAssertFalse(baseWithoutVehicle.hasVehicle(vehicleId: "vehicle_1"))
    }
    
    // MARK: - Destructive Tests (COMENTADOS - Solo para ambiente de prueba)
    
    /*
    /// ⚠️ TEST DESTRUCTIVO - Descomentar solo en ambiente de prueba
    func testCreateBase() async throws {
        // Given
        let programmer = try await createProgrammerUser()
        
        // When
        let newBase = try await sut.create(
            code: "test_base_\(UUID().uuidString.prefix(6))",
            name: "Test Base (eliminar)",
            address: "Test Address",
            active: true,
            actor: programmer
        )
        
        // Then
        XCTAssertNotNil(newBase.id)
        XCTAssertEqual(newBase.name, "Test Base (eliminar)")
        
        // Cleanup
        if let baseId = newBase.id {
            try await sut.delete(baseId: baseId, actor: programmer)
        }
    }
    
    /// ⚠️ TEST DESTRUCTIVO - Verificar que Logistics no puede crear bases
    func testLogisticsCannotCreateBase() async throws {
        // Given
        let logistics = try await createLogisticsUser()
        
        // When/Then
        do {
            _ = try await sut.create(
                code: "test_fail",
                name: "Should Fail",
                address: "Address",
                actor: logistics
            )
            XCTFail("Logistics NO debería poder crear bases")
        } catch {
            // Error esperado ✅
        }
    }
    */
}
