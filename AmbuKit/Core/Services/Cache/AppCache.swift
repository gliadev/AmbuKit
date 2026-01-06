//
//  AppCache.swift
//  AmbuKit
//
//  Created by Adolfo on 5/1/26.
//  Coordinador central de cachés de la aplicación
//  Usa CacheManager para cada tipo de dato con TTL apropiado
//

import Foundation

/// Coordinador central de cachés de la aplicación
/// Compatible con Swift 6 strict concurrency
///
/// Uso:
/// ```swift
/// // Obtener categorías (del caché o Firebase)
/// let categories = await AppCache.shared.getCategories()
///
/// // Forzar refresh desde Firebase
/// let categories = await AppCache.shared.getCategories(forceRefresh: true)
///
/// // Pre-cargar datos comunes después del login
/// await AppCache.shared.preloadCommonData()
///
/// // Invalidar todo en logout
/// AppCache.shared.invalidateAll()
/// ```
@MainActor
final class AppCache {
    
    // MARK: - Singleton
    
    static let shared = AppCache()
    
    // MARK: - Cache Instances
    
    /// Caché de roles (TTL: 1 hora - cambian muy poco)
    private let rolesCache = CacheManager<[RoleFS]>(name: "Roles", expirationTime: 3600)
    
    /// Caché de categorías (TTL: 30 min - cambian poco)
    private let categoriesCache = CacheManager<[CategoryFS]>(name: "Categories", expirationTime: 1800)
    
    /// Caché de unidades de medida (TTL: 30 min - cambian poco)
    private let uomsCache = CacheManager<[UnitOfMeasureFS]>(name: "UOMs", expirationTime: 1800)
    
    /// Caché de items del catálogo (TTL: 10 min - cambian con moderación)
    private let catalogItemsCache = CacheManager<[CatalogItemFS]>(name: "CatalogItems", expirationTime: 600)
    
    /// Caché de bases activas (TTL: 5 min - consulta frecuente)
    private let basesCache = CacheManager<[BaseFS]>(name: "Bases", expirationTime: 300)
    
    /// Caché de vehículos (TTL: 5 min)
    private let vehiclesCache = CacheManager<[VehicleFS]>(name: "Vehicles", expirationTime: 300)
    
    /// Caché de kits (TTL: 2 min - cambian frecuentemente)
    private let kitsCache = CacheManager<[KitFS]>(name: "Kits", expirationTime: 120)
    
    // MARK: - Cache Keys
    
    private enum Keys {
        static let allRoles = "all_roles"
        static let allCategories = "all_categories"
        static let allUOMs = "all_uoms"
        static let allCatalogItems = "all_catalog_items"
        static let criticalItems = "critical_items"
        static let activeBases = "active_bases"
        static let allBases = "all_bases"
        static let allVehicles = "all_vehicles"
        static let allKits = "all_kits"
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Roles (via PolicyService)
    
    /// Obtiene todos los roles (del caché o Firebase)
    /// - Parameter forceRefresh: Si true, ignora el caché
    /// - Returns: Lista de roles
    func getRoles(forceRefresh: Bool = false) async -> [RoleFS] {
        if !forceRefresh, let cached = rolesCache.get(Keys.allRoles) {
            #if DEBUG
            print("✅ Roles obtenidos del caché (\(cached.count))")
            #endif
            return cached
        }
        
        let roles = await PolicyService.shared.getAllRoles()
        rolesCache.set(Keys.allRoles, value: roles)
        
        #if DEBUG
        print("🔄 Roles cargados de Firebase (\(roles.count))")
        #endif
        
        return roles
    }
    
    /// Invalida el caché de roles
    func invalidateRoles() {
        rolesCache.clear()
    }
    
    // MARK: - Categories (via CatalogService)
    
    /// Obtiene todas las categorías (del caché o Firebase)
    /// - Parameter forceRefresh: Si true, ignora el caché
    /// - Returns: Lista de categorías
    func getCategories(forceRefresh: Bool = false) async -> [CategoryFS] {
        if !forceRefresh, let cached = categoriesCache.get(Keys.allCategories) {
            #if DEBUG
            print("✅ Categorías obtenidas del caché (\(cached.count))")
            #endif
            return cached
        }
        
        let categories = await CatalogService.shared.getAllCategories()
        categoriesCache.set(Keys.allCategories, value: categories)
        
        #if DEBUG
        print("🔄 Categorías cargadas de Firebase (\(categories.count))")
        #endif
        
        return categories
    }
    
    /// Invalida el caché de categorías
    func invalidateCategories() {
        categoriesCache.clear()
    }
    
    // MARK: - Units of Measure (via CatalogService)
    
    /// Obtiene todas las unidades de medida (del caché o Firebase)
    /// - Parameter forceRefresh: Si true, ignora el caché
    /// - Returns: Lista de unidades de medida
    func getUOMs(forceRefresh: Bool = false) async -> [UnitOfMeasureFS] {
        if !forceRefresh, let cached = uomsCache.get(Keys.allUOMs) {
            #if DEBUG
            print("✅ UOMs obtenidas del caché (\(cached.count))")
            #endif
            return cached
        }
        
        let uoms = await CatalogService.shared.getAllUOMs()
        uomsCache.set(Keys.allUOMs, value: uoms)
        
        #if DEBUG
        print("🔄 UOMs cargadas de Firebase (\(uoms.count))")
        #endif
        
        return uoms
    }
    
    /// Invalida el caché de UOMs
    func invalidateUOMs() {
        uomsCache.clear()
    }
    
    // MARK: - Catalog Items (via CatalogService)
    
    /// Obtiene todos los items del catálogo (del caché o Firebase)
    /// - Parameter forceRefresh: Si true, ignora el caché
    /// - Returns: Lista de items del catálogo
    func getCatalogItems(forceRefresh: Bool = false) async -> [CatalogItemFS] {
        if !forceRefresh, let cached = catalogItemsCache.get(Keys.allCatalogItems) {
            #if DEBUG
            print("✅ Items del catálogo obtenidos del caché (\(cached.count))")
            #endif
            return cached
        }
        
        let items = await CatalogService.shared.getAllItems()
        catalogItemsCache.set(Keys.allCatalogItems, value: items)
        
        #if DEBUG
        print("🔄 Items del catálogo cargados de Firebase (\(items.count))")
        #endif
        
        return items
    }
    
    /// Obtiene los items críticos (del caché o Firebase)
    /// - Parameter forceRefresh: Si true, ignora el caché
    /// - Returns: Lista de items críticos
    func getCriticalItems(forceRefresh: Bool = false) async -> [CatalogItemFS] {
        if !forceRefresh, let cached = catalogItemsCache.get(Keys.criticalItems) {
            #if DEBUG
            print("✅ Items críticos obtenidos del caché (\(cached.count))")
            #endif
            return cached
        }
        
        let items = await CatalogService.shared.getCriticalItems()
        catalogItemsCache.set(Keys.criticalItems, value: items)
        
        #if DEBUG
        print("🔄 Items críticos cargados de Firebase (\(items.count))")
        #endif
        
        return items
    }
    
    /// Invalida el caché de items del catálogo
    func invalidateCatalogItems() {
        catalogItemsCache.clear()
    }
    
    // MARK: - Bases (via BaseService)
    
    /// Obtiene las bases activas (del caché o Firebase)
    /// - Parameter forceRefresh: Si true, ignora el caché
    /// - Returns: Lista de bases activas
    func getActiveBases(forceRefresh: Bool = false) async -> [BaseFS] {
        if !forceRefresh, let cached = basesCache.get(Keys.activeBases) {
            #if DEBUG
            print("✅ Bases activas obtenidas del caché (\(cached.count))")
            #endif
            return cached
        }
        
        let bases = await BaseService.shared.getActiveBases()
        basesCache.set(Keys.activeBases, value: bases)
        
        #if DEBUG
        print("🔄 Bases activas cargadas de Firebase (\(bases.count))")
        #endif
        
        return bases
    }
    
    /// Obtiene todas las bases (del caché o Firebase)
    /// - Parameter forceRefresh: Si true, ignora el caché
    /// - Returns: Lista de todas las bases
    func getAllBases(forceRefresh: Bool = false) async -> [BaseFS] {
        if !forceRefresh, let cached = basesCache.get(Keys.allBases) {
            #if DEBUG
            print("✅ Todas las bases obtenidas del caché (\(cached.count))")
            #endif
            return cached
        }
        
        let bases = await BaseService.shared.getAllBases(includeInactive: true)
        basesCache.set(Keys.allBases, value: bases)
        
        #if DEBUG
        print("🔄 Todas las bases cargadas de Firebase (\(bases.count))")
        #endif
        
        return bases
    }
    
    /// Invalida el caché de bases
    func invalidateBases() {
        basesCache.clear()
    }
    
    // MARK: - Vehicles (via VehicleService)
    
    /// Obtiene todos los vehículos (del caché o Firebase)
    /// - Parameter forceRefresh: Si true, ignora el caché
    /// - Returns: Lista de vehículos
    func getAllVehicles(forceRefresh: Bool = false) async -> [VehicleFS] {
        if !forceRefresh, let cached = vehiclesCache.get(Keys.allVehicles) {
            #if DEBUG
            print("✅ Vehículos obtenidos del caché (\(cached.count))")
            #endif
            return cached
        }
        
        let vehicles = await VehicleService.shared.getAllVehicles()
        vehiclesCache.set(Keys.allVehicles, value: vehicles)
        
        #if DEBUG
        print("🔄 Vehículos cargados de Firebase (\(vehicles.count))")
        #endif
        
        return vehicles
    }
    
    /// Invalida el caché de vehículos
    func invalidateVehicles() {
        vehiclesCache.clear()
    }
    
    // MARK: - Kits (via KitService)
    
    /// Obtiene todos los kits (del caché o Firebase)
    /// - Parameter forceRefresh: Si true, ignora el caché
    /// - Returns: Lista de kits
    func getAllKits(forceRefresh: Bool = false) async -> [KitFS] {
        if !forceRefresh, let cached = kitsCache.get(Keys.allKits) {
            #if DEBUG
            print("✅ Kits obtenidos del caché (\(cached.count))")
            #endif
            return cached
        }
        
        let kits = await KitService.shared.getAllKits()
        kitsCache.set(Keys.allKits, value: kits)
        
        #if DEBUG
        print("🔄 Kits cargados de Firebase (\(kits.count))")
        #endif
        
        return kits
    }
    
    /// Invalida el caché de kits
    func invalidateKits() {
        kitsCache.clear()
    }
    
    // MARK: - Global Operations
    
    /// Invalida todos los cachés (llamar en logout)
    func invalidateAll() {
        rolesCache.clear()
        categoriesCache.clear()
        uomsCache.clear()
        catalogItemsCache.clear()
        basesCache.clear()
        vehiclesCache.clear()
        kitsCache.clear()
        
        #if DEBUG
        print("🧹 AppCache: Todos los cachés invalidados")
        #endif
    }
    
    /// Pre-carga datos comunes (llamar después del login)
    /// Carga en paralelo: roles, categorías, UOMs y bases activas
    func preloadCommonData() async {
        async let roles = getRoles()
        async let categories = getCategories()
        async let uoms = getUOMs()
        async let bases = getActiveBases()
        
        let _ = await (roles, categories, uoms, bases)
        
        #if DEBUG
        print("📦 AppCache: Datos comunes pre-cargados")
        #endif
    }
    
    /// Pre-carga datos estáticos del catálogo
    /// Útil para pantallas que muestran selectores de categoría/UOM
    func preloadCatalogData() async {
        async let categories = getCategories()
        async let uoms = getUOMs()
        async let items = getCatalogItems()
        
        let _ = await (categories, uoms, items)
        
        #if DEBUG
        print("📦 AppCache: Datos del catálogo pre-cargados")
        #endif
    }
    
    /// Limpia elementos expirados de todos los cachés
    func cleanupExpired() {
        rolesCache.removeExpired()
        categoriesCache.removeExpired()
        uomsCache.removeExpired()
        catalogItemsCache.removeExpired()
        basesCache.removeExpired()
        vehiclesCache.removeExpired()
        kitsCache.removeExpired()
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension AppCache {
    
    /// Imprime el estado de todos los cachés
    func printStatus() {
        print("📊 AppCache Status:")
        print("─────────────────────────────")
        rolesCache.printStatus()
        categoriesCache.printStatus()
        uomsCache.printStatus()
        catalogItemsCache.printStatus()
        basesCache.printStatus()
        vehiclesCache.printStatus()
        kitsCache.printStatus()
        print("─────────────────────────────")
    }
}
#endif
