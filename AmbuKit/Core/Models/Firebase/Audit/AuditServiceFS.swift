//
//  AuditServiceFS.swift
//  AmbuKit
//
//  Created by Adolfo on 27/11/25.
//


import Foundation
import FirebaseFirestore

// MARK: - AuditServiceFS

/// Servicio de auditoría para registrar acciones en el sistema
///
/// Características:
/// - Métodos estáticos para logging sin necesidad de instanciar
/// - Fire-and-forget pattern para no bloquear operaciones principales
/// - Manejo silencioso de errores (el logging nunca rompe la app)
/// - Queries eficientes con filtros y límites
///
/// Uso típico:
/// ```swift
/// // Fire-and-forget (recomendado para la mayoría de casos)
/// AuditServiceFS.logAsync(.create, entity: .kit, entityId: kit.id!, actor: currentUser)
///
/// // Async cuando necesitas confirmar que se guardó
/// await AuditServiceFS.log(.delete, entity: .base, entityId: baseId, actor: actor)
/// ```
///
/// - Important: Este servicio NO requiere permisos para escribir logs.
///              Cualquier acción del sistema puede registrarse.
public final class AuditServiceFS: Sendable {
    
    // MARK: - Private Init
    
    /// No instanciable - usar métodos estáticos
    private init() {}
    
    // MARK: - Firestore Reference
    
    /// Referencia a Firestore (lazy, thread-safe)
    private static var db: Firestore {
        Firestore.firestore()
    }
    
    // MARK: - Logging Methods
    
    /// Registra una acción en el sistema de auditoría
    ///
    /// Este método es async y espera a que el log se guarde en Firestore.
    /// Para la mayoría de casos, usa `logAsync()` que no bloquea.
    ///
    /// - Parameters:
    ///   - action: Tipo de acción realizada (create, read, update, delete)
    ///   - entity: Tipo de entidad afectada (kit, vehicle, base, etc.)
    ///   - entityId: ID de la entidad afectada
    ///   - actor: Usuario que realizó la acción (nil si es sistema)
    ///   - details: Detalles adicionales opcionales (ej: "Stock actualizado: 5 → 3")
    ///
    /// - Note: Los errores se manejan silenciosamente para no afectar
    ///         la operación principal. Solo se imprimen en consola.
    public static func log(
        _ action: ActionKind,
        entity: EntityKind,
        entityId: String,
        actor: UserFS?,
        details: String? = nil
    ) async {
        let entry = AuditLogFS(
            actorUsername: actor?.username,
            actorRole: actor?.roleId,
            action: action,
            entity: entity,
            entityId: entityId,
            details: details
        )
        
        do {
            _ = try db.collection(AuditLogFS.collectionName).addDocument(from: entry)
            
            #if DEBUG
            print("📝 Audit: \(actor?.username ?? "Sistema") \(action.rawValue) \(entity.rawValue) [\(entityId)]")
            #endif
            
        } catch {
            // Silencioso - el logging nunca debe romper la app
            print("⚠️ AuditServiceFS: Error logging action - \(error.localizedDescription)")
        }
    }
    
    /// Registra una acción sin esperar confirmación (fire-and-forget)
    ///
    /// Esta es la versión recomendada para la mayoría de usos.
    /// No bloquea el caller y maneja errores silenciosamente.
    ///
    /// - Parameters:
    ///   - action: Tipo de acción realizada
    ///   - entity: Tipo de entidad afectada
    ///   - entityId: ID de la entidad afectada
    ///   - actor: Usuario que realizó la acción
    ///   - details: Detalles adicionales opcionales
    ///
    /// Ejemplo:
    /// ```swift
    /// func createBase(...) async throws -> BaseFS {
    ///     // ... crear base ...
    ///
    ///     // No bloquea - sigue inmediatamente
    ///     AuditServiceFS.logAsync(.create, entity: .base, entityId: base.id!, actor: actor)
    ///
    ///     return base
    /// }
    /// ```
    public static func logAsync(
        _ action: ActionKind,
        entity: EntityKind,
        entityId: String,
        actor: UserFS?,
        details: String? = nil
    ) {
        Task {
            await log(action, entity: entity, entityId: entityId, actor: actor, details: details)
        }
    }
    
    // MARK: - Query Methods
    
    /// Obtiene logs con filtros opcionales
    ///
    /// Permite filtrar por cualquier combinación de criterios.
    /// Los resultados se ordenan por timestamp descendente (más recientes primero).
    ///
    /// - Parameters:
    ///   - action: Filtrar por tipo de acción (opcional)
    ///   - entity: Filtrar por tipo de entidad (opcional)
    ///   - entityId: Filtrar por ID de entidad específica (opcional)
    ///   - actorUsername: Filtrar por nombre de usuario (opcional)
    ///   - fromDate: Fecha inicial del rango (opcional)
    ///   - toDate: Fecha final del rango (opcional)
    ///   - limit: Número máximo de resultados (default: 100)
    ///
    /// - Returns: Array de logs que cumplen los criterios
    ///
    /// Ejemplo:
    /// ```swift
    /// // Obtener todas las eliminaciones de kits de hoy
    /// let logs = await AuditServiceFS.getLogs(
    ///     action: .delete,
    ///     entity: .kit,
    ///     fromDate: Calendar.current.startOfDay(for: Date()),
    ///     limit: 50
    /// )
    /// ```
    public static func getLogs(
        action: ActionKind? = nil,
        entity: EntityKind? = nil,
        entityId: String? = nil,
        actorUsername: String? = nil,
        fromDate: Date? = nil,
        toDate: Date? = nil,
        limit: Int = 100
    ) async -> [AuditLogFS] {
        do {
            var query: Query = db.collection(AuditLogFS.collectionName)
            
            // Aplicar filtros
            if let action = action {
                query = query.whereField("actionRaw", isEqualTo: action.rawValue)
            }
            
            if let entity = entity {
                query = query.whereField("entityRaw", isEqualTo: entity.rawValue)
            }
            
            if let entityId = entityId {
                query = query.whereField("entityId", isEqualTo: entityId)
            }
            
            if let actorUsername = actorUsername {
                query = query.whereField("actorUsername", isEqualTo: actorUsername)
            }
            
            if let fromDate = fromDate {
                query = query.whereField("timestamp", isGreaterThanOrEqualTo: fromDate)
            }
            
            if let toDate = toDate {
                query = query.whereField("timestamp", isLessThanOrEqualTo: toDate)
            }
            
            // Ordenar y limitar
            query = query
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
            
            let snapshot = try await query.getDocuments()
            
            return snapshot.documents.compactMap { doc -> AuditLogFS? in
                try? doc.data(as: AuditLogFS.self)
            }
            
        } catch {
            print("⚠️ AuditServiceFS: Error fetching logs - \(error.localizedDescription)")
            return []
        }
    }
    
    /// Obtiene todos los logs de una entidad específica
    ///
    /// Útil para mostrar el historial de cambios de un kit, vehículo, etc.
    ///
    /// - Parameters:
    ///   - entity: Tipo de entidad
    ///   - entityId: ID de la entidad
    ///   - limit: Número máximo de resultados (default: 50)
    ///
    /// - Returns: Array de logs ordenados por fecha (más recientes primero)
    ///
    /// Ejemplo:
    /// ```swift
    /// // Historial de un kit específico
    /// let kitHistory = await AuditServiceFS.getLogsForEntity(.kit, entityId: "kit123")
    /// ```
    public static func getLogsForEntity(
        _ entity: EntityKind,
        entityId: String,
        limit: Int = 50
    ) async -> [AuditLogFS] {
        await getLogs(entity: entity, entityId: entityId, limit: limit)
    }
    
    /// Obtiene todos los logs de un usuario específico
    ///
    /// Útil para ver qué acciones ha realizado un usuario.
    ///
    /// - Parameters:
    ///   - username: Nombre de usuario
    ///   - limit: Número máximo de resultados (default: 50)
    ///
    /// - Returns: Array de logs del usuario ordenados por fecha
    ///
    /// Ejemplo:
    /// ```swift
    /// // Ver actividad de un sanitario
    /// let userActivity = await AuditServiceFS.getLogsForUser(username: "sanitario1")
    /// ```
    public static func getLogsForUser(
        username: String,
        limit: Int = 50
    ) async -> [AuditLogFS] {
        await getLogs(actorUsername: username, limit: limit)
    }
    
    /// Obtiene los logs recientes (últimas 24 horas)
    ///
    /// Útil para dashboards y monitoreo de actividad.
    ///
    /// - Parameter limit: Número máximo de resultados (default: 100)
    /// - Returns: Array de logs de las últimas 24 horas
    ///
    /// Ejemplo:
    /// ```swift
    /// let recentActivity = await AuditServiceFS.getRecentLogs(limit: 20)
    /// ```
    public static func getRecentLogs(
        limit: Int = 100
    ) async -> [AuditLogFS] {
        let yesterday = Date().addingTimeInterval(-86400) // 24 horas
        return await getLogs(fromDate: yesterday, limit: limit)
    }
    
    // MARK: - Convenience Methods
    
    /// Obtiene logs de un tipo de acción específico
    ///
    /// - Parameters:
    ///   - action: Tipo de acción (create, update, delete, read)
    ///   - limit: Número máximo de resultados
    /// - Returns: Array de logs de esa acción
    public static func getLogsByAction(
        _ action: ActionKind,
        limit: Int = 100
    ) async -> [AuditLogFS] {
        await getLogs(action: action, limit: limit)
    }
    
    /// Obtiene logs de un tipo de entidad específico
    ///
    /// - Parameters:
    ///   - entity: Tipo de entidad
    ///   - limit: Número máximo de resultados
    /// - Returns: Array de logs de esa entidad
    public static func getLogsByEntity(
        _ entity: EntityKind,
        limit: Int = 100
    ) async -> [AuditLogFS] {
        await getLogs(entity: entity, limit: limit)
    }
    
    /// Obtiene logs en un rango de fechas
    ///
    /// - Parameters:
    ///   - from: Fecha inicial
    ///   - to: Fecha final
    ///   - limit: Número máximo de resultados
    /// - Returns: Array de logs en el rango
    public static func getLogsInRange(
        from: Date,
        to: Date,
        limit: Int = 100
    ) async -> [AuditLogFS] {
        await getLogs(fromDate: from, toDate: to, limit: limit)
    }
    
    // MARK: - Statistics
    
    /// Obtiene estadísticas de auditoría
    ///
    /// Cuenta los logs agrupados por tipo de acción.
    /// Útil para dashboards y reportes.
    ///
    /// - Parameter fromDate: Fecha desde la cual contar (opcional)
    /// - Returns: Tupla con conteos por tipo de acción
    public static func getStatistics(
        fromDate: Date? = nil
    ) async -> (creates: Int, reads: Int, updates: Int, deletes: Int, total: Int) {
        let logs = await getLogs(fromDate: fromDate, limit: 10000)
        
        let creates = logs.filter { $0.action == .create }.count
        let reads = logs.filter { $0.action == .read }.count
        let updates = logs.filter { $0.action == .update }.count
        let deletes = logs.filter { $0.action == .delete }.count
        
        return (
            creates: creates,
            reads: reads,
            updates: updates,
            deletes: deletes,
            total: logs.count
        )
    }
    
    /// Obtiene los usuarios más activos
    ///
    /// - Parameters:
    ///   - limit: Número de usuarios a retornar
    ///   - fromDate: Fecha desde la cual contar (opcional)
    /// - Returns: Array de tuplas (username, count) ordenado por actividad
    public static func getMostActiveUsers(
        limit: Int = 10,
        fromDate: Date? = nil
    ) async -> [(username: String, count: Int)] {
        let logs = await getLogs(fromDate: fromDate, limit: 10000)
        
        var userCounts: [String: Int] = [:]
        for log in logs {
            if let username = log.actorUsername {
                userCounts[username, default: 0] += 1
            }
        }
        
        return userCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (username: $0.key, count: $0.value) }
    }
}

// MARK: - Bulk Logging

extension AuditServiceFS {
    
    /// Registra múltiples acciones en batch
    ///
    /// Útil cuando se realizan operaciones en lote.
    /// Usa WriteBatch de Firestore para eficiencia.
    ///
    /// - Parameter entries: Array de tuplas con la información de cada log
    ///
    /// Ejemplo:
    /// ```swift
    /// // Registrar múltiples eliminaciones
    /// let entries = deletedIds.map { id in
    ///     (action: ActionKind.delete, entity: EntityKind.kitItem, entityId: id, actor: currentUser, details: nil)
    /// }
    /// await AuditServiceFS.logBatch(entries)
    /// ```
    public static func logBatch(
        _ entries: [(action: ActionKind, entity: EntityKind, entityId: String, actor: UserFS?, details: String?)]
    ) async {
        guard !entries.isEmpty else { return }
        
        let batch = db.batch()
        let collection = db.collection(AuditLogFS.collectionName)
        
        for entry in entries {
            let log = AuditLogFS(
                actorUsername: entry.actor?.username,
                actorRole: entry.actor?.roleId,
                action: entry.action,
                entity: entry.entity,
                entityId: entry.entityId,
                details: entry.details
            )
            
            let docRef = collection.document()
            
            do {
                try batch.setData(from: log, forDocument: docRef)
            } catch {
                print("⚠️ AuditServiceFS: Error encoding log entry - \(error.localizedDescription)")
            }
        }
        
        do {
            try await batch.commit()
            
            #if DEBUG
            print("📝 Audit: Batch logged \(entries.count) entries")
            #endif
            
        } catch {
            print("⚠️ AuditServiceFS: Error committing batch - \(error.localizedDescription)")
        }
    }
    
    /// Versión fire-and-forget de logBatch
    public static func logBatchAsync(
        _ entries: [(action: ActionKind, entity: EntityKind, entityId: String, actor: UserFS?, details: String?)]
    ) {
        Task {
            await logBatch(entries)
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension AuditServiceFS {
    
    /// Imprime los últimos N logs en consola (solo DEBUG)
    public static func printRecentLogs(count: Int = 10) async {
        let logs = await getRecentLogs(limit: count)
        
        print("📋 Últimos \(logs.count) logs de auditoría:")
        print("─────────────────────────────────────────")
        
        for log in logs {
            print("  \(log.formattedTimestamp) | \(log.fullMessage)")
        }
        
        print("─────────────────────────────────────────")
    }
    
    /// Imprime estadísticas de auditoría (solo DEBUG)
    public static func printStatistics() async {
        let stats = await getStatistics()
        
        print("📊 Estadísticas de Auditoría:")
        print("   Total: \(stats.total)")
        print("   Creates: \(stats.creates)")
        print("   Reads: \(stats.reads)")
        print("   Updates: \(stats.updates)")
        print("   Deletes: \(stats.deletes)")
    }
    
    /// Crea logs de prueba (solo DEBUG)
    public static func createTestLogs(count: Int = 5) async {
        print("🧪 Creando \(count) logs de prueba...")
        
        let entities: [EntityKind] = [.kit, .vehicle, .base, .user, .kitItem]
        let actions: [ActionKind] = [.create, .update, .delete]
        
        for i in 1...count {
            let entity = entities.randomElement()!
            let action = actions.randomElement()!
            
            await log(
                action,
                entity: entity,
                entityId: "test-\(UUID().uuidString.prefix(8))",
                actor: nil,
                details: "Test log #\(i)"
            )
        }
        
        print("✅ Logs de prueba creados")
    }
}
#endif
