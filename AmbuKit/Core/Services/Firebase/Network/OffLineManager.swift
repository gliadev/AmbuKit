//
//  OffLineManager.swift
//  AmbuKit
//
//  Created by Adolfo on 26/11/25.
//


import Foundation

// MARK: - Operation Type

/// Tipo de operación pendiente
public enum OfflineOperationType: String, Codable, Sendable, CaseIterable {
    case create = "create"
    case update = "update"
    case delete = "delete"
    
    /// Nombre para mostrar en UI
    nonisolated var displayName: String {
        switch self {
        case .create: return "Crear"
        case .update: return "Actualizar"
        case .delete: return "Eliminar"
        }
    }
    
    /// Icono SF Symbol
    nonisolated var icon: String {
        switch self {
        case .create: return "plus.circle"
        case .update: return "pencil.circle"
        case .delete: return "trash.circle"
        }
    }
}

// MARK: - Offline Operation

/// Representa una operación pendiente de sincronizar
/// Sendable para pasar entre actors de forma segura
public struct OfflineOperation: Codable, Identifiable, Sendable, Equatable {
    
    // MARK: - Properties
    
    /// ID único de la operación
    public let id: String
    
    /// Tipo de operación (create, update, delete)
    public let type: OfflineOperationType
    
    /// Tipo de entidad afectada
    public let entityType: EntityKind
    
    /// ID de la entidad (si existe)
    public let entityId: String
    
    /// Datos de la operación codificados en JSON
    public let payload: Data
    
    /// Fecha de creación de la operación
    public let createdAt: Date
    
    /// Número de intentos de sincronización
    public var retryCount: Int
    
    /// Fecha del último intento
    public var lastRetry: Date?
    
    /// Error del último intento (si falló)
    public var lastError: String?
    
    /// Prioridad de la operación (mayor = más prioritario)
    public let priority: Int
    
    // MARK: - Initialization
    
    public nonisolated init(
        id: String = UUID().uuidString,
        type: OfflineOperationType,
        entityType: EntityKind,
        entityId: String,
        payload: Data,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        lastRetry: Date? = nil,
        lastError: String? = nil,
        priority: Int = 0
    ) {
        self.id = id
        self.type = type
        self.entityType = entityType
        self.entityId = entityId
        self.payload = payload
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastRetry = lastRetry
        self.lastError = lastError
        self.priority = priority
    }
    
    // MARK: - Convenience Initializers
    
    /// Crea una operación desde un objeto Encodable
    public nonisolated static func create<T: Encodable & Sendable>(
        type: OfflineOperationType,
        entityType: EntityKind,
        entityId: String,
        data: T,
        priority: Int = 0
    ) throws -> OfflineOperation {
        let payload = try JSONEncoder().encode(data)
        return OfflineOperation(
            type: type,
            entityType: entityType,
            entityId: entityId,
            payload: payload,
            priority: priority
        )
    }
    
    // MARK: - Computed Properties (nonisolated para evitar inferencia de aislamiento)
    
    /// Tiempo desde que se creó la operación
    public nonisolated var age: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }
    
    /// Indica si la operación ha excedido el máximo de reintentos (5)
    public nonisolated var hasExceededMaxRetries: Bool {
        retryCount >= 5
    }
    
    /// Descripción para UI
    public nonisolated var displayDescription: String {
        "\(type.displayName) \(entityType.rawValue) (\(entityId))"
    }
    
    // MARK: - Equatable
    
    public nonisolated static func == (lhs: OfflineOperation, rhs: OfflineOperation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Offline Manager Error

/// Errores del OfflineManager
public enum OfflineManagerError: LocalizedError, Sendable {
    case operationNotFound(String)
    case persistenceError(String)
    case maxRetriesExceeded(String)
    case invalidPayload(String)
    
    public var errorDescription: String? {
        switch self {
        case .operationNotFound(let id):
            return "Operación '\(id)' no encontrada"
        case .persistenceError(let message):
            return "Error de persistencia: \(message)"
        case .maxRetriesExceeded(let id):
            return "Operación '\(id)' excedió máximo de reintentos"
        case .invalidPayload(let message):
            return "Payload inválido: \(message)"
        }
    }
}

// MARK: - Offline Manager

/// Actor que gestiona operaciones offline de forma thread-safe
/// Encola, persiste y maneja reintentos de operaciones cuando no hay conexión
actor OfflineManager {
    
    // MARK: - Singleton
    
    static let shared = OfflineManager()
    
    // MARK: - Properties
    
    /// Cola de operaciones pendientes
    private var pendingOperations: [OfflineOperation] = []
    
    /// Clave para UserDefaults
    private let storageKey = "com.ambukit.offline_operations"
    
    /// Clave para operaciones fallidas
    private let failedStorageKey = "com.ambukit.failed_operations"
    
    /// Operaciones que fallaron permanentemente
    private var failedOperations: [OfflineOperation] = []
    
    // MARK: - Initialization
    
    private init() {
        // Nota: No podemos usar await en init, la carga se hace en loadInitialData()
    }
    
    /// Carga datos iniciales - llamar después de obtener la instancia
    func loadInitialData() async {
        await load()
        print("📦 OfflineManager inicializado con \(pendingOperations.count) operaciones pendientes")
    }
    
    // MARK: - Queue Operations
    
    /// Encola una nueva operación para sincronizar después
    func enqueue(_ operation: OfflineOperation) async {
        // Verificar si ya existe una operación similar
        if let existingIndex = pendingOperations.firstIndex(where: {
            $0.entityType == operation.entityType &&
            $0.entityId == operation.entityId &&
            $0.type == operation.type
        }) {
            // Reemplazar operación existente con la nueva
            pendingOperations[existingIndex] = operation
            print("🔄 OfflineManager: Operación actualizada (dedup) - \(operation.displayDescription)")
        } else {
            // Añadir nueva operación
            pendingOperations.append(operation)
            print("➕ OfflineManager: Operación encolada - \(operation.displayDescription)")
        }
        
        // Persistir
        await save()
    }
    
    /// Encola múltiples operaciones
    func enqueue(_ operations: [OfflineOperation]) async {
        for operation in operations {
            await enqueue(operation)
        }
    }
    
    /// Obtiene la siguiente operación a procesar
    func dequeue() async -> OfflineOperation? {
        let sorted = pendingOperations.sorted { op1, op2 in
            if op1.priority != op2.priority {
                return op1.priority > op2.priority
            }
            return op1.createdAt < op2.createdAt
        }
        
        for operation in sorted {
            if canRetry(operation) {
                return operation
            }
        }
        
        return nil
    }
    
    // MARK: - Query Operations
    
    /// Obtiene todas las operaciones pendientes
    func getPendingOperations() -> [OfflineOperation] {
        pendingOperations.sorted { $0.createdAt < $1.createdAt }
    }
    
    /// Obtiene el número de operaciones pendientes
    func getPendingCount() -> Int {
        pendingOperations.count
    }
    
    /// Verifica si hay operaciones pendientes
    func hasPendingOperations() -> Bool {
        !pendingOperations.isEmpty
    }
    
    /// Obtiene operaciones por tipo de entidad
    func getOperations(for entityType: EntityKind) -> [OfflineOperation] {
        pendingOperations.filter { $0.entityType == entityType }
    }
    
    /// Obtiene operaciones para una entidad específica
    func getOperations(for entityType: EntityKind, entityId: String) -> [OfflineOperation] {
        pendingOperations.filter {
            $0.entityType == entityType && $0.entityId == entityId
        }
    }
    
    /// Obtiene operaciones fallidas permanentemente
    func getFailedOperations() -> [OfflineOperation] {
        failedOperations
    }
    
    // MARK: - Status Updates
    
    /// Marca una operación como completada y la elimina de la cola
    func markCompleted(_ id: String) async {
        guard let index = pendingOperations.firstIndex(where: { $0.id == id }) else {
            print("⚠️ OfflineManager: Operación '\(id)' no encontrada para marcar completa")
            return
        }
        
        let operation = pendingOperations[index]
        pendingOperations.remove(at: index)
        print("✅ OfflineManager: Operación completada - \(operation.displayDescription)")
        
        await save()
    }
    
    /// Marca una operación como fallida e incrementa el contador de reintentos
    func markFailed(_ id: String, error: Error) async {
        guard let index = pendingOperations.firstIndex(where: { $0.id == id }) else {
            print("⚠️ OfflineManager: Operación '\(id)' no encontrada para marcar fallida")
            return
        }
        
        var operation = pendingOperations[index]
        operation.retryCount += 1
        operation.lastRetry = Date()
        operation.lastError = error.localizedDescription
        
        if operation.hasExceededMaxRetries {
            pendingOperations.remove(at: index)
            failedOperations.append(operation)
            print("❌ OfflineManager: Operación fallida permanentemente - \(operation.displayDescription)")
            await saveFailedOperations()
        } else {
            pendingOperations[index] = operation
            let backoff = calculateBackoff(for: operation)
            print("🔄 OfflineManager: Operación fallida, reintento \(operation.retryCount)/\(5) en \(Int(backoff))s - \(operation.displayDescription)")
        }
        
        await save()
    }
    
    /// Elimina una operación de la cola sin procesarla
    func remove(_ id: String) async {
        guard let index = pendingOperations.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        let operation = pendingOperations[index]
        pendingOperations.remove(at: index)
        print("🗑️ OfflineManager: Operación eliminada - \(operation.displayDescription)")
        
        await save()
    }
    
    /// Limpia todas las operaciones pendientes
    func clearAll() async {
        pendingOperations.removeAll()
        print("🧹 OfflineManager: Todas las operaciones pendientes eliminadas")
        await save()
    }
    
    /// Limpia operaciones fallidas permanentemente
    func clearFailedOperations() async {
        failedOperations.removeAll()
        print("🧹 OfflineManager: Operaciones fallidas eliminadas")
        await saveFailedOperations()
    }
    
    /// Reintenta una operación fallida
    func retryFailedOperation(_ id: String) async {
        guard let index = failedOperations.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        var operation = failedOperations[index]
        operation.retryCount = 0
        operation.lastRetry = nil
        operation.lastError = nil
        
        failedOperations.remove(at: index)
        pendingOperations.append(operation)
        
        print("🔄 OfflineManager: Operación fallida movida a cola para reintento - \(operation.displayDescription)")
        
        await save()
        await saveFailedOperations()
    }
    
    // MARK: - Backoff Logic
    
    /// Calcula el tiempo de espera para el siguiente reintento
    func calculateBackoff(for operation: OfflineOperation) -> TimeInterval {
        let exponentialDelay = pow(2.0, Double(operation.retryCount)) * 2.0
        return min(exponentialDelay, 60.0)
    }
    
    /// Verifica si una operación puede reintentarse (respeta backoff)
    func canRetry(_ operation: OfflineOperation) -> Bool {
        guard let lastRetry = operation.lastRetry else {
            return true
        }
        
        let backoff = calculateBackoff(for: operation)
        let timeSinceLastRetry = Date().timeIntervalSince(lastRetry)
        
        return timeSinceLastRetry >= backoff
    }
    
    // MARK: - Persistence
    
    /// Guarda las operaciones pendientes en UserDefaults
    private func save() async {
        do {
            let data = try JSONEncoder().encode(pendingOperations)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("💾 OfflineManager: \(pendingOperations.count) operaciones guardadas")
        } catch {
            print("❌ OfflineManager: Error guardando operaciones - \(error.localizedDescription)")
        }
    }
    
    /// Carga las operaciones pendientes desde UserDefaults
    private func load() async {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("📂 OfflineManager: No hay operaciones persistidas")
            return
        }
        
        do {
            pendingOperations = try JSONDecoder().decode([OfflineOperation].self, from: data)
            print("📂 OfflineManager: \(pendingOperations.count) operaciones cargadas")
        } catch {
            print("❌ OfflineManager: Error cargando operaciones - \(error.localizedDescription)")
            pendingOperations = []
        }
        
        await loadFailedOperations()
    }
    
    /// Guarda las operaciones fallidas
    private func saveFailedOperations() async {
        do {
            let data = try JSONEncoder().encode(failedOperations)
            UserDefaults.standard.set(data, forKey: failedStorageKey)
        } catch {
            print("❌ OfflineManager: Error guardando operaciones fallidas")
        }
    }
    
    /// Carga las operaciones fallidas
    private func loadFailedOperations() async {
        guard let data = UserDefaults.standard.data(forKey: failedStorageKey) else {
            return
        }
        
        do {
            failedOperations = try JSONDecoder().decode([OfflineOperation].self, from: data)
            print("📂 OfflineManager: \(failedOperations.count) operaciones fallidas cargadas")
        } catch {
            failedOperations = []
        }
    }
}

// MARK: - Statistics

extension OfflineManager {
    /// Obtiene estadísticas de las operaciones
    func getStatistics() -> (
        pending: Int,
        failed: Int,
        byType: [OfflineOperationType: Int],
        byEntity: [EntityKind: Int]
    ) {
        var byType: [OfflineOperationType: Int] = [:]
        var byEntity: [EntityKind: Int] = [:]
        
        for operation in pendingOperations {
            byType[operation.type, default: 0] += 1
            byEntity[operation.entityType, default: 0] += 1
        }
        
        return (
            pending: pendingOperations.count,
            failed: failedOperations.count,
            byType: byType,
            byEntity: byEntity
        )
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension OfflineManager {
    /// Imprime estado del manager
    func printStatus() {
        print("📊 OfflineManager Status:")
        print("   Pendientes: \(pendingOperations.count)")
        print("   Fallidas: \(failedOperations.count)")
        
        if !pendingOperations.isEmpty {
            print("   Operaciones pendientes:")
            for op in pendingOperations {
                print("      - \(op.displayDescription) (reintentos: \(op.retryCount))")
            }
        }
    }
    
    /// Crea operaciones de prueba
    func createTestOperations() async {
        let testOp1 = OfflineOperation(
            type: .update,
            entityType: .kitItem,
            entityId: "test-item-1",
            payload: Data()
        )
        
        let testOp2 = OfflineOperation(
            type: .create,
            entityType: .kit,
            entityId: "test-kit-1",
            payload: Data()
        )
        
        await enqueue(testOp1)
        await enqueue(testOp2)
        
        print("🧪 Operaciones de prueba creadas")
    }
}
#endif
