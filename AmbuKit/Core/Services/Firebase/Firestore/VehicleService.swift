//
//  VehicleService.swift
//  AmbuKit
//
//  Created by Adolfo on 17/11/25.
//


import Foundation
import FirebaseFirestore
import Combine

/// Servicio para gestionar Vehículos en Firestore
/// Implementa CRUD completo con validación de permisos y cache
@MainActor
final class VehicleService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = VehicleService()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    
    // MARK: - Cache
    
    /// Cache de vehículos (vehicleId -> VehicleFS)
    private var vehicleCache: [String: VehicleFS] = [:]
    
    /// Tiempo de expiración del caché (5 minutos)
    private let cacheExpiration: TimeInterval = 300
    
    /// Última actualización del caché
    private var lastCacheUpdate: Date = .distantPast
    
    // MARK: - Initialization
    
    private init() {
        // Private para forzar uso del singleton
    }
    
    // MARK: - CRUD Operations
    
    /// Crea un nuevo vehículo en Firestore
    /// - Parameters:
    ///   - code: Código único del vehículo (ej: "AMB-001", "SVA-2401")
    ///   - plate: Matrícula del vehículo (opcional)
    ///   - type: Tipo de vehículo (ej: "SVB", "SVA", "SVAe")
    ///   - baseId: ID de la base a la que se asigna (opcional)
    ///   - actor: Usuario que realiza la acción
    /// - Returns: VehicleFS creado
    /// - Throws: VehicleServiceError si hay problemas de permisos o datos
    ///
    /// **Permisos requeridos:**
    /// - Programador: ✅ Permitido
    /// - Logística: ✅ Permitido
    /// - Sanitario: ❌ NO permitido
    ///
    /// **Validaciones:**
    /// - El código no puede estar vacío
    /// - El código debe ser único (no puede haber otro vehículo con el mismo código)
    /// - El tipo no puede estar vacío
    ///
    /// - Example:
    /// ```swift
    /// let vehicle = try await VehicleService.shared.create(
    ///     code: "SVA-2401",
    ///     plate: "1234-ABC",
    ///     type: "SVA",
    ///     baseId: "base_bilbao1",
    ///     actor: currentUser
    /// )
    /// ```
    func create(
        code: String,
        plate: String? = nil,
        type: String,
        baseId: String? = nil,
        actor: UserFS?
    ) async throws -> VehicleFS {
        // 1. Validar permisos
        guard await AuthorizationServiceFS.allowed(.create, on: .vehicle, for: actor) else {
            throw VehicleServiceError.unauthorized("No tienes permisos para crear vehículos")
        }
        
        // 2. Validar datos
        guard !code.isEmpty else {
            throw VehicleServiceError.invalidData("El código no puede estar vacío")
        }
        
        guard !type.isEmpty else {
            throw VehicleServiceError.invalidData("El tipo no puede estar vacío")
        }
        
        // 3. Verificar código duplicado
        if let _ = await getVehicleByCode(code) {
            throw VehicleServiceError.duplicateCode("Ya existe un vehículo con código '\(code)'")
        }
        
        // 4. Crear vehículo
        var vehicle = VehicleFS(
            code: code,
            plate: plate,
            type: VehicleFS.VehicleType(rawValue: type) ?? .svb,  // ✅ Cambiado de .ambulance a .svb
            baseId: baseId
        )
        
        // 5. Guardar en Firestore
        do {
            let docRef = try db.collection(VehicleFS.collectionName).addDocument(from: vehicle)
            vehicle.id = docRef.documentID
            
            // 6. Actualizar cache
            if let id = vehicle.id {
                vehicleCache[id] = vehicle
                updateCacheTimestamp()
            }
            
            // 7. Auditoría (cuando AuditServiceFS exista)
            // await AuditServiceFS.log(.create, entity: .vehicle, entityId: vehicle.id ?? "", actor: actor)
            
            print("✅ Vehículo '\(code)' creado correctamente")
            return vehicle
            
        } catch {
            print("❌ Error creando vehículo: \(error.localizedDescription)")
            throw VehicleServiceError.firestoreError(error)
        }
    }
    
    /// Actualiza un vehículo existente en Firestore
    /// - Parameters:
    ///   - vehicle: Vehículo con los datos actualizados
    ///   - actor: Usuario que realiza la acción
    /// - Throws: VehicleServiceError si hay problemas de permisos o datos
    ///
    /// **Permisos requeridos:**
    /// - Programador: ✅ Permitido
    /// - Logística: ✅ Permitido
    /// - Sanitario: ❌ NO permitido
    ///
    /// **Validaciones:**
    /// - El vehículo debe tener un ID válido
    /// - El código no puede estar vacío
    /// - El tipo no puede estar vacío
    ///
    /// - Example:
    /// ```swift
    /// var vehicle = await VehicleService.shared.getVehicle(id: "vehicle_id")
    /// vehicle?.plate = "9999-XYZ"
    /// try await VehicleService.shared.update(vehicle: vehicle!, actor: currentUser)
    /// ```
    func update(vehicle: VehicleFS, actor: UserFS?) async throws {
        // 1. Validar permisos
        guard await AuthorizationServiceFS.allowed(.update, on: .vehicle, for: actor) else {
            throw VehicleServiceError.unauthorized("No tienes permisos para actualizar vehículos")
        }
        
        // 2. Validar datos
        guard let vehicleId = vehicle.id else {
            throw VehicleServiceError.invalidData("El vehículo no tiene ID válido")
        }
        
        guard !vehicle.code.isEmpty else {
            throw VehicleServiceError.invalidData("El código no puede estar vacío")
        }
        
        guard !vehicle.type.isEmpty else {
            throw VehicleServiceError.invalidData("El tipo no puede estar vacío")
        }
        
        // 3. Actualizar timestamp
        var updatedVehicle = vehicle
        updatedVehicle.updatedAt = Date()
        
        // 4. Guardar en Firestore
        do {
            try db.collection(VehicleFS.collectionName)
                .document(vehicleId)
                .setData(from: updatedVehicle, merge: true)
            
            // 5. Actualizar cache
            vehicleCache[vehicleId] = updatedVehicle
            
            // 6. Auditoría
            // await AuditServiceFS.log(.update, entity: .vehicle, entityId: vehicleId, actor: actor)
            
            print("✅ Vehículo '\(vehicle.code)' actualizado correctamente")
            
        } catch {
            print("❌ Error actualizando vehículo: \(error.localizedDescription)")
            throw VehicleServiceError.firestoreError(error)
        }
    }
    
    /// Elimina un vehículo de Firestore
    /// - Parameters:
    ///   - vehicleId: ID del vehículo a eliminar
    ///   - actor: Usuario que realiza la acción
    /// - Throws: VehicleServiceError si hay problemas de permisos o el vehículo tiene kits asignados
    ///
    /// **Permisos requeridos:**
    /// - Programador: ✅ Permitido
    /// - Logística: ❌ NO permitido (solo puede crear y actualizar)
    /// - Sanitario: ❌ NO permitido
    ///
    /// **Validaciones:**
    /// - El vehículo no puede tener kits asignados
    /// - El vehículo debe existir
    ///
    /// - Example:
    /// ```swift
    /// try await VehicleService.shared.delete(vehicleId: "vehicle_id", actor: currentUser)
    /// ```
    func delete(vehicleId: String, actor: UserFS?) async throws {
        // 1. Validar permisos
        guard await AuthorizationServiceFS.allowed(.delete, on: .vehicle, for: actor) else {
            throw VehicleServiceError.unauthorized("No tienes permisos para eliminar vehículos")
        }
        
        // 2. Verificar que existe
        guard let vehicle = await getVehicle(id: vehicleId) else {
            throw VehicleServiceError.vehicleNotFound("Vehículo con ID '\(vehicleId)' no encontrado")
        }
        
        // 3. Validar que no tiene kits asignados
        if vehicle.hasKits {
            throw VehicleServiceError.hasKits("No se puede eliminar el vehículo porque tiene \(vehicle.kitCount) kit(s) asignado(s)")
        }
        
        // 4. Eliminar de Firestore
        do {
            try await db.collection(VehicleFS.collectionName)
                .document(vehicleId)
                .delete()
            
            // 5. Eliminar del cache
            vehicleCache.removeValue(forKey: vehicleId)
            
            // 6. Auditoría
            // await AuditServiceFS.log(.delete, entity: .vehicle, entityId: vehicleId, actor: actor)
            
            print("✅ Vehículo '\(vehicle.code)' eliminado correctamente")
            
        } catch {
            print("❌ Error eliminando vehículo: \(error.localizedDescription)")
            throw VehicleServiceError.firestoreError(error)
        }
    }
    
    // MARK: - Query Operations
    
    /// Obtiene un vehículo por su ID
    /// - Parameter id: ID del vehículo en Firestore
    /// - Returns: VehicleFS si existe, nil si no
    func getVehicle(id: String) async -> VehicleFS? {
        // Verificar cache primero
        if isCacheValid(), let cached = vehicleCache[id] {
            return cached
        }
        
        do {
            let document = try await db.collection(VehicleFS.collectionName)
                .document(id)
                .getDocument()
            
            guard let vehicle = VehicleFS.from(snapshot: document) else {
                return nil
            }
            
            // Actualizar cache
            vehicleCache[id] = vehicle
            return vehicle
            
        } catch {
            print("❌ Error obteniendo vehículo '\(id)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Obtiene un vehículo por su código único
    /// - Parameter code: Código del vehículo (ej: "SVA-2401")
    /// - Returns: VehicleFS si existe, nil si no
    func getVehicleByCode(_ code: String) async -> VehicleFS? {
        do {
            let snapshot = try await db.collection(VehicleFS.collectionName)
                .whereField("code", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = snapshot.documents.first,
                  let vehicle = VehicleFS.from(snapshot: document) else {
                return nil
            }
            
            // Actualizar cache
            if let id = vehicle.id {
                vehicleCache[id] = vehicle
            }
            
            return vehicle
            
        } catch {
            print("❌ Error obteniendo vehículo por código '\(code)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Obtiene todos los vehículos
    /// - Returns: Array de todos los vehículos ordenados por código
    func getAllVehicles() async -> [VehicleFS] {
        do {
            let snapshot = try await db.collection(VehicleFS.collectionName)
                .order(by: "code")
                .getDocuments()
            
            let vehicles = snapshot.documents.compactMap { doc -> VehicleFS? in
                VehicleFS.from(snapshot: doc)
            }
            
            // Actualizar cache
            vehicles.forEach { vehicle in
                if let id = vehicle.id {
                    vehicleCache[id] = vehicle
                }
            }
            
            updateCacheTimestamp()
            return vehicles
            
        } catch {
            print("❌ Error obteniendo todos los vehículos: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Obtiene vehículos de una base específica
    /// - Parameter baseId: ID de la base
    /// - Returns: Array de vehículos asignados a esa base
    func getVehiclesByBase(baseId: String) async -> [VehicleFS] {
        do {
            let snapshot = try await db.collection(VehicleFS.collectionName)
                .whereField("baseId", isEqualTo: baseId)
                .order(by: "code")
                .getDocuments()
            
            let vehicles = snapshot.documents.compactMap { doc -> VehicleFS? in
                VehicleFS.from(snapshot: doc)
            }
            
            // Actualizar cache
            vehicles.forEach { vehicle in
                if let id = vehicle.id {
                    vehicleCache[id] = vehicle
                }
            }
            
            return vehicles
            
        } catch {
            print("❌ Error obteniendo vehículos de base '\(baseId)': \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Assignment Operations
    
    /// Asigna o desasigna un vehículo a una base
    /// - Parameters:
    ///   - vehicleId: ID del vehículo
    ///   - baseId: ID de la base (nil para desasignar)
    ///   - actor: Usuario que realiza la acción
    /// - Throws: VehicleServiceError si hay problemas
    ///
    /// **Permisos requeridos:**
    /// - Programador: ✅ Permitido
    /// - Logística: ✅ Permitido
    /// - Sanitario: ❌ NO permitido
    ///
    /// - Example:
    /// ```swift
    /// // Asignar a base
    /// try await VehicleService.shared.assignToBase(
    ///     vehicleId: "vehicle_id",
    ///     baseId: "base_id",
    ///     actor: currentUser
    /// )
    ///
    /// // Desasignar de base
    /// try await VehicleService.shared.assignToBase(
    ///     vehicleId: "vehicle_id",
    ///     baseId: nil,
    ///     actor: currentUser
    /// )
    /// ```
    func assignToBase(vehicleId: String, baseId: String?, actor: UserFS?) async throws {
        // 1. Validar permisos (esto es una actualización)
        guard await AuthorizationServiceFS.allowed(.update, on: .vehicle, for: actor) else {
            throw VehicleServiceError.unauthorized("No tienes permisos para asignar vehículos")
        }
        
        // 2. Obtener vehículo
        guard var vehicle = await getVehicle(id: vehicleId) else {
            throw VehicleServiceError.vehicleNotFound("Vehículo no encontrado")
        }
        
        // 3. Actualizar baseId
        vehicle.baseId = baseId
        
        // 4. Guardar cambios
        try await update(vehicle: vehicle, actor: actor)
        
        if let baseId = baseId {
            print("✅ Vehículo '\(vehicle.code)' asignado a base '\(baseId)'")
        } else {
            print("✅ Vehículo '\(vehicle.code)' desasignado de su base")
        }
    }
    
    /// Obtiene vehículos sin base asignada
    /// - Returns: Array de vehículos sin base
    ///
    /// **Permisos:** No requiere permisos (lectura pública)
    ///
    /// - Example:
    /// ```swift
    /// let unassigned = await VehicleService.shared.getVehiclesWithoutBase()
    /// print("Vehículos sin asignar: \(unassigned.count)")
    /// ```
    func getVehiclesWithoutBase() async -> [VehicleFS] {
        let allVehicles = await getAllVehicles()
        return allVehicles.filter { !$0.hasBase }
    }
    
    /// Obtiene vehículos con kits asignados
    /// - Returns: Array de vehículos que tienen kits
    ///
    /// **Permisos:** No requiere permisos (lectura pública)
    ///
    /// - Example:
    /// ```swift
    /// let withKits = await VehicleService.shared.getVehiclesWithKits()
    /// print("Vehículos con kits: \(withKits.count)")
    /// ```
    func getVehiclesWithKits() async -> [VehicleFS] {
        let allVehicles = await getAllVehicles()
        return allVehicles.filter { $0.hasKits }
    }
    
    // MARK: - Cache Management
    
    /// Limpia todo el caché de vehículos
    func clearCache() {
        vehicleCache.removeAll()
        lastCacheUpdate = .distantPast
    }
    
    /// Limpia el caché de un vehículo específico
    /// - Parameter vehicleId: ID del vehículo
    func clearCache(forVehicle vehicleId: String) {
        vehicleCache.removeValue(forKey: vehicleId)
    }
    
    /// Verifica si el caché es válido (no ha expirado)
    /// - Returns: true si el caché es válido
    private func isCacheValid() -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastCacheUpdate)
        return timeSinceLastUpdate < cacheExpiration
    }
    
    /// Actualiza el timestamp del caché
    private func updateCacheTimestamp() {
        lastCacheUpdate = Date()
    }
    
    /// Pre-carga todos los vehículos en caché
    /// Útil para llamar al inicio de la app o después de hacer login
    func preloadVehicles() async {
        _ = await getAllVehicles()
        updateCacheTimestamp()
        print("📦 Vehículos pre-cargados en caché")
    }
}

// MARK: - Error Types

/// Errores específicos del servicio de vehículos
enum VehicleServiceError: LocalizedError {
    case unauthorized(String)
    case vehicleNotFound(String)
    case duplicateCode(String)
    case invalidData(String)
    case hasKits(String)
    case firestoreError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let message):
            return "❌ Sin autorización: \(message)"
        case .vehicleNotFound(let message):
            return "❌ Vehículo no encontrado: \(message)"
        case .duplicateCode(let message):
            return "❌ Código duplicado: \(message)"
        case .invalidData(let message):
            return "❌ Datos inválidos: \(message)"
        case .hasKits(let message):
            return "❌ \(message)"
        case .firestoreError(let error):
            return "❌ Error de Firestore: \(error.localizedDescription)"
        }
    }
}

// MARK: - Statistics & Search

extension VehicleService {
    /// Obtiene estadísticas de vehículos
    /// - Returns: Tupla con estadísticas (total, conBase, sinBase, conKits)
    ///
    /// - Example:
    /// ```swift
    /// let stats = await VehicleService.shared.getStatistics()
    /// print("Total: \(stats.total), Con base: \(stats.withBase)")
    /// ```
    func getStatistics() async -> (total: Int, withBase: Int, withoutBase: Int, withKits: Int) {
        let allVehicles = await getAllVehicles()
        let withBase = allVehicles.filter { $0.hasBase }
        let withoutBase = allVehicles.filter { !$0.hasBase }
        let withKits = allVehicles.filter { $0.hasKits }
        
        return (
            total: allVehicles.count,
            withBase: withBase.count,
            withoutBase: withoutBase.count,
            withKits: withKits.count
        )
    }
    
    /// Busca vehículos por texto
    /// - Parameter searchText: Texto a buscar (código, matrícula o tipo)
    /// - Returns: Array de vehículos que coinciden con la búsqueda
    ///
    /// - Example:
    /// ```swift
    /// let results = await VehicleService.shared.searchVehicles(by: "SVA")
    /// print("Encontrados: \(results.count) vehículos")
    /// ```
    func searchVehicles(by searchText: String) async -> [VehicleFS] {
        let allVehicles = await getAllVehicles()
        
        guard !searchText.isEmpty else { return allVehicles }
        
        let lowercased = searchText.lowercased()
        return allVehicles.filter {
            $0.code.lowercased().contains(lowercased) ||
            ($0.plate?.lowercased().contains(lowercased) ?? false) ||  // ✅ Corregido: plate es opcional
            $0.type.lowercased().contains(lowercased)
        }
    }
    
    /// Obtiene vehículos por tipo
    /// - Parameter type: Tipo de vehículo (ej: "SVA", "SVB")
    /// - Returns: Array de vehículos de ese tipo
    ///
    /// - Example:
    /// ```swift
    /// let svaVehicles = await VehicleService.shared.getVehiclesByType("SVA")
    /// print("SVA: \(svaVehicles.count)")
    /// ```
    func getVehiclesByType(_ type: String) async -> [VehicleFS] {
        let allVehicles = await getAllVehicles()
        return allVehicles.filter { $0.type == type }
    }
    
    /// Obtiene vehículos por tipo usando el enum
    /// - Parameter type: Tipo de vehículo como enum
    /// - Returns: Array de vehículos de ese tipo
    func getVehiclesByType(_ type: VehicleFS.VehicleType) async -> [VehicleFS] {
        await getVehiclesByType(type.rawValue)
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension VehicleService {
    /// Imprime el estado del caché (solo para debug)
    func printCacheStatus() {
        print("📊 VehicleService Cache Status:")
        print("   Vehículos en caché: \(vehicleCache.count)")
        print("   Última actualización: \(lastCacheUpdate)")
        print("   Caché válido: \(isCacheValid())")
    }
    
    /// Imprime todos los vehículos (debug)
    func printAllVehicles() async {
        let vehicles = await getAllVehicles()
        print("📋 Todos los vehículos (\(vehicles.count)):")
        for vehicle in vehicles {
            let baseInfo = vehicle.hasBase ? "Base: \(vehicle.baseId!)" : "Sin base"
            let kitsInfo = vehicle.hasKits ? "\(vehicle.kitCount) kits" : "Sin kits"
            print("   \(vehicle.code) - \(vehicle.type) - \(baseInfo) - \(kitsInfo)")
        }
    }
}
#endif
