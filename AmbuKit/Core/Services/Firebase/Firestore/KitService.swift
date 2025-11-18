//
//  KitService.swift
//  AmbuKit
//
//  Created by Adolfo on 18/11/25.
//


import Foundation
import FirebaseFirestore
import Combine

/// Servicio para gestionar Kits y sus Items en Firestore
/// Maneja 2 entidades: Kit y KitItem
/// Implementa CRUD completo con operaciones de stock y validaciones
@MainActor
final class KitService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = KitService()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    
    // MARK: - Cache
    
    /// Cache de kits (kitId -> KitFS)
    private var kitCache: [String: KitFS] = [:]
    
    /// Cache de items de kit (kitItemId -> KitItemFS)
    private var kitItemCache: [String: KitItemFS] = [:]
    
    /// Tiempo de expiración del cache (5 minutos)
    private let cacheExpiration: TimeInterval = 300
    
    /// Última actualización del cache
    private var lastCacheUpdate: Date = .distantPast
    
    // MARK: - Initialization
    
    private init() {
        // Private para forzar uso del singleton
    }
    
    // MARK: - Kit CRUD
    
    /// Crea un nuevo kit
    func createKit(
        code: String,
        name: String,
        type: KitType,
        status: String = "ok",
        vehicleId: String? = nil,
        actor: UserFS?
    ) async throws -> KitFS {
        guard await AuthorizationServiceFS.allowed(.create, on: .kit, for: actor) else {
            throw KitServiceError.unauthorized("No tienes permisos para crear kits")
        }
        
        guard !code.isEmpty else {
            throw KitServiceError.invalidData("El código no puede estar vacío")
        }
        
        guard !name.isEmpty else {
            throw KitServiceError.invalidData("El nombre no puede estar vacío")
        }
        
        if let _ = await getKitByCode(code) {
            throw KitServiceError.duplicateCode("Ya existe un kit con código '\(code)'")
        }
        
        if let vId = vehicleId {
            let vehicle = await VehicleService.shared.getVehicle(id: vId)
            guard vehicle != nil else {
                throw KitServiceError.vehicleNotFound("Vehículo '\(vId)' no encontrado")
            }
        }
        
        var kit = KitFS(
            code: code,
            name: name,
            type: type,
            status: status,
            vehicleId: vehicleId
        )
        
        do {
            let docRef = try db.collection(KitFS.collectionName).addDocument(from: kit)
            kit.id = docRef.documentID
            
            if let id = kit.id {
                kitCache[id] = kit
                updateCacheTimestamp()
            }
            
            print("✅ Kit '\(name)' (\(code)) creado correctamente")
            return kit
            
        } catch {
            print("❌ Error creando kit: \(error.localizedDescription)")
            throw KitServiceError.firestoreError(error)
        }
    }
    
    /// Actualiza un kit
    func updateKit(kit: KitFS, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.update, on: .kit, for: actor) else {
            throw KitServiceError.unauthorized("No tienes permisos para actualizar kits")
        }
        
        guard let kitId = kit.id else {
            throw KitServiceError.invalidData("El kit no tiene ID válido")
        }
        
        guard !kit.code.isEmpty else {
            throw KitServiceError.invalidData("El código no puede estar vacío")
        }
        
        guard !kit.name.isEmpty else {
            throw KitServiceError.invalidData("El nombre no puede estar vacío")
        }
        
        var updatedKit = kit
        updatedKit.updatedAt = Date()
        
        do {
            try db.collection(KitFS.collectionName)
                .document(kitId)
                .setData(from: updatedKit, merge: true)
            
            kitCache[kitId] = updatedKit
            
            print("✅ Kit '\(kit.name)' actualizado correctamente")
            
        } catch {
            print("❌ Error actualizando kit: \(error.localizedDescription)")
            throw KitServiceError.firestoreError(error)
        }
    }
    
    /// Elimina un kit
    func deleteKit(kitId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.delete, on: .kit, for: actor) else {
            throw KitServiceError.unauthorized("No tienes permisos para eliminar kits")
        }
        
        guard let kit = await getKit(id: kitId) else {
            throw KitServiceError.kitNotFound("Kit con ID '\(kitId)' no encontrado")
        }
        
        let items = await getKitItems(kitId: kitId)
        guard items.isEmpty else {
            throw KitServiceError.kitHasItems("No se puede eliminar el kit '\(kit.name)' porque tiene \(items.count) items")
        }
        
        do {
            try await db.collection(KitFS.collectionName)
                .document(kitId)
                .delete()
            
            kitCache.removeValue(forKey: kitId)
            
            print("✅ Kit '\(kit.name)' eliminado correctamente")
            
        } catch {
            print("❌ Error eliminando kit: \(error.localizedDescription)")
            throw KitServiceError.firestoreError(error)
        }
    }
    
    // MARK: - Kit Queries
    
    func getKit(id: String) async -> KitFS? {
        if isCacheValid(), let cached = kitCache[id] {
            return cached
        }
        
        do {
            let document = try await db.collection(KitFS.collectionName)
                .document(id)
                .getDocument()
            
            guard let kit = KitFS.from(snapshot: document) else {
                return nil
            }
            
            kitCache[id] = kit
            return kit
            
        } catch {
            print("❌ Error obteniendo kit '\(id)': \(error.localizedDescription)")
            return nil
        }
    }
    
    func getKitByCode(_ code: String) async -> KitFS? {
        do {
            let snapshot = try await db.collection(KitFS.collectionName)
                .whereField("code", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = snapshot.documents.first,
                  let kit = KitFS.from(snapshot: document) else {
                return nil
            }
            
            if let id = kit.id {
                kitCache[id] = kit
            }
            
            return kit
            
        } catch {
            print("❌ Error obteniendo kit por código '\(code)': \(error.localizedDescription)")
            return nil
        }
    }
    
    func getAllKits() async -> [KitFS] {
        do {
            let snapshot = try await db.collection(KitFS.collectionName)
                .order(by: "code")
                .getDocuments()
            
            let kits = snapshot.documents.compactMap { doc -> KitFS? in
                KitFS.from(snapshot: doc)
            }
            
            kits.forEach { kit in
                if let id = kit.id {
                    kitCache[id] = kit
                }
            }
            
            updateCacheTimestamp()
            return kits
            
        } catch {
            print("❌ Error obteniendo todos los kits: \(error.localizedDescription)")
            return []
        }
    }
    
    func getKitsByVehicle(vehicleId: String) async -> [KitFS] {
        do {
            let snapshot = try await db.collection(KitFS.collectionName)
                .whereField("vehicleId", isEqualTo: vehicleId)
                .order(by: "code")
                .getDocuments()
            
            let kits = snapshot.documents.compactMap { doc -> KitFS? in
                KitFS.from(snapshot: doc)
            }
            
            kits.forEach { kit in
                if let id = kit.id {
                    kitCache[id] = kit
                }
            }
            
            return kits
            
        } catch {
            print("❌ Error obteniendo kits del vehículo '\(vehicleId)': \(error.localizedDescription)")
            return []
        }
    }
    
    func getUnassignedKits() async -> [KitFS] {
        do {
            let snapshot = try await db.collection(KitFS.collectionName)
                .whereField("vehicleId", isEqualTo: NSNull())
                .order(by: "code")
                .getDocuments()
            
            return snapshot.documents.compactMap { doc -> KitFS? in
                KitFS.from(snapshot: doc)
            }
            
        } catch {
            print("❌ Error obteniendo kits sin asignar: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - KitItem CRUD
    
    func addItemToKit(
        catalogItemId: String,
        kitId: String,
        quantity: Double,
        min: Double,
        max: Double? = nil,
        expiry: Date? = nil,
        lot: String? = nil,
        actor: UserFS?
    ) async throws -> KitItemFS {
        guard await AuthorizationServiceFS.allowed(.create, on: .kitItem, for: actor) else {
            throw KitServiceError.unauthorized("No tienes permisos para añadir items a kits")
        }
        
        guard let _ = await getKit(id: kitId) else {
            throw KitServiceError.kitNotFound("Kit '\(kitId)' no encontrado")
        }
        
        let catalogItem = await CatalogService.shared.getItem(id: catalogItemId)
        guard catalogItem != nil else {
            throw KitServiceError.catalogItemNotFound("Item del catálogo '\(catalogItemId)' no encontrado")
        }
        
        guard quantity >= 0 else {
            throw KitServiceError.invalidData("La cantidad no puede ser negativa")
        }
        
        guard min >= 0 else {
            throw KitServiceError.invalidData("El mínimo no puede ser negativo")
        }
        
        if let maxValue = max, maxValue < min {
            throw KitServiceError.invalidData("El máximo no puede ser menor que el mínimo")
        }
        
        let existingItems = await getKitItems(kitId: kitId)
        if existingItems.contains(where: { $0.catalogItemId == catalogItemId }) {
            throw KitServiceError.itemAlreadyInKit("El item ya existe en este kit")
        }
        
        var kitItem = KitItemFS(
            quantity: quantity,
            min: min,
            max: max,
            expiry: expiry,
            lot: lot,
            catalogItemId: catalogItemId,
            kitId: kitId
        )
        
        do {
            let docRef = try db.collection(KitItemFS.collectionName).addDocument(from: kitItem)
            kitItem.id = docRef.documentID
            
            if let id = kitItem.id {
                kitItemCache[id] = kitItem
            }
            
            print("✅ Item añadido al kit correctamente")
            return kitItem
            
        } catch {
            print("❌ Error añadiendo item al kit: \(error.localizedDescription)")
            throw KitServiceError.firestoreError(error)
        }
    }
    
    func updateKitItem(kitItem: KitItemFS, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.update, on: .kitItem, for: actor) else {
            throw KitServiceError.unauthorized("No tienes permisos para actualizar items de kits")
        }
        
        guard let itemId = kitItem.id else {
            throw KitServiceError.invalidData("El item no tiene ID válido")
        }
        
        guard kitItem.quantity >= 0 else {
            throw KitServiceError.invalidData("La cantidad no puede ser negativa")
        }
        
        guard kitItem.min >= 0 else {
            throw KitServiceError.invalidData("El mínimo no puede ser negativo")
        }
        
        var updatedItem = kitItem
        updatedItem.updatedAt = Date()
        
        do {
            try db.collection(KitItemFS.collectionName)
                .document(itemId)
                .setData(from: updatedItem, merge: true)
            
            kitItemCache[itemId] = updatedItem
            
            print("✅ Item del kit actualizado correctamente")
            
        } catch {
            print("❌ Error actualizando item del kit: \(error.localizedDescription)")
            throw KitServiceError.firestoreError(error)
        }
    }
    
    func removeItemFromKit(kitItemId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.delete, on: .kitItem, for: actor) else {
            throw KitServiceError.unauthorized("No tienes permisos para eliminar items de kits")
        }
        
        guard let _ = await getKitItem(id: kitItemId) else {
            throw KitServiceError.kitItemNotFound("Item '\(kitItemId)' no encontrado")
        }
        
        do {
            try await db.collection(KitItemFS.collectionName)
                .document(kitItemId)
                .delete()
            
            kitItemCache.removeValue(forKey: kitItemId)
            
            print("✅ Item eliminado del kit correctamente")
            
        } catch {
            print("❌ Error eliminando item del kit: \(error.localizedDescription)")
            throw KitServiceError.firestoreError(error)
        }
    }
    
    // MARK: - KitItem Queries
    
    func getKitItem(id: String) async -> KitItemFS? {
        if let cached = kitItemCache[id] {
            return cached
        }
        
        do {
            let document = try await db.collection(KitItemFS.collectionName)
                .document(id)
                .getDocument()
            
            guard let item = KitItemFS.from(snapshot: document) else {
                return nil
            }
            
            kitItemCache[id] = item
            return item
            
        } catch {
            print("❌ Error obteniendo item de kit '\(id)': \(error.localizedDescription)")
            return nil
        }
    }
    
    func getKitItems(kitId: String) async -> [KitItemFS] {
        do {
            let snapshot = try await db.collection(KitItemFS.collectionName)
                .whereField("kitId", isEqualTo: kitId)
                .getDocuments()
            
            let items = snapshot.documents.compactMap { doc -> KitItemFS? in
                KitItemFS.from(snapshot: doc)
            }
            
            items.forEach { item in
                if let id = item.id {
                    kitItemCache[id] = item
                }
            }
            
            return items
            
        } catch {
            print("❌ Error obteniendo items del kit '\(kitId)': \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Stock Operations
    
    func getLowStockItems() async -> [KitItemFS] {
        do {
            let snapshot = try await db.collection(KitItemFS.collectionName)
                .getDocuments()
            
            return snapshot.documents.compactMap { doc -> KitItemFS? in
                guard let item = KitItemFS.from(snapshot: doc) else { return nil }
                return item.isBelowMinimum ? item : nil
            }
            
        } catch {
            print("❌ Error obteniendo items con stock bajo: \(error.localizedDescription)")
            return []
        }
    }
    
    func getExpiringItems() async -> [KitItemFS] {
        do {
            let thirtyDaysFromNow = Date().addingTimeInterval(86400 * 30)
            
            let snapshot = try await db.collection(KitItemFS.collectionName)
                .whereField("expiry", isLessThanOrEqualTo: thirtyDaysFromNow)
                .whereField("expiry", isGreaterThan: Date())
                .getDocuments()
            
            return snapshot.documents.compactMap { doc -> KitItemFS? in
                KitItemFS.from(snapshot: doc)
            }
            
        } catch {
            print("❌ Error obteniendo items próximos a caducar: \(error.localizedDescription)")
            return []
        }
    }
    
    func getExpiredItems() async -> [KitItemFS] {
        do {
            let snapshot = try await db.collection(KitItemFS.collectionName)
                .whereField("expiry", isLessThan: Date())
                .getDocuments()
            
            return snapshot.documents.compactMap { doc -> KitItemFS? in
                KitItemFS.from(snapshot: doc)
            }
            
        } catch {
            print("❌ Error obteniendo items caducados: \(error.localizedDescription)")
            return []
        }
    }
    
    func getLowStockItemsInKit(kitId: String) async -> [KitItemFS] {
        let allItems = await getKitItems(kitId: kitId)
        return allItems.filter { $0.isBelowMinimum }
    }
    
    // MARK: - Statistics
    
    func getKitStatistics(kitId: String) async -> (
        totalItems: Int,
        lowStockItems: Int,
        expiringItems: Int,
        expiredItems: Int
    ) {
        let items = await getKitItems(kitId: kitId)
        
        let lowStock = items.filter { $0.isBelowMinimum }
        let expiring = items.filter { $0.isExpiringSoon }
        let expired = items.filter { $0.isExpired }
        
        return (
            totalItems: items.count,
            lowStockItems: lowStock.count,
            expiringItems: expiring.count,
            expiredItems: expired.count
        )
    }
    
    func getGlobalStatistics() async -> (
        totalKits: Int,
        assignedKits: Int,
        unassignedKits: Int,
        totalItems: Int,
        lowStockItems: Int,
        expiringItems: Int,
        expiredItems: Int
    ) {
        let kits = await getAllKits()
        let assigned = kits.filter { $0.isAssigned }
        
        let lowStock = await getLowStockItems()
        let expiring = await getExpiringItems()
        let expired = await getExpiredItems()
        
        var totalItems = 0
        for kit in kits {
            let items = await getKitItems(kitId: kit.id ?? "")
            totalItems += items.count
        }
        
        return (
            totalKits: kits.count,
            assignedKits: assigned.count,
            unassignedKits: kits.count - assigned.count,
            totalItems: totalItems,
            lowStockItems: lowStock.count,
            expiringItems: expiring.count,
            expiredItems: expired.count
        )
    }
    
    func isKitComplete(kitId: String) async -> Bool {
        let lowStockItems = await getLowStockItemsInKit(kitId: kitId)
        return lowStockItems.isEmpty
    }
    
    // MARK: - Cache
    
    func clearCache() {
        kitCache.removeAll()
        kitItemCache.removeAll()
        lastCacheUpdate = .distantPast
    }
    
    func clearKitCache() {
        kitCache.removeAll()
    }
    
    func clearKitItemCache() {
        kitItemCache.removeAll()
    }
    
    private func isCacheValid() -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastCacheUpdate)
        return timeSinceLastUpdate < cacheExpiration
    }
    
    private func updateCacheTimestamp() {
        lastCacheUpdate = Date()
    }
}

// MARK: - Errors

enum KitServiceError: LocalizedError {
    case unauthorized(String)
    case kitNotFound(String)
    case kitItemNotFound(String)
    case vehicleNotFound(String)
    case catalogItemNotFound(String)
    case duplicateCode(String)
    case invalidData(String)
    case kitHasItems(String)
    case itemAlreadyInKit(String)
    case firestoreError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let message):
            return "❌ Sin autorización: \(message)"
        case .kitNotFound(let message):
            return "❌ Kit no encontrado: \(message)"
        case .kitItemNotFound(let message):
            return "❌ Item de kit no encontrado: \(message)"
        case .vehicleNotFound(let message):
            return "❌ Vehículo no encontrado: \(message)"
        case .catalogItemNotFound(let message):
            return "❌ Item del catálogo no encontrado: \(message)"
        case .duplicateCode(let message):
            return "❌ Código duplicado: \(message)"
        case .invalidData(let message):
            return "❌ Datos inválidos: \(message)"
        case .kitHasItems(let message):
            return "❌ Kit tiene items: \(message)"
        case .itemAlreadyInKit(let message):
            return "❌ Item ya existe: \(message)"
        case .firestoreError(let error):
            return "❌ Error de Firestore: \(error.localizedDescription)"
        }
    }
}

// MARK: - Search

extension KitService {
    func searchKits(by searchText: String) async -> [KitFS] {
        let allKits = await getAllKits()
        
        guard !searchText.isEmpty else { return allKits }
        
        let lowercased = searchText.lowercased()
        return allKits.filter {
            $0.code.lowercased().contains(lowercased) ||
            $0.name.lowercased().contains(lowercased)
        }
    }
    
    func getKitsNeedingAudit() async -> [KitFS] {
        let allKits = await getAllKits()
        return allKits.filter { $0.needsAudit }
    }
}

// MARK: - Debug

#if DEBUG
extension KitService {
    func printCacheStatus() {
        print("📊 KitService Cache Status:")
        print("   Kits en cache: \(kitCache.count)")
        print("   Items en cache: \(kitItemCache.count)")
        print("   Última actualización: \(lastCacheUpdate)")
        print("   Cache válido: \(isCacheValid())")
    }
}
#endif
