//
//  KitService.swift
//  AmbuKit
//
//  Created by Adolfo on 18/11/25.
//  CORREGIDO: TAREA A+B - Uso correcto de async/await en creación
//


import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class KitService: ObservableObject {
    
    static let shared = KitService()
    private let db = Firestore.firestore()
    
    private var kitCache: [String: KitFS] = [:]
    private var kitItemCache: [String: KitItemFS] = [:]
    private let cacheExpiration: TimeInterval = 300
    private var lastCacheUpdate: Date = .distantPast
    
    private init() {}
    
    // MARK: - Kit CRUD
    
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
        guard !code.isEmpty else { throw KitServiceError.invalidData("El código no puede estar vacío") }
        guard !name.isEmpty else { throw KitServiceError.invalidData("El nombre no puede estar vacío") }
        
        if let _ = await getKitByCode(code) {
            throw KitServiceError.duplicateCode("Ya existe un kit con código '\(code)'")
        }
        
        if let vId = vehicleId, await VehicleService.shared.getVehicle(id: vId) == nil {
            throw KitServiceError.vehicleNotFound("Vehículo '\(vId)' no encontrado")
        }
        
        var kit = KitFS(code: code, name: name, type: type.rawValue, status: KitFS.Status(rawValue: status) ?? .active, vehicleId: vehicleId)
        
        let docRef = db.collection(KitFS.collectionName).document()
        kit.id = docRef.documentID
        
        let encodedData = try Firestore.Encoder().encode(kit)
        try await docRef.setData(encodedData)
        
        kitCache[docRef.documentID] = kit
        print("✅ Kit '\(name)' creado con ID: \(docRef.documentID)")
        return kit
    }
    
    func updateKit(kit: KitFS, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.update, on: .kit, for: actor) else {
            throw KitServiceError.unauthorized("No tienes permisos para actualizar kits")
        }
        guard let kitId = kit.id else { throw KitServiceError.invalidData("El kit no tiene ID válido") }
        guard !kit.code.isEmpty else { throw KitServiceError.invalidData("El código no puede estar vacío") }
        guard !kit.name.isEmpty else { throw KitServiceError.invalidData("El nombre no puede estar vacío") }
        
        var updatedKit = kit
        updatedKit.updatedAt = Date()
        
        let encodedData = try Firestore.Encoder().encode(updatedKit)
        try await db.collection(KitFS.collectionName).document(kitId).setData(encodedData, merge: true)
        kitCache[kitId] = updatedKit
        print("✅ Kit '\(kit.name)' actualizado")
    }
    
    func deleteKit(kitId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.delete, on: .kit, for: actor) else {
            throw KitServiceError.unauthorized("No tienes permisos para eliminar kits")
        }
        guard let kit = await getKit(id: kitId) else {
            throw KitServiceError.kitNotFound("Kit '\(kitId)' no encontrado")
        }
        let items = await getKitItems(kitId: kitId)
        guard items.isEmpty else {
            throw KitServiceError.kitHasItems("No se puede eliminar: tiene \(items.count) items")
        }
        
        try await db.collection(KitFS.collectionName).document(kitId).delete()
        kitCache.removeValue(forKey: kitId)
        print("✅ Kit '\(kit.name)' eliminado")
    }
    
    // MARK: - Kit Queries
    
    func getKit(id: String) async -> KitFS? {
        if isCacheValid(), let cached = kitCache[id] { return cached }
        do {
            let doc = try await db.collection(KitFS.collectionName).document(id).getDocument()
            guard let kit = try? doc.data(as: KitFS.self) else { return nil }
            kitCache[id] = kit
            return kit
        } catch { return nil }
    }
    
    func getKitByCode(_ code: String) async -> KitFS? {
        do {
            let snapshot = try await db.collection(KitFS.collectionName).whereField("code", isEqualTo: code).limit(to: 1).getDocuments()
            guard let doc = snapshot.documents.first, let kit = try? doc.data(as: KitFS.self) else { return nil }
            if let id = kit.id { kitCache[id] = kit }
            return kit
        } catch { return nil }
    }
    
    func getAllKits() async -> [KitFS] {
        do {
            let snapshot = try await db.collection(KitFS.collectionName).order(by: "code").getDocuments()
            let kits = snapshot.documents.compactMap { try? $0.data(as: KitFS.self) }
            kits.forEach { if let id = $0.id { kitCache[id] = $0 } }
            updateCacheTimestamp()
            return kits
        } catch { return [] }
    }
    
    func getKitsByVehicle(vehicleId: String) async -> [KitFS] {
        do {
            let snapshot = try await db.collection(KitFS.collectionName).whereField("vehicleId", isEqualTo: vehicleId).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: KitFS.self) }
        } catch { return [] }
    }
    
    func getUnassignedKits() async -> [KitFS] {
        do {
            let snapshot = try await db.collection(KitFS.collectionName).whereField("vehicleId", isEqualTo: NSNull()).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: KitFS.self) }
        } catch { return [] }
    }
    
    // MARK: - KitItem CRUD
    
    func addItemToKit(
        catalogItemId: String, kitId: String, quantity: Double, min: Double,
        max: Double? = nil, expiry: Date? = nil, lot: String? = nil, actor: UserFS?
    ) async throws -> KitItemFS {
        guard await AuthorizationServiceFS.allowed(.create, on: .kitItem, for: actor) else {
            throw KitServiceError.unauthorized("No tienes permisos para añadir items")
        }
        guard await getKit(id: kitId) != nil else { throw KitServiceError.kitNotFound("Kit no encontrado") }
        guard await CatalogService.shared.getItem(id: catalogItemId) != nil else {
            throw KitServiceError.catalogItemNotFound("Item del catálogo no encontrado")
        }
        guard quantity >= 0 else { throw KitServiceError.invalidData("Cantidad no puede ser negativa") }
        guard min >= 0 else { throw KitServiceError.invalidData("Mínimo no puede ser negativo") }
        if let m = max, m < min { throw KitServiceError.invalidData("Máximo no puede ser menor que mínimo") }
        
        let existing = await getKitItems(kitId: kitId)
        if existing.contains(where: { $0.catalogItemId == catalogItemId }) {
            throw KitServiceError.itemAlreadyInKit("El item ya existe en este kit")
        }
        
        var kitItem = KitItemFS(quantity: quantity, min: min, max: max, expiry: expiry, lot: lot, catalogItemId: catalogItemId, kitId: kitId)
        let docRef = db.collection(KitItemFS.collectionName).document()
        kitItem.id = docRef.documentID
        
        let encodedData = try Firestore.Encoder().encode(kitItem)
        try await docRef.setData(encodedData)
        
        kitItemCache[docRef.documentID] = kitItem
        print("✅ Item añadido al kit con ID: \(docRef.documentID)")
        return kitItem
    }
    
    func updateKitItem(kitItem: KitItemFS, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.update, on: .kitItem, for: actor) else {
            throw KitServiceError.unauthorized("No tienes permisos para actualizar items")
        }
        guard let itemId = kitItem.id else { throw KitServiceError.invalidData("Item sin ID") }
        guard kitItem.quantity >= 0 else { throw KitServiceError.invalidData("Cantidad no puede ser negativa") }
        
        var updated = kitItem
        updated.updatedAt = Date()
        
        let encodedData = try Firestore.Encoder().encode(updated)
        try await db.collection(KitItemFS.collectionName).document(itemId).setData(encodedData, merge: true)
        kitItemCache[itemId] = updated
        print("✅ Item del kit actualizado")
    }
    
    func updateKitThresholds(itemId: String, min: Double, max: Double?, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.canEditThresholds(actor) else {
            throw KitServiceError.unauthorized("No tienes permisos para editar umbrales")
        }
        guard min >= 0 else { throw KitServiceError.invalidData("Mínimo no puede ser negativo") }
        if let m = max, m < min { throw KitServiceError.invalidData("Máximo no puede ser menor que mínimo") }
        
        var updates: [String: Any] = ["min": min, "updatedAt": Timestamp(date: Date())]
        updates["max"] = max ?? NSNull()
        
        try await db.collection(KitItemFS.collectionName).document(itemId).updateData(updates)
        if var cached = kitItemCache[itemId] {
            cached.min = min; cached.max = max; cached.updatedAt = Date()
            kitItemCache[itemId] = cached
        }
        print("✅ Umbrales actualizados")
    }
    
    func removeItemFromKit(kitItemId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.delete, on: .kitItem, for: actor) else {
            throw KitServiceError.unauthorized("No tienes permisos para eliminar items")
        }
        try await db.collection(KitItemFS.collectionName).document(kitItemId).delete()
        kitItemCache.removeValue(forKey: kitItemId)
        print("✅ Item eliminado del kit")
    }
    
    // MARK: - KitItem Queries
    
    func getKitItem(id: String) async -> KitItemFS? {
        if let cached = kitItemCache[id] { return cached }
        do {
            let doc = try await db.collection(KitItemFS.collectionName).document(id).getDocument()
            guard let item = try? doc.data(as: KitItemFS.self) else { return nil }
            kitItemCache[id] = item
            return item
        } catch { return nil }
    }
    
    func getKitItems(kitId: String) async -> [KitItemFS] {
        do {
            let snapshot = try await db.collection(KitItemFS.collectionName).whereField("kitId", isEqualTo: kitId).getDocuments()
            let items = snapshot.documents.compactMap { try? $0.data(as: KitItemFS.self) }
            items.forEach { if let id = $0.id { kitItemCache[id] = $0 } }
            return items
        } catch { return [] }
    }
    
    // MARK: - Stock Operations
    
    func getLowStockItems() async -> [KitItemFS] {
        do {
            let snapshot = try await db.collection(KitItemFS.collectionName).getDocuments()
            return snapshot.documents.compactMap { doc -> KitItemFS? in
                guard let item = try? doc.data(as: KitItemFS.self) else { return nil }
                return item.isBelowMinimum ? item : nil
            }
        } catch { return [] }
    }
    
    func getExpiringItems() async -> [KitItemFS] {
        do {
            let thirtyDays = Date().addingTimeInterval(86400 * 30)
            let snapshot = try await db.collection(KitItemFS.collectionName)
                .whereField("expiry", isLessThanOrEqualTo: thirtyDays)
                .whereField("expiry", isGreaterThan: Date()).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: KitItemFS.self) }
        } catch { return [] }
    }
    
    func getExpiredItems() async -> [KitItemFS] {
        do {
            let snapshot = try await db.collection(KitItemFS.collectionName).whereField("expiry", isLessThan: Date()).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: KitItemFS.self) }
        } catch { return [] }
    }
    
    func getLowStockItemsInKit(kitId: String) async -> [KitItemFS] {
        return await getKitItems(kitId: kitId).filter { $0.isBelowMinimum }
    }
    
    // MARK: - Statistics
    
    func getKitStatistics(kitId: String) async -> (totalItems: Int, lowStockItems: Int, expiringItems: Int, expiredItems: Int) {
        let items = await getKitItems(kitId: kitId)
        return (items.count, items.filter { $0.isBelowMinimum }.count, items.filter { $0.isExpiringSoon }.count, items.filter { $0.isExpired }.count)
    }
    
    func getGlobalStatistics() async -> (totalKits: Int, assignedKits: Int, unassignedKits: Int, totalItems: Int, lowStockItems: Int, expiringItems: Int, expiredItems: Int) {
        let kits = await getAllKits()
        let assigned = kits.filter { $0.isAssigned }.count
        var totalItems = 0
        for kit in kits { totalItems += await getKitItems(kitId: kit.id ?? "").count }
        return (kits.count, assigned, kits.count - assigned, totalItems, await getLowStockItems().count, await getExpiringItems().count, await getExpiredItems().count)
    }
    
    func isKitComplete(kitId: String) async -> Bool { return await getLowStockItemsInKit(kitId: kitId).isEmpty }
    
    // MARK: - Cache
    
    func clearCache() { kitCache.removeAll(); kitItemCache.removeAll(); lastCacheUpdate = .distantPast }
    func clearKitCache() { kitCache.removeAll() }
    func clearKitItemCache() { kitItemCache.removeAll() }
    private func isCacheValid() -> Bool { Date().timeIntervalSince(lastCacheUpdate) < cacheExpiration }
    private func updateCacheTimestamp() { lastCacheUpdate = Date() }
    
    // MARK: - Search
    
    func searchKits(by text: String) async -> [KitFS] {
        let all = await getAllKits()
        guard !text.isEmpty else { return all }
        let l = text.lowercased()
        return all.filter { $0.code.lowercased().contains(l) || $0.name.lowercased().contains(l) }
    }
    
    func getKitsNeedingAudit() async -> [KitFS] { return await getAllKits().filter { $0.needsAudit } }
}

// MARK: - Errors

enum KitServiceError: LocalizedError {
    case unauthorized(String), kitNotFound(String), kitItemNotFound(String), vehicleNotFound(String)
    case catalogItemNotFound(String), duplicateCode(String), invalidData(String), kitHasItems(String)
    case itemAlreadyInKit(String), firestoreError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let m): return "❌ Sin autorización: \(m)"
        case .kitNotFound(let m): return "❌ Kit no encontrado: \(m)"
        case .kitItemNotFound(let m): return "❌ Item no encontrado: \(m)"
        case .vehicleNotFound(let m): return "❌ Vehículo no encontrado: \(m)"
        case .catalogItemNotFound(let m): return "❌ Item catálogo no encontrado: \(m)"
        case .duplicateCode(let m): return "❌ Código duplicado: \(m)"
        case .invalidData(let m): return "❌ Datos inválidos: \(m)"
        case .kitHasItems(let m): return "❌ Kit tiene items: \(m)"
        case .itemAlreadyInKit(let m): return "❌ Item ya existe: \(m)"
        case .firestoreError(let e): return "❌ Firestore: \(e.localizedDescription)"
        }
    }
}

#if DEBUG
extension KitService {
    func printCacheStatus() { print("📊 KitService: Kits=\(kitCache.count), Items=\(kitItemCache.count)") }
}
#endif
