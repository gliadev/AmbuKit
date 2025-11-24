//
//  BaseService.swift
//  AmbuKit
//
//  Created by Adolfo on 17/11/25.
//


import Foundation
import FirebaseFirestore
import Combine

/// Servicio para gestionar Bases (estaciones/sedes) en Firestore
/// Implementa CRUD completo con validación de permisos
@MainActor
final class BaseService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = BaseService()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    
    // MARK: - Cache
    
    private var baseCache: [String: BaseFS] = [:]
    private let cacheExpiration: TimeInterval = 300
    private var lastCacheUpdate: Date = .distantPast
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - CRUD Operations
    
    /// Crea una nueva base en Firestore
    /// - Parameters:
    ///   - code: Código único (ej: "2401")
    ///   - name: Nombre (ej: "Bilbao 1")
    ///   - address: Dirección opcional
    ///   - active: Si está activa
    ///   - actor: Usuario que realiza la acción
    /// - Returns: BaseFS creada
    func create(
        code: String,
        name: String,
        address: String? = nil,
        active: Bool = true,
        actor: UserFS?
    ) async throws -> BaseFS {
        // 1. Validar permisos
        guard await AuthorizationServiceFS.allowed(.create, on: .base, for: actor) else {
            throw BaseServiceError.unauthorized("No tienes permisos para crear bases")
        }
        
        // 2. Validar datos
        guard !code.isEmpty else {
            throw BaseServiceError.invalidData("El código no puede estar vacío")
        }
        
        guard !name.isEmpty else {
            throw BaseServiceError.invalidData("El nombre no puede estar vacío")
        }
        
        // 3. Verificar código duplicado
        if let _ = await getBaseByCode(code) {
            throw BaseServiceError.duplicateCode("Ya existe una base con código '\(code)'")
        }
        
        // 4. Crear base
        var base = BaseFS(code: code, name: name, address: address ?? "", active: active)
        
        // 5. Guardar en Firestore
        do {
            let docRef = try db.collection(BaseFS.collectionName).addDocument(from: base)
            base.id = docRef.documentID
            
            if let id = base.id {
                baseCache[id] = base
                updateCacheTimestamp()
            }
            
            // 6. Auditoría (cuando AuditServiceFS exista)
            // await AuditServiceFS.log(.create, entity: .base, entityId: base.id ?? "", actor: actor)
            
            print("✅ Base '\(name)' (\(code)) creada correctamente")
            return base
            
        } catch {
            print("❌ Error creando base: \(error.localizedDescription)")
            throw BaseServiceError.firestoreError(error)
        }
    }
    
    /// Actualiza una base existente
    func update(_ base: BaseFS, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.update, on: .base, for: actor) else {
            throw BaseServiceError.unauthorized("No tienes permisos para actualizar bases")
        }
        
        guard let baseId = base.id else {
            throw BaseServiceError.invalidData("La base no tiene ID válido")
        }
        
        var updatedBase = base
        updatedBase.updatedAt = Date()
        
        do {
            try db.collection(BaseFS.collectionName)
                .document(baseId)
                .setData(from: updatedBase, merge: true)
            
            baseCache[baseId] = updatedBase
            
            // Auditoría
            // await AuditServiceFS.log(.update, entity: .base, entityId: baseId, actor: actor)
            
            print("✅ Base '\(base.name)' actualizada correctamente")
            
        } catch {
            print("❌ Error actualizando base: \(error.localizedDescription)")
            throw BaseServiceError.firestoreError(error)
        }
    }
    
    /// Elimina una base de Firestore
    func delete(baseId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.delete, on: .base, for: actor) else {
            throw BaseServiceError.unauthorized("No tienes permisos para eliminar bases")
        }
        
        guard let base = await getBase(id: baseId) else {
            throw BaseServiceError.baseNotFound("Base con ID '\(baseId)' no encontrada")
        }
        
        if base.hasVehicles {
            throw BaseServiceError.hasVehicles("No se puede eliminar la base porque tiene \(base.vehicleCount) vehículo(s) asignado(s)")
        }
        
        do {
            try await db.collection(BaseFS.collectionName)
                .document(baseId)
                .delete()
            
            baseCache.removeValue(forKey: baseId)
            
            // Auditoría
            // await AuditServiceFS.log(.delete, entity: .base, entityId: baseId, actor: actor)
            
            print("✅ Base '\(base.name)' eliminada correctamente")
            
        } catch {
            print("❌ Error eliminando base: \(error.localizedDescription)")
            throw BaseServiceError.firestoreError(error)
        }
    }
    
    // MARK: - Query Operations
    
    /// Obtiene una base por su ID
    func getBase(id: String) async -> BaseFS? {
        if isCacheValid(), let cached = baseCache[id] {
            return cached
        }
        
        do {
            let document = try await db.collection(BaseFS.collectionName)
                .document(id)
                .getDocument()
            
            guard let base = try? document.data(as: BaseFS.self) else { return nil }
            
            baseCache[id] = base
            return base
            
        } catch {
            print("❌ Error obteniendo base '\(id)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Obtiene una base por su código único
    func getBaseByCode(_ code: String) async -> BaseFS? {
        do {
            let snapshot = try await db.collection(BaseFS.collectionName)
                .whereField("code", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = snapshot.documents.first,
                  let base = try? document.data(as: BaseFS.self) else {
                return nil
            }
            
            if let id = base.id {
                baseCache[id] = base
            }
            
            return base
            
        } catch {
            print("❌ Error obteniendo base por código '\(code)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Obtiene todas las bases
    func getAllBases(includeInactive: Bool = false) async -> [BaseFS] {
        do {
            var query: Query = db.collection(BaseFS.collectionName)
            
            if !includeInactive {
                query = query.whereField("active", isEqualTo: true)
            }
            
            let snapshot = try await query
                .order(by: "code")
                .getDocuments()
            
            let bases = snapshot.documents.compactMap { doc -> BaseFS? in
                try? doc.data(as: BaseFS.self)
            }
            
            bases.forEach { base in
                if let id = base.id {
                    baseCache[id] = base
                }
            }
            
            updateCacheTimestamp()
            return bases
            
        } catch {
            print("❌ Error obteniendo todas las bases: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Obtiene solo las bases activas
    func getActiveBases() async -> [BaseFS] {
        await getAllBases(includeInactive: false)
    }
    
    /// Obtiene bases que tienen vehículos asignados
    func getBasesWithVehicles() async -> [BaseFS] {
        let allBases = await getAllBases()
        return allBases.filter { $0.hasVehicles }
    }
    
    /// Obtiene bases sin vehículos asignados
    func getBasesWithoutVehicles() async -> [BaseFS] {
        let allBases = await getAllBases()
        return allBases.filter { !$0.hasVehicles }
    }
    
    // MARK: - Vehicle Management
    
    /// Asigna un vehículo a una base
    func assignVehicle(_ vehicleId: String, to baseId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.update, on: .base, for: actor) else {
            throw BaseServiceError.unauthorized("No tienes permisos para asignar vehículos")
        }
        
        guard var base = await getBase(id: baseId) else {
            throw BaseServiceError.baseNotFound("Base no encontrada")
        }
        
       _ = base.hasVehicle(vehicleId: vehicleId)
        
        base = base.addingVehicle(vehicleId: vehicleId)
        try await update(base, actor: actor)
        
        print("✅ Vehículo '\(vehicleId)' asignado a base '\(base.name)'")
    }
    
    /// Desasigna un vehículo de una base
    func unassignVehicle(_ vehicleId: String, from baseId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.update, on: .base, for: actor) else {
            throw BaseServiceError.unauthorized("No tienes permisos para desasignar vehículos")
        }
        
        guard var base = await getBase(id: baseId) else {
            throw BaseServiceError.baseNotFound("Base no encontrada")
        }
        
        if !base.hasVehicle(vehicleId: vehicleId) {
            return // No está asignado
        }
        
        base = base.removingVehicle(vehicleId: vehicleId)
        try await update(base, actor: actor)
        
        print("✅ Vehículo '\(vehicleId)' desasignado de base '\(base.name)'")
    }
    
    /// Obtiene el ID de la base asignada a un vehículo
    func getBaseIdForVehicle(_ vehicleId: String) async -> String? {
        let bases = await getAllBases()
        return bases.first(where: { $0.hasVehicle(vehicleId: vehicleId) })?.id
    }
    
    // MARK: - Status Management
    
    /// Activa una base
    func activate(baseId: String, actor: UserFS?) async throws {
        guard var base = await getBase(id: baseId) else {
            throw BaseServiceError.baseNotFound("Base no encontrada")
        }
        
        base.active = true
        base.updatedAt = Date()
        try await update(base, actor: actor)
        
        print("✅ Base '\(base.name)' activada")
    }
    
    /// Desactiva una base
    func deactivate(baseId: String, actor: UserFS?) async throws {
        guard var base = await getBase(id: baseId) else {
            throw BaseServiceError.baseNotFound("Base no encontrada")
        }
        
        base.active = false
        base.updatedAt = Date()
        try await update(base, actor: actor)
        
        print("✅ Base '\(base.name)' desactivada")
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        baseCache.removeAll()
        lastCacheUpdate = .distantPast
    }
    
    func clearCache(forBase baseId: String) {
        baseCache.removeValue(forKey: baseId)
    }
    
    private func isCacheValid() -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastCacheUpdate)
        return timeSinceLastUpdate < cacheExpiration
    }
    
    private func updateCacheTimestamp() {
        lastCacheUpdate = Date()
    }
    
    func preloadActiveBases() async {
        _ = await getActiveBases()
        updateCacheTimestamp()
        print("📦 Bases activas pre-cargadas en caché")
    }
}

// MARK: - Error Types

enum BaseServiceError: LocalizedError {
    case unauthorized(String)
    case baseNotFound(String)
    case duplicateCode(String)
    case invalidData(String)
    case hasVehicles(String)
    case firestoreError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let message):
            return "❌ Sin autorización: \(message)"
        case .baseNotFound(let message):
            return "❌ Base no encontrada: \(message)"
        case .duplicateCode(let message):
            return "❌ Código duplicado: \(message)"
        case .invalidData(let message):
            return "❌ Datos inválidos: \(message)"
        case .hasVehicles(let message):
            return "❌ \(message)"
        case .firestoreError(let error):
            return "❌ Error de Firestore: \(error.localizedDescription)"
        }
    }
}

// MARK: - Statistics & Helpers

extension BaseService {
    /// Obtiene estadísticas de bases
    func getStatistics() async -> (total: Int, active: Int, withVehicles: Int, withoutVehicles: Int) {
        let allBases = await getAllBases(includeInactive: true)
        let activeBases = allBases.filter { $0.active }
        let withVehicles = allBases.filter { $0.hasVehicles }
        let withoutVehicles = allBases.filter { !$0.hasVehicles }
        
        return (
            total: allBases.count,
            active: activeBases.count,
            withVehicles: withVehicles.count,
            withoutVehicles: withoutVehicles.count
        )
    }
    
    /// Busca bases por nombre
    func searchBases(by searchText: String) async -> [BaseFS] {
        let allBases = await getAllBases()
        
        guard !searchText.isEmpty else { return allBases }
        
        let lowercased = searchText.lowercased()
        return allBases.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.code.lowercased().contains(lowercased) ||
            ($0.address.lowercased().contains(lowercased))
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension BaseService {
    func printCacheStatus() {
        print("📊 BaseService Cache Status:")
        print("   Bases en caché: \(baseCache.count)")
        print("   Última actualización: \(lastCacheUpdate)")
        print("   Caché válido: \(isCacheValid())")
    }
    
    func printAllBases() async {
        let bases = await getAllBases(includeInactive: true)
        print("📋 Todas las bases (\(bases.count)):")
        for base in bases {
            print("   \(base.code) - \(base.name) (\(base.active ? "Activa" : "Inactiva")) - \(base.vehicleCountText)")
        }
    }
}
#endif
