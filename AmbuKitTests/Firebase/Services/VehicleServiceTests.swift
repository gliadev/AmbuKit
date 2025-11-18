//
//  VehicleServiceTests.swift
//  AmbuKitTests
//
//  Created by Adolfo on 17/11/25.
//

import XCTest
@testable import AmbuKit
import FirebaseFirestore

@MainActor
final class VehicleServiceTests: XCTestCase {
    
    var service: VehicleService!
    var testProgrammerUser: UserFS!
    var testLogisticsUser: UserFS!
    var testSanitaryUser: UserFS!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        service = VehicleService.shared
        service.clearCache()
        
        // Crear usuarios de prueba con diferentes roles
        testProgrammerUser = UserFS(
            id: "test_prog_user",
            uid: "firebase_uid_programmer",
            username: "programmer",
            fullName: "Test Programmer",
            email: "prog@test.com",
            active: true,
            roleId: "role_programmer"
        )
        
        testLogisticsUser = UserFS(
            id: "test_log_user",
            uid: "firebase_uid_logistics",
            username: "logistics",
            fullName: "Test Logistics",
            email: "log@test.com",
            active: true,
            roleId: "role_logistics"
        )
        
        testSanitaryUser = UserFS(
            id: "test_san_user",
            uid: "firebase_uid_sanitary",
            username: "sanitary",
            fullName: "Test Sanitary",
            email: "san@test.com",
            active: true,
            roleId: "role_sanitary"
        )
    }
    
    override func tearDown() async throws {
        // Limpiar datos de prueba de Firestore
        await cleanupTestVehicles()
        service.clearCache()
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func cleanupTestVehicles() async {
        let vehicles = await service.getAllVehicles()
        for vehicle in vehicles where vehicle.code.hasPrefix("TEST-") {
            if let id = vehicle.id {
                try? await service.delete(vehicleId: id, actor: testProgrammerUser)
            }
        }
    }
    
    // MARK: - CREATE Tests
    
    func testCreateVehicle_AsProgrammer_Success() async throws {
        // Given: Usuario programador
        let code = "TEST-PROG-001"
        let type = "SVA Avanzada"
        
        // When: Crear vehículo
        let vehicle = try await service.create(
            code: code,
            plate: "1234-ABC",
            type: type,
            baseId: nil,
            actor: testProgrammerUser
        )
        
        // Then: Vehículo creado correctamente
        XCTAssertNotNil(vehicle.id)
        XCTAssertEqual(vehicle.code, code)
        XCTAssertEqual(vehicle.type, type)
        XCTAssertEqual(vehicle.plate, "1234-ABC")
        
        // Verificar en Firestore
        let fetched = await service.getVehicle(id: vehicle.id!)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.code, code)
    }
    
    func testCreateVehicle_AsLogistics_Success() async throws {
        // Given: Usuario logística
        let code = "TEST-LOG-001"
        let type = "SVB Básica"
        
        // When: Crear vehículo
        let vehicle = try await service.create(
            code: code,
            plate: nil,
            type: type,
            actor: testLogisticsUser
        )
        
        // Then: Vehículo creado correctamente
        XCTAssertNotNil(vehicle.id)
        XCTAssertEqual(vehicle.code, code)
        XCTAssertNil(vehicle.plate)
    }
    
    func testCreateVehicle_AsSanitary_Unauthorized() async throws {
        // Given: Usuario sanitario (sin permisos de crear)
        let code = "TEST-SAN-001"
        
        // When & Then: Debe lanzar error de autorización
        do {
            _ = try await service.create(
                code: code,
                plate: nil,
                type: "SVA",
                actor: testSanitaryUser
            )
            XCTFail("Debería lanzar error de autorización")
        } catch let error as VehicleServiceError {
            switch error {
            case .unauthorized:
                // Expected
                XCTAssertTrue(true)
            default:
                XCTFail("Error incorrecto: \(error)")
            }
        }
    }
    
    func testCreateVehicle_DuplicateCode_ThrowsError() async throws {
        // Given: Vehículo existente
        let code = "TEST-DUP-001"
        _ = try await service.create(
            code: code,
            plate: nil,
            type: "SVA",
            actor: testProgrammerUser
        )
        
        // When & Then: Intentar crear otro con el mismo código
        do {
            _ = try await service.create(
                code: code,
                plate: nil,
                type: "SVB",
                actor: testProgrammerUser
            )
            XCTFail("Debería lanzar error de código duplicado")
        } catch let error as VehicleServiceError {
            switch error {
            case .duplicateCode:
                // Expected
                XCTAssertTrue(true)
            default:
                XCTFail("Error incorrecto: \(error)")
            }
        }
    }
    
    func testCreateVehicle_EmptyCode_ThrowsError() async throws {
        // Given: Código vacío
        let code = ""
        
        // When & Then: Debe lanzar error de datos inválidos
        do {
            _ = try await service.create(
                code: code,
                plate: nil,
                type: "SVA",
                actor: testProgrammerUser
            )
            XCTFail("Debería lanzar error de datos inválidos")
        } catch let error as VehicleServiceError {
            switch error {
            case .invalidData:
                // Expected
                XCTAssertTrue(true)
            default:
                XCTFail("Error incorrecto: \(error)")
            }
        }
    }
    
    func testCreateVehicle_WithBase_Success() async throws {
        // Given: Vehículo con base asignada
        let code = "TEST-BASE-001"
        let baseId = "test_base_bilbao"
        
        // When: Crear vehículo con base
        let vehicle = try await service.create(
            code: code,
            plate: nil,
            type: "SVA",
            baseId: baseId,
            actor: testProgrammerUser
        )
        
        // Then: Vehículo tiene base asignada
        XCTAssertNotNil(vehicle.baseId)
        XCTAssertEqual(vehicle.baseId, baseId)
        XCTAssertTrue(vehicle.hasBase)
    }
    
    // MARK: - UPDATE Tests
    
    func testUpdateVehicle_Success() async throws {
        // Given: Vehículo existente
        var vehicle = try await service.create(
            code: "TEST-UPD-001",
            plate: "1111-AAA",
            type: "SVA",
            actor: testProgrammerUser
        )
        
        // When: Actualizar matrícula
        vehicle.plate = "2222-BBB"
        try await service.update(vehicle: vehicle, actor: testProgrammerUser)
        
        // Then: Vehículo actualizado
        let updated = await service.getVehicle(id: vehicle.id!)
        XCTAssertEqual(updated?.plate, "2222-BBB")
    }
    
    // MARK: - DELETE Tests
    
    func testDeleteVehicle_AsProgrammer_Success() async throws {
        // Given: Vehículo sin kits
        let vehicle = try await service.create(
            code: "TEST-DEL-001",
            plate: nil,
            type: "SVA",
            actor: testProgrammerUser
        )
        
        let vehicleId = vehicle.id!
        
        // When: Eliminar vehículo
        try await service.delete(vehicleId: vehicleId, actor: testProgrammerUser)
        
        // Then: Vehículo eliminado
        let deleted = await service.getVehicle(id: vehicleId)
        XCTAssertNil(deleted)
    }
    
    func testDeleteVehicle_AsLogistics_Unauthorized() async throws {
        // Given: Vehículo existente
        let vehicle = try await service.create(
            code: "TEST-DEL-LOG-001",
            plate: nil,
            type: "SVB",
            actor: testProgrammerUser
        )
        
        // When & Then: Logística no puede eliminar
        do {
            try await service.delete(vehicleId: vehicle.id!, actor: testLogisticsUser)
            XCTFail("Debería lanzar error de autorización")
        } catch let error as VehicleServiceError {
            switch error {
            case .unauthorized:
                XCTAssertTrue(true)
            default:
                XCTFail("Error incorrecto: \(error)")
            }
        }
    }
    
    // MARK: - QUERY Tests
    
    func testGetAllVehicles_Success() async throws {
        // Given: Varios vehículos
        _ = try await service.create(code: "TEST-ALL-001", plate: nil, type: "SVA", actor: testProgrammerUser)
        _ = try await service.create(code: "TEST-ALL-002", plate: nil, type: "SVB", actor: testProgrammerUser)
        
        // When: Obtener todos
        let vehicles = await service.getAllVehicles()
        
        // Then: Al menos 2 vehículos
        let testVehicles = vehicles.filter { $0.code.hasPrefix("TEST-ALL-") }
        XCTAssertGreaterThanOrEqual(testVehicles.count, 2)
    }
    
    func testGetVehiclesByBase_Success() async throws {
        // Given: Vehículos en diferentes bases
        let baseId = "test_base_trapaga"
        _ = try await service.create(code: "TEST-BASE1-001", plate: nil, type: "SVA", baseId: baseId, actor: testProgrammerUser)
        _ = try await service.create(code: "TEST-BASE1-002", plate: nil, type: "SVB", baseId: baseId, actor: testProgrammerUser)
        
        // When: Obtener vehículos de una base
        let vehicles = await service.getVehiclesByBase(baseId: baseId)
        
        // Then: Solo vehículos de esa base
        let testVehicles = vehicles.filter { $0.code.hasPrefix("TEST-BASE1-") }
        XCTAssertEqual(testVehicles.count, 2)
    }
    
    func testGetVehicleByCode_Success() async throws {
        // Given: Vehículo con código específico
        let code = "TEST-CODE-001"
        _ = try await service.create(code: code, plate: "9999-ZZZ", type: "SVA", actor: testProgrammerUser)
        
        // When: Buscar por código
        let vehicle = await service.getVehicleByCode(code)
        
        // Then: Vehículo encontrado
        XCTAssertNotNil(vehicle)
        XCTAssertEqual(vehicle?.code, code)
    }
    
    func testAssignToBase_Success() async throws {
        // Given: Vehículo sin base
        let vehicle = try await service.create(
            code: "TEST-ASSIGN-001",
            plate: nil,
            type: "SVA",
            baseId: nil,
            actor: testProgrammerUser
        )
        
        // When: Asignar a base
        let baseId = "test_base_bilbao"
        try await service.assignToBase(
            vehicleId: vehicle.id!,
            baseId: baseId,
            actor: testProgrammerUser
        )
        
        // Then: Vehículo asignado
        let updated = await service.getVehicle(id: vehicle.id!)
        XCTAssertEqual(updated?.baseId, baseId)
    }
}
