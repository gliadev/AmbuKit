//
//  BaseService.swift
//  AmbuKit
//
//  Created by Adolfo on 17/11/25.
//  CORREGIDO: TAREA A+B - Uso correcto de async/await en creación y actualización
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class BaseService: ObservableObject {
    
    static let shared = BaseService()
    private let db = Firestore.firestore()
    
    private var baseCache: [String: BaseFS] = [:]
    private let cacheExpiration: TimeInterval = 300
    private var lastCacheUpdate: Date = .distantPast
    
    private init() {}
    
    // MARK: - CRUD
    
    func create(
        code: String,
        name: String,
        address: String?,
        active: Bool = true,
        actor: UserFS?
    ) async throws -> BaseFS {
        guard await AuthorizationServiceFS.allowed(.create, on: .base, for: actor) else {
            throw BaseServiceError.unauthorized("No tienes permisos para crear bases")
        }
        guard !code.isEmpty else { throw BaseServiceError.invalidData("El código no puede estar vacío") }
        guard !name.isEmpty else { throw BaseServiceError.invalidData("El nombre no puede estar vacío") }
        
        if let _ = await getBaseByCode(code) {
            throw BaseServiceError.duplicateCode("Ya existe una base con código '\(code)'")
        }
        
        var base = BaseFS(code: code, name: name, address: address ?? "")
        base.active = active
        let docRef = db.collection(BaseFS.collectionName).document()
        base.id = docRef.documentID
        
        let encodedData = try Firestore.Encoder().encode(base)
        try await docRef.setData(encodedData)
        
        baseCache[docRef.documentID] = base
        print("✅ Base '\(name)' creada con ID: \(docRef.documentID)")
        return base
    }
    
    func update(_ base: BaseFS, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.update, on: .base, for: actor) else {
            throw BaseServiceError.unauthorized("No tienes permisos para actualizar bases")
        }
        guard let baseId = base.id else { throw BaseServiceError.invalidData("Base sin ID") }
        guard !base.code.isEmpty else { throw BaseServiceError.invalidData("Código vacío") }
        guard !base.name.isEmpty else { throw BaseServiceError.invalidData("Nombre vacío") }
        
        var updated = base
        updated.updatedAt = Date()
        
        let encodedData = try Firestore.Encoder().encode(updated)
        try await db.collection(BaseFS.collectionName).document(baseId).setData(encodedData, merge: true)
        baseCache[baseId] = updated
        print("✅ Base '\(base.name)' actualizada")
    }
    
    func delete(baseId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.delete, on: .base, for: actor) else {
            throw BaseServiceError.unauthorized("No tienes permisos para eliminar bases")
        }
        guard let base = await getBase(id: baseId) else {
            throw BaseServiceError.baseNotFound("Base no encontrada")
        }
        let vehicles = await VehicleService.shared.getVehiclesByBase(baseId: baseId)
        guard vehicles.isEmpty else {
            throw BaseServiceError.baseHasVehicles("Tiene \(vehicles.count) vehículos asignados")
        }
        
        try await db.collection(BaseFS.collectionName).document(baseId).delete()
        baseCache.removeValue(forKey: baseId)
        print("✅ Base '\(base.name)' eliminada")
    }
    
    // MARK: - Queries
    
    func getBase(id: String) async -> BaseFS? {
        if isCacheValid(), let cached = baseCache[id] { return cached }
        do {
            let doc = try await db.collection(BaseFS.collectionName).document(id).getDocument()
            guard let base = try? doc.data(as: BaseFS.self) else { return nil }
            baseCache[id] = base
            return base
        } catch { return nil }
    }
    
    func getBaseByCode(_ code: String) async -> BaseFS? {
        do {
            let snapshot = try await db.collection(BaseFS.collectionName).whereField("code", isEqualTo: code).limit(to: 1).getDocuments()
            guard let doc = snapshot.documents.first, let base = try? doc.data(as: BaseFS.self) else { return nil }
            if let id = base.id { baseCache[id] = base }
            return base
        } catch { return nil }
    }
    
    func getActiveBases() async -> [BaseFS] {
        do {
            let snapshot = try await db.collection(BaseFS.collectionName)
                .whereField("active", isEqualTo: true)
                .order(by: "code")
                .getDocuments()
            let bases = snapshot.documents.compactMap { try? $0.data(as: BaseFS.self) }
            bases.forEach { if let id = $0.id { baseCache[id] = $0 } }
            updateCacheTimestamp()
            return bases
        } catch { return [] }
    }
    
    func getAllBases(includeInactive: Bool = false) async -> [BaseFS] {
        do {
            var query: Query = db.collection(BaseFS.collectionName).order(by: "code")
            
            if !includeInactive {
                query = db.collection(BaseFS.collectionName)
                    .whereField("active", isEqualTo: true)
                    .order(by: "code")
            }
            
            let snapshot = try await query.getDocuments()
            let bases = snapshot.documents.compactMap { try? $0.data(as: BaseFS.self) }
            bases.forEach { if let id = $0.id { baseCache[id] = $0 } }
            updateCacheTimestamp()
            return bases
        } catch { return [] }
    }
    
    // MARK: - Statistics (nombres compatibles con StatisticsView)
    
    func getStatistics() async -> (total: Int, active: Int, withVehicles: Int, withoutVehicles: Int) {
        let allBases = await getAllBases(includeInactive: true)
        let activeBases = allBases.filter { $0.active }
        
        var withVehicles = 0
        for base in allBases {
            let vehicles = await VehicleService.shared.getVehiclesByBase(baseId: base.id ?? "")
            if !vehicles.isEmpty { withVehicles += 1 }
        }
        
        return (allBases.count, activeBases.count, withVehicles, allBases.count - withVehicles)
    }
    
    // MARK: - Cache
    
    func clearCache() { baseCache.removeAll(); lastCacheUpdate = .distantPast }
    private func isCacheValid() -> Bool { Date().timeIntervalSince(lastCacheUpdate) < cacheExpiration }
    private func updateCacheTimestamp() { lastCacheUpdate = Date() }
    
    // MARK: - Search
    
    func searchBases(by text: String) async -> [BaseFS] {
        let all = await getAllBases()
        guard !text.isEmpty else { return all }
        let l = text.lowercased()
        return all.filter { $0.code.lowercased().contains(l) || $0.name.lowercased().contains(l) }
    }
}

// MARK: - Errors

enum BaseServiceError: LocalizedError {
    case unauthorized(String), baseNotFound(String), duplicateCode(String)
    case invalidData(String), baseHasVehicles(String), firestoreError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let m): return "❌ Sin autorización: \(m)"
        case .baseNotFound(let m): return "❌ Base no encontrada: \(m)"
        case .duplicateCode(let m): return "❌ Código duplicado: \(m)"
        case .invalidData(let m): return "❌ Datos inválidos: \(m)"
        case .baseHasVehicles(let m): return "❌ Tiene vehículos: \(m)"
        case .firestoreError(let e): return "❌ Firestore: \(e.localizedDescription)"
        }
    }
}

#if DEBUG
extension BaseService {
    func printCacheStatus() { print("📊 BaseService: \(baseCache.count) bases") }
}
#endif






















