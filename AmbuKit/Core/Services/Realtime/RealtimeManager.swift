//
//  RealtimeManager.swift
//  AmbuKit
//
//  Created by Adolfo on 31/12/24.
//

import Foundation
import FirebaseFirestore


/// Gestor de listeners en tiempo real de Firestore
/// Compatible con Swift 6 strict concurrency
///
/// Uso en vistas:
/// ```swift
/// .task {
///     RealtimeManager.shared.listenToCollection(
///         KitFS.collectionName,
///         listenerKey: "kits_main"
///     ) { (kits: [KitFS]) in
///         self.kits = kits
///     }
/// }
/// ```
///
/// Cleanup en logout:
/// ```swift
/// RealtimeManager.shared.cleanup()
/// ```
@MainActor
final class RealtimeManager {
    
    // MARK: - Singleton
    
    static let shared = RealtimeManager()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    
    /// Número de listeners activos
     private(set) var activeListenersCount: Int = 0
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Collection Listeners
    
    /// Escucha cambios en una colección completa
    /// - Parameters:
    ///   - collectionPath: Ruta de la colección (ej: "kits")
    ///   - listenerKey: Clave única para identificar el listener
    ///   - orderBy: Campo por el que ordenar (opcional)
    ///   - descending: Si el orden es descendente (default: false)
    ///   - onChange: Callback ejecutado cuando hay cambios
    func listenToCollection<T: Decodable>(
        _ collectionPath: String,
        listenerKey: String,
        orderBy: String? = nil,
        descending: Bool = false,
        onChange: @escaping @MainActor ([T]) -> Void
    ) {
        // Cancelar listener previo si existe
        stopListening(listenerKey)
        
        // Crear query base
        var query: Query = db.collection(collectionPath)
        
        // Añadir ordenamiento si se especifica
        if let orderField = orderBy {
            query = query.order(by: orderField, descending: descending)
        }
        
        // Crear listener
        let listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard self != nil else { return }
            
            Task { @MainActor in
                if let error = error {
                    print("❌ Error en listener '\(listenerKey)': \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    onChange([])
                    return
                }
                
                let items = documents.compactMap { doc -> T? in
                    try? doc.data(as: T.self)
                }
                
                onChange(items)
                
                #if DEBUG
                print("📡 \(listenerKey): \(items.count) items recibidos")
                #endif
            }
        }
        
        // Guardar listener
        listeners[listenerKey] = listener
        activeListenersCount = listeners.count
        
        print("👂 Listener '\(listenerKey)' activado en '\(collectionPath)'")
    }
    
    /// Escucha cambios en una colección con filtro
    /// - Parameters:
    ///   - collectionPath: Ruta de la colección
    ///   - listenerKey: Clave única para identificar el listener
    ///   - field: Campo para filtrar
    ///   - isEqualTo: Valor que debe coincidir
    ///   - onChange: Callback ejecutado cuando hay cambios
    func listenToCollection<T: Decodable>(
        _ collectionPath: String,
        listenerKey: String,
        whereField field: String,
        isEqualTo value: Any,
        onChange: @escaping @MainActor ([T]) -> Void
    ) {
        stopListening(listenerKey)
        
        let listener = db.collection(collectionPath)
            .whereField(field, isEqualTo: value)
            .addSnapshotListener { [weak self] snapshot, error in
                guard self != nil else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("❌ Error en listener '\(listenerKey)': \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        onChange([])
                        return
                    }
                    
                    let items = documents.compactMap { doc -> T? in
                        try? doc.data(as: T.self)
                    }
                    
                    onChange(items)
                }
            }
        
        listeners[listenerKey] = listener
        activeListenersCount = listeners.count
        
        print("👂 Listener '\(listenerKey)' activado con filtro \(field)=\(value)")
    }
    
    // MARK: - Document Listeners
    
    /// Escucha cambios en un documento específico
    /// - Parameters:
    ///   - collectionPath: Ruta de la colección
    ///   - documentId: ID del documento
    ///   - listenerKey: Clave única para identificar el listener
    ///   - onChange: Callback ejecutado cuando hay cambios
    func listenToDocument<T: Decodable>(
        _ collectionPath: String,
        documentId: String,
        listenerKey: String,
        onChange: @escaping @MainActor (T?) -> Void
    ) {
        stopListening(listenerKey)
        
        let listener = db.collection(collectionPath)
            .document(documentId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard self != nil else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("❌ Error en listener '\(listenerKey)': \(error.localizedDescription)")
                        onChange(nil)
                        return
                    }
                    
                    guard let snapshot = snapshot, snapshot.exists else {
                        onChange(nil)
                        return
                    }
                    
                    let item = try? snapshot.data(as: T.self)
                    onChange(item)
                    
                    #if DEBUG
                    print("📡 \(listenerKey): documento actualizado")
                    #endif
                }
            }
        
        listeners[listenerKey] = listener
        activeListenersCount = listeners.count
        
        print("👂 Listener '\(listenerKey)' activado en '\(collectionPath)/\(documentId)'")
    }
    
    // MARK: - Listener Management
    
    /// Detiene un listener específico
    /// - Parameter key: Clave del listener a detener
    func stopListening(_ key: String) {
        guard let listener = listeners[key] else { return }
        
        listener.remove()
        listeners.removeValue(forKey: key)
        activeListenersCount = listeners.count
        
        print("🛑 Listener '\(key)' detenido")
    }
    
    /// Detiene múltiples listeners
    /// - Parameter keys: Claves de los listeners a detener
    func stopListening(_ keys: [String]) {
        for key in keys {
            stopListening(key)
        }
    }
    
    /// Detiene todos los listeners que empiezan con un prefijo
    /// - Parameter prefix: Prefijo de las claves a detener
    func stopListenersWithPrefix(_ prefix: String) {
        let keysToRemove = listeners.keys.filter { $0.hasPrefix(prefix) }
        stopListening(Array(keysToRemove))
    }
    
    /// Limpia todos los listeners (llamar en logout)
    func cleanup() {
        let count = listeners.count
        
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
        activeListenersCount = 0
        
        print("🧹 RealtimeManager: \(count) listeners detenidos")
    }
    
    /// Verifica si un listener está activo
    /// - Parameter key: Clave del listener
    /// - Returns: true si el listener está activo
    func isListening(_ key: String) -> Bool {
        listeners[key] != nil
    }
    
    /// Lista de listeners activos
    var activeListeners: [String] {
        Array(listeners.keys).sorted()
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension RealtimeManager {
    
    /// Imprime el estado de todos los listeners
    func printStatus() {
        print("📊 RealtimeManager Status:")
        print("   Listeners activos: \(listeners.count)")
        for key in listeners.keys.sorted() {
            print("   👂 \(key)")
        }
    }
}
#endif

// MARK: - Listener Keys

/// Claves predefinidas para listeners comunes
enum ListenerKeys {
    static let kitsMain = "kits_main"
    static let kitsForVehicle = "kits_vehicle_"
    static let kitItems = "kit_items_"
    static let vehiclesMain = "vehicles_main"
    static let vehiclesForBase = "vehicles_base_"
    static let basesMain = "bases_main"
    static let usersMain = "users_main"
    static let catalogMain = "catalog_main"
    
    /// Genera clave para items de un kit específico
    static func kitItems(kitId: String) -> String {
        "\(kitItems)\(kitId)"
    }
    
    /// Genera clave para kits de un vehículo específico
    static func kitsForVehicle(vehicleId: String) -> String {
        "\(kitsForVehicle)\(vehicleId)"
    }
    
    /// Genera clave para vehículos de una base específica
    static func vehiclesForBase(baseId: String) -> String {
        "\(vehiclesForBase)\(baseId)"
    }
}
