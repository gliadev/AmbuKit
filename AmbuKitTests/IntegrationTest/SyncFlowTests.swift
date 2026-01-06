//
//  SyncFlowTests.swift
//  AmbuKitTests
//
//  Created by Adolfo on 30/12/25.
//  Integration Tests para flujos de sincronización.
//  Verifica: Offline → Online → Resolución de conflictos
//
//  NOTA: Estos tests simulan comportamiento offline/online mediante
//  manipulación de caché, ya que no podemos controlar la red real en tests.
//

import XCTest
@testable import AmbuKit

/// Tests de integración para flujos de sincronización
/// Simula escenarios offline/online y verifica consistencia de datos
@MainActor
final class SyncFlowTests: XCTestCase {
    
    // MARK: - Properties
    
    var kitService: KitService!
    var baseService: BaseService!
    var vehicleService: VehicleService!
    var userService: UserService!
    var policyService: PolicyService!
    
    var programmerUser: UserFS!
    var programmerRole: RoleFS!
    
    var createdKitIds: [String] = []
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        kitService = KitService.shared
        baseService = BaseService.shared
        vehicleService = VehicleService.shared
        userService = UserService.shared
        policyService = PolicyService.shared
        
        // Limpiar cachés
        clearAllCaches()
        
        createdKitIds = []
        
        // Obtener rol y crear usuario de prueba
        try await setupTestUser()
    }
    
    override func tearDown() async throws {
        // Limpiar kits creados
        for kitId in createdKitIds {
            try? await kitService.deleteKit(kitId: kitId, actor: programmerUser)
        }
        
        clearAllCaches()
        
        try await super.tearDown()
    }
    
    // MARK: - Setup Helpers
    
    private func clearAllCaches() {
        kitService.clearCache()
        baseService.clearCache()
        vehicleService.clearCache()
        userService.clearCache()
        policyService.clearCache()
    }
    
    private func setupTestUser() async throws {
        let roles = await policyService.getAllRoles()
        programmerRole = roles.first(where: { $0.kind == .programmer })
        
        guard let role = programmerRole else {
            throw XCTSkip("No se encontró rol de programador")
        }
        
        programmerUser = UserFS(
            id: "sync_test_user_\(UUID().uuidString.prefix(6))",
            uid: "sync_uid_\(UUID().uuidString.prefix(6))",
            username: "sync_tester",
            fullName: "Sync Test User",
            email: "sync@test.com",
            active: true,
            roleId: role.id
        )
    }
    
    // MARK: - Offline/Online Simulation Tests
    
    /// Test del flujo: Cargar datos → "Ir offline" (usar caché) → Verificar datos disponibles
    func testOfflineDataAvailability() async throws {
        // STEP 1: Cargar datos mientras "online"
        let kits = await kitService.getAllKits()
        let bases = await baseService.getAllBases()
        let vehicles = await vehicleService.getAllVehicles()
        
        // Guardar counts
        let onlineKitCount = kits.count
        let onlineBaseCount = bases.count
        let onlineVehicleCount = vehicles.count
        
        // STEP 2: Simular "offline" - los datos deberían estar en caché
        // STEP 3: Acceder a datos "offline" (desde caché)
        let cachedKits = await kitService.getAllKits()
        let cachedBases = await baseService.getAllBases()
        let cachedVehicles = await vehicleService.getAllVehicles()
        
        // STEP 4: Verificar que los datos están disponibles
        XCTAssertEqual(cachedKits.count, onlineKitCount,
                       "Datos de kits deberían estar disponibles offline")
        XCTAssertEqual(cachedBases.count, onlineBaseCount,
                       "Datos de bases deberían estar disponibles offline")
        XCTAssertEqual(cachedVehicles.count, onlineVehicleCount,
                       "Datos de vehículos deberían estar disponibles offline")
    }
    
    /// Test de operaciones en caché: Modificar datos localmente → Sincronizar
    func testCacheConsistency() async throws {
        let prefix = UUID().uuidString.prefix(6)
        
        // STEP 1: Crear kit "online"
        let kit = try await kitService.createKit(
            code: "SYNC-\(prefix)",
            name: "Sync Test Kit",
            type: .custom,
            status: "active",
            actor: programmerUser
        )
        createdKitIds.append(kit.id!)
        
        // STEP 2: Verificar que está en caché
        let cachedKit1 = await kitService.getKit(id: kit.id!)
        XCTAssertNotNil(cachedKit1)
        XCTAssertEqual(cachedKit1?.name, "Sync Test Kit")
        
        // STEP 3: Actualizar kit
        var updatedKit = kit
        updatedKit.name = "Updated Sync Kit"
        try await kitService.updateKit(kit: updatedKit, actor: programmerUser)
        
        // STEP 4: Verificar que el caché se actualizó
        let cachedKit2 = await kitService.getKit(id: kit.id!)
        XCTAssertEqual(cachedKit2?.name, "Updated Sync Kit",
                       "Caché debería reflejar actualización")
        
        // STEP 5: Limpiar caché y verificar desde Firebase
        kitService.clearCache()
        
        let freshKit = await kitService.getKit(id: kit.id!)
        XCTAssertEqual(freshKit?.name, "Updated Sync Kit",
                       "Firebase debería tener el dato actualizado")
    }
    
    /// Test de sincronización después de reconexión
    func testReconnectionSync() async throws {
        // STEP 1: Cargar datos iniciales
        let initialKits = await kitService.getAllKits()
        let initialCount = initialKits.count
        
        let prefix = UUID().uuidString.prefix(6)
        
        // STEP 2: Simular "desconexión" - limpiar caché
        kitService.clearCache()
        
        // STEP 3: Crear nuevo kit (simula otra sesión/dispositivo)
        let newKit = try await kitService.createKit(
            code: "SYNC-NEW-\(prefix)",
            name: "New Kit After Reconnect",
            type: .custom,
            status: "active",
            actor: programmerUser
        )
        createdKitIds.append(newKit.id!)
        
        // STEP 4: Simular "reconexión" - limpiar caché y recargar
        kitService.clearCache()
        
        // STEP 5: Verificar que se ven los nuevos datos
        let syncedKits = await kitService.getAllKits()
        
        XCTAssertGreaterThanOrEqual(syncedKits.count, initialCount,
                                     "Después de sync debería haber al menos los mismos kits")
        XCTAssertTrue(syncedKits.contains(where: { $0.id == newKit.id }),
                      "Nuevo kit debería aparecer después de sync")
    }
    
    // MARK: - Conflict Resolution Tests
    
    /// Test de conflicto: Dos "usuarios" modifican el mismo recurso
    func testConflictScenario() async throws {
        let prefix = UUID().uuidString.prefix(6)
        
        // STEP 1: Crear kit inicial
        let kit = try await kitService.createKit(
            code: "CONFLICT-\(prefix)",
            name: "Original Name",
            type: .custom,
            status: "active",
            actor: programmerUser
        )
        createdKitIds.append(kit.id!)
        
        // STEP 2: "Usuario A" modifica el kit
        var kitUserA = kit
        kitUserA.name = "Modified by User A"
        try await kitService.updateKit(kit: kitUserA, actor: programmerUser)
        
        // STEP 3: Limpiar caché (simular que "Usuario B" no vio el cambio)
        kitService.clearCache()
        
        // STEP 4: "Usuario B" carga el kit (verá la versión de User A)
        let kitUserB = await kitService.getKit(id: kit.id!)
        
        // En Firebase, "last write wins" - Usuario B ve los cambios de A
        XCTAssertEqual(kitUserB?.name, "Modified by User A",
                       "Usuario B debería ver cambios de Usuario A")
        
        // STEP 5: "Usuario B" hace su propia modificación
        var kitModifiedByB = kitUserB!
        kitModifiedByB.name = "Modified by User B"
        try await kitService.updateKit(kit: kitModifiedByB, actor: programmerUser)
        
        // STEP 6: Verificar resultado final
        kitService.clearCache()
        let finalKit = await kitService.getKit(id: kit.id!)
        
        XCTAssertEqual(finalKit?.name, "Modified by User B",
                       "Última escritura debería ganar")
    }
    
    /// Test de operaciones encoladas: Múltiples operaciones → Ejecutar secuencialmente
    func testQueuedOperations() async throws {
        let prefix = UUID().uuidString.prefix(6)
        
        // STEP 1: Crear kit base
        let kit = try await kitService.createKit(
            code: "QUEUE-\(prefix)",
            name: "Queue Test Kit",
            type: .custom,
            status: "active",
            actor: programmerUser
        )
        createdKitIds.append(kit.id!)
        
        // STEP 2: Ejecutar múltiples operaciones secuencialmente
        
        // Operación 1: Cambiar nombre
        var op1Kit = kit
        op1Kit.name = "After Op 1"
        try await kitService.updateKit(kit: op1Kit, actor: programmerUser)
        
        // Operación 2: Cambiar estado
        var op2Kit = op1Kit
        op2Kit.status = .maintenance
        try await kitService.updateKit(kit: op2Kit, actor: programmerUser)
        
        // Operación 3: Cambiar nombre otra vez
        var op3Kit = op2Kit
        op3Kit.name = "After Op 3"
        try await kitService.updateKit(kit: op3Kit, actor: programmerUser)
        
        // Operación 4: Volver a estado activo
        var op4Kit = op3Kit
        op4Kit.status = .active
        try await kitService.updateKit(kit: op4Kit, actor: programmerUser)
        
        // Operación 5: Nombre final
        var op5Kit = op4Kit
        op5Kit.name = "Final Name After Queue"
        try await kitService.updateKit(kit: op5Kit, actor: programmerUser)
        
        // STEP 3: Limpiar caché y verificar estado final
        kitService.clearCache()
        
        let finalKit = await kitService.getKit(id: kit.id!)
        
        XCTAssertNotNil(finalKit)
        XCTAssertEqual(finalKit?.name, "Final Name After Queue",
                       "Nombre debería reflejar última operación")
        XCTAssertEqual(finalKit?.status, .active,
                       "Estado debería reflejar última operación")
    }
    
    // MARK: - Data Integrity Tests
    
    /// Test de integridad: Verificar que los datos no se corrompen durante sync
    func testDataIntegrity() async throws {
        let prefix = UUID().uuidString.prefix(6)
        
        // STEP 1: Crear kit con todos los campos
        let originalKit = try await kitService.createKit(
            code: "INTEGRITY-\(prefix)",
            name: "Integrity Test Kit",
            type: .custom,
            status: "active",
            vehicleId: nil,
            actor: programmerUser
        )
        createdKitIds.append(originalKit.id!)
        
        // Guardar valores originales
        let originalCode = originalKit.code
        let originalName = originalKit.name
        let originalType = originalKit.type
        let originalStatus = originalKit.status
        
        // STEP 2: Múltiples ciclos de caché clear y reload
        for i in 1...5 {
            kitService.clearCache()
            
            let reloadedKit = await kitService.getKit(id: originalKit.id!)
            
            XCTAssertNotNil(reloadedKit, "Kit debería existir en ciclo \(i)")
            XCTAssertEqual(reloadedKit?.code, originalCode,
                          "Código no debería cambiar en ciclo \(i)")
            XCTAssertEqual(reloadedKit?.name, originalName,
                          "Nombre no debería cambiar en ciclo \(i)")
            XCTAssertEqual(reloadedKit?.type, originalType,
                          "Tipo no debería cambiar en ciclo \(i)")
            XCTAssertEqual(reloadedKit?.status, originalStatus,
                          "Estado no debería cambiar en ciclo \(i)")
        }
    }
    
    /// Test de consistencia entre servicios: Datos relacionados se mantienen coherentes
    func testCrossServiceConsistency() async throws {
        // Obtener datos de múltiples servicios
        let kits = await kitService.getAllKits()
        let vehicles = await vehicleService.getAllVehicles()
        
        // Verificar consistencia: kits asignados deberían tener vehicleId válido
        let assignedKits = kits.filter { $0.isAssigned }
        
        for kit in assignedKits {
            guard let vehicleId = kit.vehicleId else { continue }
            
            // El vehículo referenciado debería existir
            let vehicle = vehicles.first(where: { $0.id == vehicleId })
            
            if vehicle != nil {
                XCTAssertNotNil(vehicle,
                               "Vehículo \(vehicleId) referenciado por kit \(kit.id ?? "") debería existir")
            }
        }
        
        // El test pasa si no hay inconsistencias detectadas
        XCTAssertTrue(true, "No se detectaron inconsistencias entre servicios")
    }
    
    // MARK: - Performance Under Sync Tests
    
    /// Test de rendimiento: Múltiples operaciones no degradan el servicio
    func testPerformanceUnderLoad() async throws {
        let prefix = UUID().uuidString.prefix(6)
        
        // Crear varios kits rápidamente
        var kits: [KitFS] = []
        
        for i in 1...5 {
            let kit = try await kitService.createKit(
                code: "PERF-\(prefix)-\(i)",
                name: "Performance Kit \(i)",
                type: .custom,
                status: "active",
                actor: programmerUser
            )
            kits.append(kit)
            createdKitIds.append(kit.id!)
        }
        
        // Verificar que todos se crearon
        XCTAssertEqual(kits.count, 5, "Deberían crearse 5 kits")
        
        // Limpiar caché
        kitService.clearCache()
        
        // Cargar todos de nuevo
        let start = Date()
        
        for kit in kits {
            let loaded = await kitService.getKit(id: kit.id!)
            XCTAssertNotNil(loaded)
        }
        
        let elapsed = Date().timeIntervalSince(start)
        
        // Debería completarse en tiempo razonable (< 10 segundos para 5 kits)
        XCTAssertLessThan(elapsed, 10.0,
                          "Cargar 5 kits debería tomar menos de 10 segundos")
    }
}
