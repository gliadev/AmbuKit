//
//  CatalogService.swift
//  AmbuKit
//
//  Created by Adolfo on 17/11/25.
//


import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class CatalogService: ObservableObject {
    
    static let shared = CatalogService()
    private let db = Firestore.firestore()
    
    private var itemCache: [String: CatalogItemFS] = [:]
    private var categoryCache: [String: CategoryFS] = [:]
    private var uomCache: [String: UnitOfMeasureFS] = [:]
    private let cacheExpiration: TimeInterval = 300
    private var lastCacheUpdate: Date = .distantPast
    
    private init() {}
    
    // MARK: - CatalogItem CRUD
    
    func createItem(
        code: String, name: String, description: String? = nil, critical: Bool = false,
        minStock: Double? = nil, maxStock: Double? = nil, categoryId: String? = nil, uomId: String? = nil, actor: UserFS?
    ) async throws -> CatalogItemFS {
        guard await AuthorizationServiceFS.allowed(.create, on: .catalogItem, for: actor) else {
            throw CatalogServiceError.unauthorized("No tienes permisos para crear items")
        }
        guard !code.isEmpty else { throw CatalogServiceError.invalidData("Código vacío") }
        guard !name.isEmpty else { throw CatalogServiceError.invalidData("Nombre vacío") }
        
        if let _ = await getItemByCode(code) {
            throw CatalogServiceError.duplicateCode("Ya existe item con código '\(code)'")
        }
        
        var item = CatalogItemFS(code: code, name: name, description: description, critical: critical, minStock: minStock, maxStock: maxStock, categoryId: categoryId, uomId: uomId)
        let docRef = db.collection(CatalogItemFS.collectionName).document()
        item.id = docRef.documentID
        
        let encodedData = try Firestore.Encoder().encode(item)
        try await docRef.setData(encodedData)
        
        itemCache[docRef.documentID] = item
        print("✅ Item '\(name)' creado con ID: \(docRef.documentID)")
        return item
    }
    
    func updateItem(item: CatalogItemFS, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.update, on: .catalogItem, for: actor) else {
            throw CatalogServiceError.unauthorized("No tienes permisos para actualizar items")
        }
        guard let itemId = item.id else { throw CatalogServiceError.invalidData("Item sin ID") }
        guard !item.code.isEmpty else { throw CatalogServiceError.invalidData("Código vacío") }
        guard !item.name.isEmpty else { throw CatalogServiceError.invalidData("Nombre vacío") }
        
        var updated = item
        updated.updatedAt = Date()
        
        let encodedData = try Firestore.Encoder().encode(updated)
        try await db.collection(CatalogItemFS.collectionName).document(itemId).setData(encodedData, merge: true)
        itemCache[itemId] = updated
        print("✅ Item '\(item.name)' actualizado")
    }
    
    func deleteItem(itemId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.delete, on: .catalogItem, for: actor) else {
            throw CatalogServiceError.unauthorized("No tienes permisos para eliminar items")
        }
        guard let item = await getItem(id: itemId) else {
            throw CatalogServiceError.itemNotFound("Item no encontrado")
        }
        
        try await db.collection(CatalogItemFS.collectionName).document(itemId).delete()
        itemCache.removeValue(forKey: itemId)
        print("✅ Item '\(item.name)' eliminado")
    }
    
    // MARK: - CatalogItem Queries
    
    func getItem(id: String) async -> CatalogItemFS? {
        if isCacheValid(), let cached = itemCache[id] { return cached }
        do {
            let doc = try await db.collection(CatalogItemFS.collectionName).document(id).getDocument()
            guard let item = try? doc.data(as: CatalogItemFS.self) else { return nil }
            itemCache[id] = item
            return item
        } catch { return nil }
    }
    
    func getItemByCode(_ code: String) async -> CatalogItemFS? {
        do {
            let snapshot = try await db.collection(CatalogItemFS.collectionName).whereField("code", isEqualTo: code).limit(to: 1).getDocuments()
            guard let doc = snapshot.documents.first, let item = try? doc.data(as: CatalogItemFS.self) else { return nil }
            if let id = item.id { itemCache[id] = item }
            return item
        } catch { return nil }
    }
    
    func getAllItems() async -> [CatalogItemFS] {
        do {
            let snapshot = try await db.collection(CatalogItemFS.collectionName).order(by: "code").getDocuments()
            let items = snapshot.documents.compactMap { try? $0.data(as: CatalogItemFS.self) }
            items.forEach { if let id = $0.id { itemCache[id] = $0 } }
            updateCacheTimestamp()
            return items
        } catch { return [] }
    }
    
    func getItemsByCategory(categoryId: String) async -> [CatalogItemFS] {
        do {
            let snapshot = try await db.collection(CatalogItemFS.collectionName).whereField("categoryId", isEqualTo: categoryId).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: CatalogItemFS.self) }
        } catch { return [] }
    }
    
    func getCriticalItems() async -> [CatalogItemFS] {
        do {
            let snapshot = try await db.collection(CatalogItemFS.collectionName).whereField("critical", isEqualTo: true).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: CatalogItemFS.self) }
        } catch { return [] }
    }
    
    // MARK: - Category CRUD
    
    func createCategory(code: String, name: String, icon: String? = nil, actor: UserFS?) async throws -> CategoryFS {
        guard await AuthorizationServiceFS.allowed(.create, on: .category, for: actor) else {
            throw CatalogServiceError.unauthorized("No tienes permisos para crear categorías")
        }
        guard !code.isEmpty else { throw CatalogServiceError.invalidData("Código vacío") }
        guard !name.isEmpty else { throw CatalogServiceError.invalidData("Nombre vacío") }
        
        if let _ = await getCategoryByCode(code) {
            throw CatalogServiceError.duplicateCode("Ya existe categoría con código '\(code)'")
        }
        
        var category = CategoryFS(code: code, name: name, icon: icon)
        let docRef = db.collection(CategoryFS.collectionName).document()
        category.id = docRef.documentID
        
        let encodedData = try Firestore.Encoder().encode(category)
        try await docRef.setData(encodedData)
        
        categoryCache[docRef.documentID] = category
        print("✅ Categoría '\(name)' creada con ID: \(docRef.documentID)")
        return category
    }
    
    func getCategoryByCode(_ code: String) async -> CategoryFS? {
        do {
            let snapshot = try await db.collection(CategoryFS.collectionName).whereField("code", isEqualTo: code).limit(to: 1).getDocuments()
            guard let doc = snapshot.documents.first, let cat = try? doc.data(as: CategoryFS.self) else { return nil }
            if let id = cat.id { categoryCache[id] = cat }
            return cat
        } catch { return nil }
    }
    
    func getAllCategories() async -> [CategoryFS] {
        if isCacheValid(), !categoryCache.isEmpty { return Array(categoryCache.values).sorted { $0.code < $1.code } }
        do {
            let snapshot = try await db.collection(CategoryFS.collectionName).order(by: "code").getDocuments()
            let categories = snapshot.documents.compactMap { try? $0.data(as: CategoryFS.self) }
            categoryCache.removeAll()
            categories.forEach { if let id = $0.id { categoryCache[id] = $0 } }
            updateCacheTimestamp()
            return categories
        } catch { return [] }
    }
    
    func deleteCategory(categoryId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.delete, on: .category, for: actor) else {
            throw CatalogServiceError.unauthorized("No tienes permisos para eliminar categorías")
        }
        
        try await db.collection(CategoryFS.collectionName).document(categoryId).delete()
        categoryCache.removeValue(forKey: categoryId)
        print("✅ Categoría eliminada")
    }
    
    // MARK: - UnitOfMeasure CRUD
    
    func createUOM(symbol: String, name: String, actor: UserFS?) async throws -> UnitOfMeasureFS {
        guard await AuthorizationServiceFS.allowed(.create, on: .unit, for: actor) else {
            throw CatalogServiceError.unauthorized("No tienes permisos para crear unidades")
        }
        guard !symbol.isEmpty else { throw CatalogServiceError.invalidData("Símbolo vacío") }
        guard !name.isEmpty else { throw CatalogServiceError.invalidData("Nombre vacío") }
        
        if let _ = await getUOMBySymbol(symbol) {
            throw CatalogServiceError.duplicateCode("Ya existe unidad con símbolo '\(symbol)'")
        }
        
        var uom = UnitOfMeasureFS(symbol: symbol, name: name)
        let docRef = db.collection(UnitOfMeasureFS.collectionName).document()
        uom.id = docRef.documentID
        
        let encodedData = try Firestore.Encoder().encode(uom)
        try await docRef.setData(encodedData)
        
        uomCache[docRef.documentID] = uom
        print("✅ UOM '\(symbol)' creada con ID: \(docRef.documentID)")
        return uom
    }
    
    func getUOMBySymbol(_ symbol: String) async -> UnitOfMeasureFS? {
        do {
            let snapshot = try await db.collection(UnitOfMeasureFS.collectionName).whereField("symbol", isEqualTo: symbol).limit(to: 1).getDocuments()
            guard let doc = snapshot.documents.first, let uom = try? doc.data(as: UnitOfMeasureFS.self) else { return nil }
            if let id = uom.id { uomCache[id] = uom }
            return uom
        } catch { return nil }
    }
    
    func getAllUOMs() async -> [UnitOfMeasureFS] {
        if isCacheValid(), !uomCache.isEmpty { return Array(uomCache.values).sorted { $0.symbol < $1.symbol } }
        do {
            let snapshot = try await db.collection(UnitOfMeasureFS.collectionName).order(by: "symbol").getDocuments()
            let uoms = snapshot.documents.compactMap { try? $0.data(as: UnitOfMeasureFS.self) }
            uomCache.removeAll()
            uoms.forEach { if let id = $0.id { uomCache[id] = $0 } }
            updateCacheTimestamp()
            return uoms
        } catch { return [] }
    }
    
    func deleteUOM(uomId: String, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.allowed(.delete, on: .unit, for: actor) else {
            throw CatalogServiceError.unauthorized("No tienes permisos para eliminar unidades")
        }
        
        try await db.collection(UnitOfMeasureFS.collectionName).document(uomId).delete()
        uomCache.removeValue(forKey: uomId)
        print("✅ UOM eliminada")
    }
    
    // MARK: - Cache
    
    func clearCache() { itemCache.removeAll(); categoryCache.removeAll(); uomCache.removeAll(); lastCacheUpdate = .distantPast }
    func clearItemCache() { itemCache.removeAll() }
    func clearCategoryCache() { categoryCache.removeAll() }
    func clearUOMCache() { uomCache.removeAll() }
    private func isCacheValid() -> Bool { Date().timeIntervalSince(lastCacheUpdate) < cacheExpiration }
    private func updateCacheTimestamp() { lastCacheUpdate = Date() }
    
    func preloadStaticData() async {
        _ = await getAllCategories()
        _ = await getAllUOMs()
        print("📦 Datos estáticos pre-cargados")
    }
    
    // MARK: - Statistics & Search
    
    func getStatistics() async -> (totalItems: Int, criticalItems: Int, categories: Int, uoms: Int) {
        let items = await getAllItems()
        return (items.count, items.filter { $0.critical }.count, await getAllCategories().count, await getAllUOMs().count)
    }
    
    func searchItems(by text: String) async -> [CatalogItemFS] {
        let all = await getAllItems()
        guard !text.isEmpty else { return all }
        let l = text.lowercased()
        return all.filter { $0.code.lowercased().contains(l) || $0.name.lowercased().contains(l) || ($0.itemDescription?.lowercased().contains(l) ?? false) }
    }
}

// MARK: - Errors

enum CatalogServiceError: LocalizedError {
    case unauthorized(String), itemNotFound(String), categoryNotFound(String), uomNotFound(String)
    case duplicateCode(String), invalidData(String), firestoreError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let m): return "❌ Sin autorización: \(m)"
        case .itemNotFound(let m): return "❌ Item no encontrado: \(m)"
        case .categoryNotFound(let m): return "❌ Categoría no encontrada: \(m)"
        case .uomNotFound(let m): return "❌ UOM no encontrada: \(m)"
        case .duplicateCode(let m): return "❌ Código duplicado: \(m)"
        case .invalidData(let m): return "❌ Datos inválidos: \(m)"
        case .firestoreError(let e): return "❌ Firestore: \(e.localizedDescription)"
        }
    }
}

#if DEBUG
extension CatalogService {
    func printCacheStatus() { print("📊 CatalogService: Items=\(itemCache.count), Cat=\(categoryCache.count), UOM=\(uomCache.count)") }
}
#endif






















