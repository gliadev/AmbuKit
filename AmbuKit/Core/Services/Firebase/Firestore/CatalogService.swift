//
//  CatalogService.swift
//  AmbuKit
//
//  Created by Adolfo on 17/11/25.
//

import Foundation
import FirebaseFirestore
import Combine

/// Servicio para gestionar el Catálogo de Productos en Firestore
/// Maneja 3 entidades: CatalogItem, Category y UnitOfMeasure
/// Implementa CRUD completo con validación de permisos y cache
@MainActor
final class CatalogService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = CatalogService()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    
    // MARK: - Cache
    
    /// Cache de items del catálogo (itemId -> CatalogItemFS)
    private var itemCache: [String: CatalogItemFS] = [:]
    
    /// Cache de categorías (categoryId -> CategoryFS)
    private var categoryCache: [String: CategoryFS] = [:]
    
    /// Cache de unidades de medida (uomId -> UnitOfMeasureFS)
    private var uomCache: [String: UnitOfMeasureFS] = [:]
    
    /// Tiempo de expiración del cache (5 minutos)
    private let cacheExpiration: TimeInterval = 300
    
    /// Última actualización del cache
    private var lastCacheUpdate: Date = .distantPast
    
    // MARK: - Initialization
    
    private init() {
        // Private para forzar uso del singleton
    }
    
    // MARK: - CatalogItem CRUD
    
    /// Crea un nuevo item en el catálogo
    /// - Parameters:
    ///   - code: Código único del item (ej: "ADRE1MG")
    ///   - name: Nombre del producto (ej: "Adrenalina 1mg")
    ///   - description: Descripción detallada (opcional)
    ///   - critical: Si es item crítico (default: false)
    ///   - minStock: Stock mínimo recomendado (opcional)
    ///   - maxStock: Stock máximo recomendado (opcional)
    ///   - categoryId: ID de la categoría (opcional)
    ///   - uomId: ID de la unidad de medida (opcional)
    ///   - actor: Usuario que realiza la acción
    /// - Returns: CatalogItemFS creado
    /// - Throws: CatalogServiceError si hay problemas de permisos o datos
    ///
    /// **Permisos requeridos:**
    /// - Programador: ✅ Permitido
    /// - Logística: ✅ Permitido
    /// - Sanitario: ❌ NO permitido
    ///
    /// - Example:
    /// ```swift
    /// let item = try await CatalogService.shared.createItem(
    ///     code: "ADRE1MG",
    ///     name: "Adrenalina 1mg",
    ///     description: "Ampolla 1mg/ml",
    ///     critical: true,
    ///     minStock: 10,
    ///     maxStock: 50,
    ///     categoryId: "cat_pharmacy",
    ///     uomId: "uom_unit",
    ///     actor: currentUser
    /// )
    /// ```
    func createItem(
        code: String,
        name: String,
        description: String? = nil,
        critical: Bool = false,
        minStock: Double? = nil,
        maxStock: Double? = nil,
        categoryId: String? = nil,
        uomId: String? = nil,
        actor: UserFS?
    ) async throws -> CatalogItemFS {
        // 1. Validar permisos
        guard await AuthorizationServiceFS.allowed(.create, on: .catalogItem, for: actor) else {
            throw CatalogServiceError.unauthorized("No tienes permisos para crear items")
        }
        
        // 2. Validar datos
        guard !code.isEmpty else {
            throw CatalogServiceError.invalidData("El código no puede estar vacío")
        }
        
        guard !name.isEmpty else {
            throw CatalogServiceError.invalidData("El nombre no puede estar vacío")
        }
        
        // 3. Verificar código duplicado
        if let _ = await getItemByCode(code) {
            throw CatalogServiceError.duplicateCode("Ya existe un item con código '\(code)'")
        }
        
        // 4. Crear item
        var item = CatalogItemFS(
            code: code,
            name: name,
            description: description,
            critical: critical,
            minStock: minStock,
            maxStock: maxStock,
            categoryId: categoryId,
            uomId: uomId
        )
        
        // 5. Guardar en Firestore
        do {
            let docRef = try db.collection(CatalogItemFS.collectionName).addDocument(from: item)
            item.id = docRef.documentID
            
            // 6. Actualizar cache
            if let id = item.id {
                itemCache[id] = item
                updateCacheTimestamp()
            }
            
            // 7. Auditoría (cuando AuditServiceFS exista)
            // await AuditServiceFS.log(.create, entity: .catalogItem, entityId: item.id ?? "", actor: actor)
            
            print("✅ Item '\(name)' (\(code)) creado correctamente")
            return item
            
        } catch {
            print("❌ Error creando item: \(error.localizedDescription)")
            throw CatalogServiceError.firestoreError(error)
        }
    }
    
    /// Actualiza un item del catálogo
    /// - Parameters:
    ///   - item: Item con los datos actualizados
    ///   - actor: Usuario que realiza la acción
    /// - Throws: CatalogServiceError si hay problemas
    ///
    /// **Permisos requeridos:**
    /// - Programador: ✅ Permitido
    /// - Logística: ✅ Permitido
    /// - Sanitario: ❌ NO permitido
    func updateItem(item: CatalogItemFS, actor: UserFS?) async throws {
        // 1. Validar permisos
        guard await AuthorizationServiceFS.allowed(.update, on: .catalogItem, for: actor) else {
            throw CatalogServiceError.unauthorized("No tienes permisos para actualizar items")
        }
        
        // 2. Validar datos
        guard let itemId = item.id else {
            throw CatalogServiceError.invalidData("El item no tiene ID válido")
        }
        
        guard !item.code.isEmpty else {
            throw CatalogServiceError.invalidData("El código no puede estar vacío")
        }
        
        guard !item.name.isEmpty else {
            throw CatalogServiceError.invalidData("El nombre no puede estar vacío")
        }
        
        // 3. Actualizar timestamp
        var updatedItem = item
        updatedItem.updatedAt = Date()
        
        // 4. Guardar en Firestore
        do {
            try db.collection(CatalogItemFS.collectionName)
                .document(itemId)
                .setData(from: updatedItem, merge: true)
            
            // 5. Actualizar cache
            itemCache[itemId] = updatedItem
            
            // 6. Auditoría
            // await AuditServiceFS.log(.update, entity: .catalogItem, entityId: itemId, actor: actor)
            
            print("✅ Item '\(item.name)' actualizado correctamente")
            
        } catch {
            print("❌ Error actualizando item: \(error.localizedDescription)")
            throw CatalogServiceError.firestoreError(error)
        }
    }
    
    /// Elimina un item del catálogo
    /// - Parameters:
    ///   - itemId: ID del item a eliminar
    ///   - actor: Usuario que realiza la acción
    /// - Throws: CatalogServiceError si hay problemas
    ///
    /// **Permisos requeridos:**
    /// - Programador: ✅ Permitido
    /// - Logística: ❌ NO permitido (solo puede crear y actualizar)
    /// - Sanitario: ❌ NO permitido
    func deleteItem(itemId: String, actor: UserFS?) async throws {
        // 1. Validar permisos
        guard await AuthorizationServiceFS.allowed(.delete, on: .catalogItem, for: actor) else {
            throw CatalogServiceError.unauthorized("No tienes permisos para eliminar items")
        }
        
        // 2. Verificar que existe
        guard let item = await getItem(id: itemId) else {
            throw CatalogServiceError.itemNotFound("Item con ID '\(itemId)' no encontrado")
        }
        
        // 3. Eliminar de Firestore
        do {
            try await db.collection(CatalogItemFS.collectionName)
                .document(itemId)
                .delete()
            
            // 4. Eliminar del cache
            itemCache.removeValue(forKey: itemId)
            
            // 5. Auditoría
            // await AuditServiceFS.log(.delete, entity: .catalogItem, entityId: itemId, actor: actor)
            
            print("✅ Item '\(item.name)' eliminado correctamente")
            
        } catch {
            print("❌ Error eliminando item: \(error.localizedDescription)")
            throw CatalogServiceError.firestoreError(error)
        }
    }
    
    // MARK: - CatalogItem Queries
    
    /// Obtiene un item por su ID
    /// - Parameter id: ID del item
    /// - Returns: CatalogItemFS si existe, nil si no
    func getItem(id: String) async -> CatalogItemFS? {
        // 1. Verificar cache
        if isCacheValid(), let cached = itemCache[id] {
            return cached
        }
        
        // 2. Consultar Firestore
        do {
            let document = try await db.collection(CatalogItemFS.collectionName)
                .document(id)
                .getDocument()
            
            guard let item = CatalogItemFS.from(snapshot: document) else {
                return nil
            }
            
            // 3. Actualizar cache
            itemCache[id] = item
            return item
            
        } catch {
            print("❌ Error obteniendo item '\(id)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Obtiene un item por su código único
    /// - Parameter code: Código del item
    /// - Returns: CatalogItemFS si existe, nil si no
    func getItemByCode(_ code: String) async -> CatalogItemFS? {
        do {
            let snapshot = try await db.collection(CatalogItemFS.collectionName)
                .whereField("code", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = snapshot.documents.first,
                  let item = CatalogItemFS.from(snapshot: document) else {
                return nil
            }
            
            // Actualizar cache
            if let id = item.id {
                itemCache[id] = item
            }
            
            return item
            
        } catch {
            print("❌ Error obteniendo item por código '\(code)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Obtiene todos los items del catálogo
    /// - Returns: Array de items ordenados por código
    func getAllItems() async -> [CatalogItemFS] {
        do {
            let snapshot = try await db.collection(CatalogItemFS.collectionName)
                .order(by: "code")
                .getDocuments()
            
            let items = snapshot.documents.compactMap { doc -> CatalogItemFS? in
                CatalogItemFS.from(snapshot: doc)
            }
            
            // Actualizar cache
            items.forEach { item in
                if let id = item.id {
                    itemCache[id] = item
                }
            }
            
            updateCacheTimestamp()
            return items
            
        } catch {
            print("❌ Error obteniendo todos los items: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Obtiene items de una categoría específica
    /// - Parameter categoryId: ID de la categoría
    /// - Returns: Array de items de esa categoría
    func getItemsByCategory(categoryId: String) async -> [CatalogItemFS] {
        do {
            let snapshot = try await db.collection(CatalogItemFS.collectionName)
                .whereField("categoryId", isEqualTo: categoryId)
                .order(by: "code")
                .getDocuments()
            
            let items = snapshot.documents.compactMap { doc -> CatalogItemFS? in
                CatalogItemFS.from(snapshot: doc)
            }
            
            // Actualizar cache
            items.forEach { item in
                if let id = item.id {
                    itemCache[id] = item
                }
            }
            
            return items
            
        } catch {
            print("❌ Error obteniendo items de categoría '\(categoryId)': \(error.localizedDescription)")
            return []
        }
    }
    
    /// Obtiene items marcados como críticos
    /// - Returns: Array de items críticos
    func getCriticalItems() async -> [CatalogItemFS] {
        do {
            let snapshot = try await db.collection(CatalogItemFS.collectionName)
                .whereField("critical", isEqualTo: true)
                .order(by: "code")
                .getDocuments()
            
            let items = snapshot.documents.compactMap { doc -> CatalogItemFS? in
                CatalogItemFS.from(snapshot: doc)
            }
            
            return items
            
        } catch {
            print("❌ Error obteniendo items críticos: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Category CRUD
    
    /// Crea una nueva categoría
    /// - Parameters:
    ///   - code: Código único (ej: "FARM")
    ///   - name: Nombre (ej: "Farmacia")
    ///   - icon: Icono SF Symbol (opcional)
    ///   - actor: Usuario que realiza la acción
    /// - Returns: CategoryFS creada
    /// - Throws: CatalogServiceError si hay problemas
    ///
    /// **Permisos requeridos:**
    /// - Programador: ✅ Permitido
    /// - Logística: ✅ Permitido
    /// - Sanitario: ❌ NO permitido
    func createCategory(
        code: String,
        name: String,
        icon: String? = nil,
        actor: UserFS?
    ) async throws -> CategoryFS {
        // 1. Validar permisos
        guard await AuthorizationServiceFS.allowed(.create, on: .category, for: actor) else {
            throw CatalogServiceError.unauthorized("No tienes permisos para crear categorías")
        }
        
        // 2. Validar datos
        guard !code.isEmpty else {
            throw CatalogServiceError.invalidData("El código no puede estar vacío")
        }
        
        guard !name.isEmpty else {
            throw CatalogServiceError.invalidData("El nombre no puede estar vacío")
        }
        
        // 3. Verificar código duplicado
        if let _ = await getCategoryByCode(code) {
            throw CatalogServiceError.duplicateCode("Ya existe una categoría con código '\(code)'")
        }
        
        // 4. Crear categoría
        var category = CategoryFS(code: code, name: name, icon: icon)
        
        // 5. Guardar en Firestore
        do {
            let docRef = try db.collection(CategoryFS.collectionName).addDocument(from: category)
            category.id = docRef.documentID
            
            // 6. Actualizar cache
            if let id = category.id {
                categoryCache[id] = category
            }
            
            print("✅ Categoría '\(name)' creada correctamente")
            return category
            
        } catch {
            print("❌ Error creando categoría: \(error.localizedDescription)")
            throw CatalogServiceError.firestoreError(error)
        }
    }
    
    /// Obtiene una categoría por su código
    /// - Parameter code: Código de la categoría
    /// - Returns: CategoryFS si existe, nil si no
    func getCategoryByCode(_ code: String) async -> CategoryFS? {
        do {
            let snapshot = try await db.collection(CategoryFS.collectionName)
                .whereField("code", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = snapshot.documents.first,
                  let category = CategoryFS.from(snapshot: document) else {
                return nil
            }
            
            if let id = category.id {
                categoryCache[id] = category
            }
            
            return category
            
        } catch {
            print("❌ Error obteniendo categoría por código '\(code)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Obtiene todas las categorías (con cache)
    /// - Returns: Array de categorías ordenadas por código
    func getAllCategories() async -> [CategoryFS] {
        // 1. Verificar cache
        if isCacheValid(), !categoryCache.isEmpty {
            return Array(categoryCache.values).sorted { $0.code < $1.code }
        }
        
        // 2. Consultar Firestore
        do {
            let snapshot = try await db.collection(CategoryFS.collectionName)
                .order(by: "code")
                .getDocuments()
            
            let categories = snapshot.documents.compactMap { doc -> CategoryFS? in
                CategoryFS.from(snapshot: doc)
            }
            
            // 3. Actualizar cache completo
            categoryCache.removeAll()
            categories.forEach { category in
                if let id = category.id {
                    categoryCache[id] = category
                }
            }
            
            updateCacheTimestamp()
            return categories
            
        } catch {
            print("❌ Error obteniendo todas las categorías: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - UnitOfMeasure CRUD
    
    /// Crea una nueva unidad de medida
    /// - Parameters:
    ///   - symbol: Símbolo (ej: "mg", "ml")
    ///   - name: Nombre completo (ej: "miligramo")
    ///   - actor: Usuario que realiza la acción
    /// - Returns: UnitOfMeasureFS creada
    /// - Throws: CatalogServiceError si hay problemas
    ///
    /// **Permisos requeridos:**
    /// - Programador: ✅ Permitido
    /// - Logística: ✅ Permitido
    /// - Sanitario: ❌ NO permitido
    func createUOM(
        symbol: String,
        name: String,
        actor: UserFS?
    ) async throws -> UnitOfMeasureFS {
        // 1. Validar permisos
        guard await AuthorizationServiceFS.allowed(.create, on: .unit, for: actor) else {
            throw CatalogServiceError.unauthorized("No tienes permisos para crear unidades de medida")
        }
        
        // 2. Validar datos
        guard !symbol.isEmpty else {
            throw CatalogServiceError.invalidData("El símbolo no puede estar vacío")
        }
        
        guard !name.isEmpty else {
            throw CatalogServiceError.invalidData("El nombre no puede estar vacío")
        }
        
        // 3. Verificar símbolo duplicado
        if let _ = await getUOMBySymbol(symbol) {
            throw CatalogServiceError.duplicateCode("Ya existe una unidad con símbolo '\(symbol)'")
        }
        
        // 4. Crear UOM
        var uom = UnitOfMeasureFS(symbol: symbol, name: name)
        
        // 5. Guardar en Firestore
        do {
            let docRef = try db.collection(UnitOfMeasureFS.collectionName).addDocument(from: uom)
            uom.id = docRef.documentID
            
            // 6. Actualizar cache
            if let id = uom.id {
                uomCache[id] = uom
            }
            
            print("✅ Unidad de medida '\(symbol)' creada correctamente")
            return uom
            
        } catch {
            print("❌ Error creando unidad de medida: \(error.localizedDescription)")
            throw CatalogServiceError.firestoreError(error)
        }
    }
    
    /// Obtiene una unidad de medida por su símbolo
    /// - Parameter symbol: Símbolo de la unidad
    /// - Returns: UnitOfMeasureFS si existe, nil si no
    func getUOMBySymbol(_ symbol: String) async -> UnitOfMeasureFS? {
        do {
            let snapshot = try await db.collection(UnitOfMeasureFS.collectionName)
                .whereField("symbol", isEqualTo: symbol)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = snapshot.documents.first,
                  let uom = UnitOfMeasureFS.from(snapshot: document) else {
                return nil
            }
            
            if let id = uom.id {
                uomCache[id] = uom
            }
            
            return uom
            
        } catch {
            print("❌ Error obteniendo UOM por símbolo '\(symbol)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Obtiene todas las unidades de medida (con cache)
    /// - Returns: Array de unidades ordenadas por símbolo
    func getAllUOMs() async -> [UnitOfMeasureFS] {
        // 1. Verificar cache
        if isCacheValid(), !uomCache.isEmpty {
            return Array(uomCache.values).sorted { $0.symbol < $1.symbol }
        }
        
        // 2. Consultar Firestore
        do {
            let snapshot = try await db.collection(UnitOfMeasureFS.collectionName)
                .order(by: "symbol")
                .getDocuments()
            
            let uoms = snapshot.documents.compactMap { doc -> UnitOfMeasureFS? in
                UnitOfMeasureFS.from(snapshot: doc)
            }
            
            // 3. Actualizar cache completo
            uomCache.removeAll()
            uoms.forEach { uom in
                if let id = uom.id {
                    uomCache[id] = uom
                }
            }
            
            updateCacheTimestamp()
            return uoms
            
        } catch {
            print("❌ Error obteniendo todas las UOMs: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Cache Management
    
    /// Limpia todo el cache
    func clearCache() {
        itemCache.removeAll()
        categoryCache.removeAll()
        uomCache.removeAll()
        lastCacheUpdate = .distantPast
    }
    
    /// Limpia el cache de items
    func clearItemCache() {
        itemCache.removeAll()
    }
    
    /// Limpia el cache de categorías
    func clearCategoryCache() {
        categoryCache.removeAll()
    }
    
    /// Limpia el cache de UOMs
    func clearUOMCache() {
        uomCache.removeAll()
    }
    
    /// Verifica si el cache es válido
    private func isCacheValid() -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastCacheUpdate)
        return timeSinceLastUpdate < cacheExpiration
    }
    
    /// Actualiza el timestamp del cache
    private func updateCacheTimestamp() {
        lastCacheUpdate = Date()
    }
    
    /// Pre-carga categorías y UOMs en cache
    /// Útil para llamar al inicio de la app
    func preloadStaticData() async {
        _ = await getAllCategories()
        _ = await getAllUOMs()
        updateCacheTimestamp()
        print("📦 Categorías y UOMs pre-cargados en cache")
    }
}

// MARK: - Error Types

/// Errores específicos del servicio de catálogo
enum CatalogServiceError: LocalizedError {
    case unauthorized(String)
    case itemNotFound(String)
    case categoryNotFound(String)
    case uomNotFound(String)
    case duplicateCode(String)
    case invalidData(String)
    case firestoreError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let message):
            return "❌ Sin autorización: \(message)"
        case .itemNotFound(let message):
            return "❌ Item no encontrado: \(message)"
        case .categoryNotFound(let message):
            return "❌ Categoría no encontrada: \(message)"
        case .uomNotFound(let message):
            return "❌ Unidad de medida no encontrada: \(message)"
        case .duplicateCode(let message):
            return "❌ Código duplicado: \(message)"
        case .invalidData(let message):
            return "❌ Datos inválidos: \(message)"
        case .firestoreError(let error):
            return "❌ Error de Firestore: \(error.localizedDescription)"
        }
    }
}

// MARK: - Statistics & Search

extension CatalogService {
    /// Obtiene estadísticas del catálogo
    /// - Returns: Tupla con estadísticas
    func getStatistics() async -> (totalItems: Int, criticalItems: Int, categories: Int, uoms: Int) {
        let items = await getAllItems()
        let critical = items.filter { $0.critical }
        let categories = await getAllCategories()
        let uoms = await getAllUOMs()
        
        return (
            totalItems: items.count,
            criticalItems: critical.count,
            categories: categories.count,
            uoms: uoms.count
        )
    }
    
    /// Busca items por texto
    /// - Parameter searchText: Texto a buscar (código o nombre)
    /// - Returns: Array de items que coinciden
    func searchItems(by searchText: String) async -> [CatalogItemFS] {
        let allItems = await getAllItems()
        
        guard !searchText.isEmpty else { return allItems }
        
        let lowercased = searchText.lowercased()
        return allItems.filter {
            $0.code.lowercased().contains(lowercased) ||
            $0.name.lowercased().contains(lowercased) ||
            ($0.itemDescription?.lowercased().contains(lowercased) ?? false)
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension CatalogService {
    /// Imprime el estado del cache
    func printCacheStatus() {
        print("📊 CatalogService Cache Status:")
        print("   Items en cache: \(itemCache.count)")
        print("   Categorías en cache: \(categoryCache.count)")
        print("   UOMs en cache: \(uomCache.count)")
        print("   Última actualización: \(lastCacheUpdate)")
        print("   Cache válido: \(isCacheValid())")
    }
}
#endif
