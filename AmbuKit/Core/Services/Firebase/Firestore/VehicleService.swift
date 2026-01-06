//
//  VehicleService.swift
//  AmbuKit
//
//  Created by Adolfo on 17/11/25.
//  CORREGIDO: TAREA A+B - Uso correcto de async/await en creación y actualización
//


import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class VehicleService: ObservableObject {
    
    static let shared = VehicleService()
    private let db = Firestore.firestore()
    
    private var vehicleCache: [String: VehicleFS] = [:]
    private let cacheExpiration: TimeInterval = 300
    private var lastCacheUpdate: Date = .distantPast
    
    private init() {}
    
    // MARK: - CRUD
    
    func create(
        code: String,
        plate: String? = nil,
        type: String,
        baseId: String? = nil,
        actor: UserFS?
    ) async throws -> VehicleFS {
        guard await AuthorizationServiceFS.allowed(.create, on: .vehicle, for: actor) else {
            throw VehicleServiceError.unauthorized("No tienes permisos para crear vehículos")
        }
        guard !code.isEmpty else { throw VehicleServiceError.invalidData("El código no puede estar vacío") }
        
        let vehicleType = VehicleFS.VehicleType(rawValue: type.lowercased()) ?? .svb
        
        if let p = plate, !p.isEmpty, let _ = await getVehicleByPlate(p) {
            throw VehicleServiceError.duplicatePlate("Ya existe un vehículo con matrícula '\(p)'")
        }
        if let _ = await getVehicleByCode(code) {
            throw VehicleServiceError.duplicateCode("Ya existe un vehículo con código '\(code)'")
        }
        
        var vehicle = VehicleFS(code: code, plate: plate, type: vehicleType, baseId: baseId)
        let docRef = db.collection(VehicleFS.collectionName).document()
        vehicle.id = docRef.documentID
        
        let encodedData = try Firestore.Encoder().encode(vehicle)
        try await docRef.setData(encodedData)
        
        vehicleCache[docRef.documentID] = vehicle
        print("✅ Vehículo '\(code)' creado con ID: \(docRef.documentID)")
        return vehicle
    }
    
    func create(
        code: String,
        plate: String? = nil,
        type: VehicleFS.VehicleType,
        baseId: String? = nil,
        actor: UserFS?
    ) async throws -> VehicleFS {
        return try await create(code: code, plate: plate, type: type.rawValue, baseId: baseId, actor: actor)
    }
    
    func update(vehicle: VehicleFS, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.update, on: .vehicle, for: actor) else {
            throw VehicleServiceError.unauthorized("No tienes permisos para actualizar vehículos")
        }
        guard let vehicleId = vehicle.id else { throw VehicleServiceError.invalidData("Vehículo sin ID") }
        guard !vehicle.code.isEmpty else { throw VehicleServiceError.invalidData("Código vacío") }
        
        var updated = vehicle
        updated.updatedAt = Date()
        
        let encodedData = try Firestore.Encoder().encode(updated)
        try await db.collection(VehicleFS.collectionName).document(vehicleId).setData(encodedData, merge: true)
        vehicleCache[vehicleId] = updated
        print("✅ Vehículo '\(vehicle.code)' actualizado")
    }
    
    func delete(vehicleId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.delete, on: .vehicle, for: actor) else {
            throw VehicleServiceError.unauthorized("No tienes permisos para eliminar vehículos")
        }
        guard let vehicle = await getVehicle(id: vehicleId) else {
            throw VehicleServiceError.vehicleNotFound("Vehículo no encontrado")
        }
        let kits = await KitService.shared.getKitsByVehicle(vehicleId: vehicleId)
        guard kits.isEmpty else {
            throw VehicleServiceError.vehicleHasKits("Tiene \(kits.count) kits asignados")
        }
        
        try await db.collection(VehicleFS.collectionName).document(vehicleId).delete()
        vehicleCache.removeValue(forKey: vehicleId)
        print("✅ Vehículo '\(vehicle.code)' eliminado")
    }
    
    // MARK: - Queries
    
    func getVehicle(id: String) async -> VehicleFS? {
        if isCacheValid(), let cached = vehicleCache[id] { return cached }
        do {
            let doc = try await db.collection(VehicleFS.collectionName).document(id).getDocument()
            guard let vehicle = try? doc.data(as: VehicleFS.self) else { return nil }
            vehicleCache[id] = vehicle
            return vehicle
        } catch { return nil }
    }
    
    func getVehicleByPlate(_ plate: String) async -> VehicleFS? {
        do {
            let snapshot = try await db.collection(VehicleFS.collectionName).whereField("plate", isEqualTo: plate).limit(to: 1).getDocuments()
            guard let doc = snapshot.documents.first, let v = try? doc.data(as: VehicleFS.self) else { return nil }
            if let id = v.id { vehicleCache[id] = v }
            return v
        } catch { return nil }
    }
    
    func getVehicleByCode(_ code: String) async -> VehicleFS? {
        do {
            let snapshot = try await db.collection(VehicleFS.collectionName).whereField("code", isEqualTo: code).limit(to: 1).getDocuments()
            guard let doc = snapshot.documents.first, let v = try? doc.data(as: VehicleFS.self) else { return nil }
            if let id = v.id { vehicleCache[id] = v }
            return v
        } catch { return nil }
    }
    
    func getAllVehicles() async -> [VehicleFS] {
        do {
            let snapshot = try await db.collection(VehicleFS.collectionName).order(by: "code").getDocuments()
            let vehicles = snapshot.documents.compactMap { try? $0.data(as: VehicleFS.self) }
            vehicles.forEach { if let id = $0.id { vehicleCache[id] = $0 } }
            updateCacheTimestamp()
            return vehicles
        } catch { return [] }
    }
    
    func getVehiclesByBase(baseId: String) async -> [VehicleFS] {
        do {
            let snapshot = try await db.collection(VehicleFS.collectionName).whereField("baseId", isEqualTo: baseId).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: VehicleFS.self) }
        } catch { return [] }
    }
    
    func getVehiclesByType(_ type: VehicleFS.VehicleType) async -> [VehicleFS] {
        do {
            let snapshot = try await db.collection(VehicleFS.collectionName).whereField("type", isEqualTo: type.rawValue).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: VehicleFS.self) }
        } catch { return [] }
    }
    
    func getUnassignedVehicles() async -> [VehicleFS] {
        do {
            let snapshot = try await db.collection(VehicleFS.collectionName).whereField("baseId", isEqualTo: NSNull()).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: VehicleFS.self) }
        } catch { return [] }
    }
    
    // MARK: - Assignment
    
    func assignToBase(vehicleId: String, baseId: String?, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.update, on: .vehicle, for: actor) else {
            throw VehicleServiceError.unauthorized("Sin permisos")
        }
        guard let actualBaseId = baseId, !actualBaseId.isEmpty else {
            throw VehicleServiceError.invalidData("Base ID no válido")
        }
        guard var vehicle = await getVehicle(id: vehicleId) else {
            throw VehicleServiceError.vehicleNotFound("Vehículo no encontrado")
        }
        guard await BaseService.shared.getBase(id: actualBaseId) != nil else {
            throw VehicleServiceError.baseNotFound("Base no encontrada")
        }
        
        vehicle.baseId = actualBaseId
        vehicle.updatedAt = Date()
        
        let encodedData = try Firestore.Encoder().encode(vehicle)
        try await db.collection(VehicleFS.collectionName).document(vehicleId).setData(encodedData, merge: true)
        vehicleCache[vehicleId] = vehicle
        print("✅ Vehículo asignado a base")
    }
    
    func unassignFromBase(vehicleId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.update, on: .vehicle, for: actor) else {
            throw VehicleServiceError.unauthorized("Sin permisos")
        }
        guard var vehicle = await getVehicle(id: vehicleId) else {
            throw VehicleServiceError.vehicleNotFound("Vehículo no encontrado")
        }
        
        vehicle.baseId = nil
        vehicle.updatedAt = Date()
        
        try await db.collection(VehicleFS.collectionName).document(vehicleId).updateData([
            "baseId": NSNull(), "updatedAt": Timestamp(date: Date())
        ])
        vehicleCache[vehicleId] = vehicle
        print("✅ Vehículo desasignado")
    }
    
    // MARK: - Statistics (nombres compatibles con StatisticsView)
    
    func getStatistics() async -> (total: Int, withBase: Int, withoutBase: Int, withKits: Int) {
        let vehicles = await getAllVehicles()
        let withBase = vehicles.filter { $0.baseId != nil }.count
        let withoutBase = vehicles.count - withBase
        
        var withKits = 0
        for vehicle in vehicles {
            let kits = await KitService.shared.getKitsByVehicle(vehicleId: vehicle.id ?? "")
            if !kits.isEmpty { withKits += 1 }
        }
        
        return (vehicles.count, withBase, withoutBase, withKits)
    }
    
    // MARK: - Cache
    
    func clearCache() { vehicleCache.removeAll(); lastCacheUpdate = .distantPast }
    private func isCacheValid() -> Bool { Date().timeIntervalSince(lastCacheUpdate) < cacheExpiration }
    private func updateCacheTimestamp() { lastCacheUpdate = Date() }
    
    // MARK: - Search
    
    func searchVehicles(by text: String) async -> [VehicleFS] {
        let all = await getAllVehicles()
        guard !text.isEmpty else { return all }
        let l = text.lowercased()
        return all.filter { $0.code.lowercased().contains(l) || ($0.plate?.lowercased().contains(l) ?? false) }
    }
}

// MARK: - Errors

enum VehicleServiceError: LocalizedError {
    case unauthorized(String), vehicleNotFound(String), baseNotFound(String)
    case duplicatePlate(String), duplicateCode(String), invalidData(String)
    case vehicleHasKits(String), firestoreError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let m): return "❌ Sin autorización: \(m)"
        case .vehicleNotFound(let m): return "❌ Vehículo no encontrado: \(m)"
        case .baseNotFound(let m): return "❌ Base no encontrada: \(m)"
        case .duplicatePlate(let m): return "❌ Matrícula duplicada: \(m)"
        case .duplicateCode(let m): return "❌ Código duplicado: \(m)"
        case .invalidData(let m): return "❌ Datos inválidos: \(m)"
        case .vehicleHasKits(let m): return "❌ Tiene kits: \(m)"
        case .firestoreError(let e): return "❌ Firestore: \(e.localizedDescription)"
        }
    }
}

#if DEBUG
extension VehicleService {
    func printCacheStatus() { print("📊 VehicleService: \(vehicleCache.count) vehículos") }
}
#endif
