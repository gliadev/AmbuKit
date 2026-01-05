//
//  CacheManager.swift
//  AmbuKit
//
//  Created by Adolfo on 31/12/24.
//

import Foundation

/// Gestor de caché genérico con TTL (Time To Live) configurable
/// Compatible con Swift 6 strict concurrency (@MainActor)
///
/// Uso:
/// ```swift
/// private let kitCache = CacheManager<KitFS>(expirationTime: 300) // 5 min
///
/// // Guardar
/// kitCache.set("kit123", value: kit)
///
/// // Obtener (nil si expiró o no existe)
/// if let cached = kitCache.get("kit123") { ... }
///
/// // Limpiar
/// kitCache.clear()
/// ```
@MainActor
final class CacheManager<Value> {
    
    // MARK: - Nested Types
    
    private struct CachedValue {
        let value: Value
        let timestamp: Date
        
        func isValid(expiration: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) < expiration
        }
        
        var age: TimeInterval {
            Date().timeIntervalSince(timestamp)
        }
    }
    
    // MARK: - Properties
    
    /// Caché interno
    private var cache: [String: CachedValue] = [:]
    
    /// Tiempo de expiración en segundos
    let expirationTime: TimeInterval
    
    /// Nombre del caché (para debugging)
    let name: String
    
    // MARK: - Initialization
    
    /// Crea un gestor de caché
    /// - Parameters:
    ///   - name: Nombre identificador (para logs)
    ///   - expirationTime: Tiempo de expiración en segundos (default: 300 = 5 min)
    init(name: String = "Cache", expirationTime: TimeInterval = 300) {
        self.name = name
        self.expirationTime = expirationTime
    }
    
    // MARK: - Cache Operations
    
    /// Obtiene un valor del caché si existe y es válido
    /// - Parameter key: Clave del valor
    /// - Returns: Valor si existe y no ha expirado, nil en caso contrario
    func get(_ key: String) -> Value? {
        guard let cached = cache[key] else {
            return nil
        }
        
        guard cached.isValid(expiration: expirationTime) else {
            // Expiró, eliminarlo
            cache.removeValue(forKey: key)
            return nil
        }
        
        return cached.value
    }
    
    /// Guarda un valor en el caché
    /// - Parameters:
    ///   - key: Clave del valor
    ///   - value: Valor a guardar
    func set(_ key: String, value: Value) {
        cache[key] = CachedValue(value: value, timestamp: Date())
    }
    
    /// Actualiza un valor existente o lo crea si no existe
    /// - Parameters:
    ///   - key: Clave del valor
    ///   - value: Nuevo valor
    func update(_ key: String, value: Value) {
        set(key, value: value)
    }
    
    /// Elimina un valor específico del caché
    /// - Parameter key: Clave del valor a eliminar
    func remove(_ key: String) {
        cache.removeValue(forKey: key)
    }
    
    /// Limpia todo el caché
    func clear() {
        let previousCount = cache.count
        cache.removeAll()
        
        #if DEBUG
        if previousCount > 0 {
            print("🧹 \(name): Limpiado (\(previousCount) elementos)")
        }
        #endif
    }
    
    /// Limpia valores expirados
    /// - Returns: Número de elementos eliminados
    @discardableResult
    func removeExpired() -> Int {
        let initialCount = cache.count
        cache = cache.filter { $0.value.isValid(expiration: expirationTime) }
        let removed = initialCount - cache.count
        
        #if DEBUG
        if removed > 0 {
            print("🧹 \(name): Eliminados \(removed) elementos expirados")
        }
        #endif
        
        return removed
    }
    
    /// Verifica si una clave existe y es válida
    /// - Parameter key: Clave a verificar
    /// - Returns: true si existe y no ha expirado
    func contains(_ key: String) -> Bool {
        get(key) != nil
    }
    
    // MARK: - Computed Properties
    
    /// Número de elementos en caché (incluyendo expirados)
    var count: Int {
        cache.count
    }
    
    /// Número de elementos válidos en caché
    var validCount: Int {
        cache.values.filter { $0.isValid(expiration: expirationTime) }.count
    }
    
    /// Si el caché está vacío
    var isEmpty: Bool {
        cache.isEmpty
    }
    
    /// Todas las claves almacenadas
    var keys: [String] {
        Array(cache.keys)
    }
}

// MARK: - Batch Operations

extension CacheManager {
    
    /// Guarda múltiples valores de una vez
    /// - Parameter items: Diccionario de clave-valor
    func setAll(_ items: [String: Value]) {
        for (key, value) in items {
            set(key, value: value)
        }
    }
    
    /// Obtiene múltiples valores
    /// - Parameter keys: Claves a obtener
    /// - Returns: Diccionario con los valores encontrados (solo los válidos)
    func getAll(_ keys: [String]) -> [String: Value] {
        var result: [String: Value] = [:]
        for key in keys {
            if let value = get(key) {
                result[key] = value
            }
        }
        return result
    }
    
    /// Elimina múltiples valores
    /// - Parameter keys: Claves a eliminar
    func removeAll(_ keys: [String]) {
        for key in keys {
            remove(key)
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension CacheManager {
    
    /// Imprime el estado del caché
    func printStatus() {
        print("📊 \(name) Status:")
        print("   Total: \(count)")
        print("   Válidos: \(validCount)")
        print("   TTL: \(Int(expirationTime))s")
    }
    
    /// Imprime todas las claves con su edad
    func printDetails() {
        print("📊 \(name) Details:")
        for (key, cached) in cache {
            let age = Int(cached.age)
            let valid = cached.isValid(expiration: expirationTime) ? "✅" : "❌"
            print("   \(valid) \(key): \(age)s old")
        }
    }
}
#endif

// MARK: - Convenience Initializers

extension CacheManager {
    
    /// Caché de corta duración (1 minuto)
    static func shortLived<T>(name: String = "ShortCache") -> CacheManager<T> {
        CacheManager<T>(name: name, expirationTime: 60)
    }
    
    /// Caché estándar (5 minutos)
    static func standard<T>(name: String = "StandardCache") -> CacheManager<T> {
        CacheManager<T>(name: name, expirationTime: 300)
    }
    
    /// Caché de larga duración (10 minutos)
    static func longLived<T>(name: String = "LongCache") -> CacheManager<T> {
        CacheManager<T>(name: name, expirationTime: 600)
    }
    
    /// Caché de muy larga duración (30 minutos)
    static func extended<T>(name: String = "ExtendedCache") -> CacheManager<T> {
        CacheManager<T>(name: name, expirationTime: 1800)
    }
}
