//
//  SyncServices.swift
//  AmbuKit
//
//  Created by Adolfo on 26/11/25.
//


import Foundation
import Combine

// MARK: - Sync State

/// Estado actual de sincronización
public enum SyncState: Sendable, Equatable {
    case idle
    case syncing
    case completed
    case failed(String)
    
    /// Nombre para mostrar en UI
    var displayName: String {
        switch self {
        case .idle: return "Listo"
        case .syncing: return "Sincronizando..."
        case .completed: return "Completado"
        case .failed(let error): return "Error: \(error)"
        }
    }
    
    /// Icono SF Symbol
    var icon: String {
        switch self {
        case .idle: return "checkmark.circle"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle"
        }
    }
    
    /// Color para UI
    var colorName: String {
        switch self {
        case .idle: return "gray"
        case .syncing: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
}

// MARK: - Sync Result

/// Resultado de una operación de sincronización
public struct SyncResult: Sendable {
    let totalOperations: Int
    let successfulOperations: Int
    let failedOperations: Int
    let duration: TimeInterval
    
    /// Porcentaje de éxito
    var successRate: Double {
        guard totalOperations > 0 else { return 1.0 }
        return Double(successfulOperations) / Double(totalOperations)
    }
    
    /// Indica si todas las operaciones fueron exitosas
    var isFullSuccess: Bool {
        failedOperations == 0 && totalOperations > 0
    }
}

// MARK: - Sync Service Error

public enum SyncServiceError: LocalizedError, Sendable {
    case noConnection
    case alreadySyncing
    case operationFailed(String, Error)
    case unknownEntityType(String)
    
    public var errorDescription: String? {
        switch self {
        case .noConnection:
            return "❌ No hay conexión a internet"
        case .alreadySyncing:
            return "⚠️ Ya hay una sincronización en curso"
        case .operationFailed(let operation, let error):
            return "❌ Operación '\(operation)' falló: \(error.localizedDescription)"
        case .unknownEntityType(let type):
            return "❌ Tipo de entidad desconocido: \(type)"
        }
    }
}

// MARK: - Sync Service

/// Servicio que orquesta la sincronización de operaciones offline
/// Coordina NetworkMonitor, OfflineManager y los services de Firestore
///
/// Uso:
/// ```swift
/// // Sincronización automática cuando vuelve conexión (configurada en init)
///
/// // Sincronización manual
/// Button("Sincronizar") {
///     Task {
///         await SyncService.shared.syncPendingOperations()
///     }
/// }
///
/// // Observar estado
/// @StateObject private var syncService = SyncService.shared
/// Text("Estado: \(syncService.state.displayName)")
/// ```
@MainActor
final class SyncService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SyncService()
    
    // MARK: - Published Properties
    
    /// Estado actual de sincronización
    @Published private(set) var state: SyncState = .idle
    
    /// Indica si hay sincronización en curso
    @Published private(set) var isSyncing: Bool = false
    
    /// Progreso de sincronización (0.0 - 1.0)
    @Published private(set) var progress: Double = 0.0
    
    /// Número de operaciones pendientes
    @Published private(set) var pendingCount: Int = 0
    
    /// Operación actual siendo procesada
    @Published private(set) var currentOperation: String?
    
    /// Fecha de última sincronización exitosa
    @Published private(set) var lastSyncDate: Date?
    
    /// Último error de sincronización
    @Published private(set) var lastError: Error?
    
    /// Último resultado de sincronización
    @Published private(set) var lastResult: SyncResult?
    
    // MARK: - Dependencies
    
    private let offlineManager = OfflineManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    // MARK: - Private Properties
    
    /// Subscribers de Combine
    private var cancellables = Set<AnyCancellable>()
    
    /// Flag para evitar sincronizaciones concurrentes
    private var syncTask: Task<Void, Never>?

    /// Task de reset de estado post-sincronización
    private var resetTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    private init() {
        setupAutoSync()
        setupPendingCountUpdates()
        
        // Cargar datos iniciales del OfflineManager
        Task {
            await offlineManager.loadInitialData()
            await updatePendingCount()
        }
        
        print("🔄 SyncService inicializado")
    }
    
    // MARK: - Setup
    
    /// Configura sincronización automática cuando vuelve conexión
    private func setupAutoSync() {
        // Observar cambios de conexión
        networkMonitor.$isConnected
            .dropFirst() // Ignorar valor inicial
            .removeDuplicates()
            .filter { $0 == true } // Solo cuando vuelve conexión
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                print("🌐 SyncService: Conexión restaurada, iniciando sincronización automática...")
                
                Task { @MainActor in
                    // Pequeño delay para asegurar conexión estable
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    await self.syncPendingOperations()
                }
            }
            .store(in: &cancellables)
        
        // También sincronizar al detectar pérdida de conexión (guardar estado)
        networkMonitor.$isConnected
            .filter { $0 == false }
            .sink { _ in
                print("📴 SyncService: Conexión perdida, operaciones se guardarán para sincronizar después")
            }
            .store(in: &cancellables)
    }
    
    /// Actualiza el contador de operaciones pendientes periódicamente
    private func setupPendingCountUpdates() {
        // Actualizar cada 5 segundos
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.updatePendingCount()
                }
            }
            .store(in: &cancellables)
        
        // Actualización inicial
        Task {
            await updatePendingCount()
        }
    }
    
    // MARK: - Public Methods
    
    /// Sincroniza todas las operaciones pendientes
    /// - Returns: Resultado de la sincronización
    @discardableResult
    func syncPendingOperations() async -> SyncResult {
        // Verificar que no hay otra sincronización en curso
        guard !isSyncing else {
            print("⚠️ SyncService: Sincronización ya en curso")
            return SyncResult(totalOperations: 0, successfulOperations: 0, failedOperations: 0, duration: 0)
        }
        
        // Verificar conexión
        guard networkMonitor.isConnected else {
            print("⚠️ SyncService: Sin conexión, no se puede sincronizar")
            state = .failed("Sin conexión")
            return SyncResult(totalOperations: 0, successfulOperations: 0, failedOperations: 0, duration: 0)
        }
        
        // Iniciar sincronización
        let startTime = Date()
        isSyncing = true
        state = .syncing
        progress = 0.0
        lastError = nil
        
        // Obtener operaciones pendientes
        let operations = await offlineManager.getPendingOperations()
        let totalOperations = operations.count
        
        guard totalOperations > 0 else {
            print("✅ SyncService: No hay operaciones pendientes")
            isSyncing = false
            state = .idle
            lastSyncDate = Date()
            
            return SyncResult(totalOperations: 0, successfulOperations: 0, failedOperations: 0, duration: 0)
        }
        
        print("🔄 SyncService: Iniciando sincronización de \(totalOperations) operaciones...")
        
        var successCount = 0
        var failCount = 0
        
        // Procesar cada operación
        for (index, operation) in operations.enumerated() {
            // Actualizar progreso
            progress = Double(index) / Double(totalOperations)
            currentOperation = operation.displayDescription
            
            // Verificar que sigue habiendo conexión
            guard networkMonitor.isConnected else {
                print("📴 SyncService: Conexión perdida durante sincronización")
                state = .failed("Conexión perdida")
                break
            }
            
            // Procesar operación
            do {
                try await processOperation(operation)
                await offlineManager.markCompleted(operation.id)
                successCount += 1
                print("✅ Operación \(index + 1)/\(totalOperations) completada")
            } catch {
                await offlineManager.markFailed(operation.id, error: error)
                failCount += 1
                print("❌ Operación \(index + 1)/\(totalOperations) fallida: \(error.localizedDescription)")
            }
            
            // Pequeño delay entre operaciones para no saturar
            guard !Task.isCancelled else { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        // Finalizar sincronización
        let duration = Date().timeIntervalSince(startTime)
        progress = 1.0
        currentOperation = nil
        isSyncing = false
        
        // Actualizar estado final
        if failCount == 0 {
            state = .completed
            lastSyncDate = Date()
            print("✅ SyncService: Sincronización completada - \(successCount)/\(totalOperations) exitosas")
        } else if successCount > 0 {
            state = .completed
            lastSyncDate = Date()
            print("⚠️ SyncService: Sincronización parcial - \(successCount)/\(totalOperations) exitosas, \(failCount) fallidas")
        } else {
            state = .failed("Todas las operaciones fallaron")
            print("❌ SyncService: Sincronización fallida - todas las operaciones fallaron")
        }
        
        // Crear resultado
        let result = SyncResult(
            totalOperations: totalOperations,
            successfulOperations: successCount,
            failedOperations: failCount,
            duration: duration
        )
        
        lastResult = result
        
        // Actualizar contador
        await updatePendingCount()
        
        // Resetear estado a idle después de un momento
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if self.state == .completed {
                self.state = .idle
            }
        }
        
        return result
    }
    
    /// Fuerza sincronización inmediata (ignora backoff)
    func forceSyncNow() async -> SyncResult {
        print("⚡ SyncService: Forzando sincronización inmediata...")
        return await syncPendingOperations()
    }
    
    /// Cancela la sincronización actual
    func cancelSync() {
        syncTask?.cancel()
        syncTask = nil
        isSyncing = false
        state = .idle
        currentOperation = nil
        print("🛑 SyncService: Sincronización cancelada")
    }
    
    // MARK: - Private Methods
    
    /// Procesa una operación offline
    /// - Parameter operation: Operación a procesar
    private func processOperation(_ operation: OfflineOperation) async throws {
        print("📤 Procesando: \(operation.displayDescription)")
        
        switch operation.entityType {
        case .base:
            try await processBaseOperation(operation)
        case .vehicle:
            try await processVehicleOperation(operation)
        case .kit:
            try await processKitOperation(operation)
        case .kitItem:
            try await processKitItemOperation(operation)
        case .catalogItem:
            try await processCatalogItemOperation(operation)
        case .category:
            try await processCategoryOperation(operation)
        case .unit:
            try await processUnitOperation(operation)
        case .user:
            try await processUserOperation(operation)
        case .audit:
            // Los audits se manejan de forma diferente
            print("⚠️ Operaciones de audit no requieren sincronización")
        }
    }
    
    /// Actualiza el contador de operaciones pendientes
    private func updatePendingCount() async {
        pendingCount = await offlineManager.getPendingCount()
    }
    
    // MARK: - Entity-Specific Operations
    
    private func processBaseOperation(_ operation: OfflineOperation) async throws {
        // TODO: Implementar cuando BaseService tenga métodos de sync
        // Por ahora, simular éxito
        print("📤 Base operation: \(operation.type)")
    }
    
    private func processVehicleOperation(_ operation: OfflineOperation) async throws {
        // TODO: Implementar con VehicleService
        print("📤 Vehicle operation: \(operation.type)")
    }
    
    private func processKitOperation(_ operation: OfflineOperation) async throws {
        // TODO: Implementar con KitService
        print("📤 Kit operation: \(operation.type)")
    }
    
    private func processKitItemOperation(_ operation: OfflineOperation) async throws {
        // Esta es la operación más común (updates de stock)
        // Decodificar payload y enviar a KitService
        
        switch operation.type {
        case .create:
            // TODO: KitService.shared.createKitItem(from: payload)
            break
        case .update:
            // TODO: KitService.shared.updateKitItem(from: payload)
            break
        case .delete:
            // TODO: KitService.shared.deleteKitItem(id: operation.entityId)
            break
        }
        
        print("📤 KitItem operation: \(operation.type)")
    }
    
    private func processCatalogItemOperation(_ operation: OfflineOperation) async throws {
        // TODO: Implementar con CatalogService
        print("📤 CatalogItem operation: \(operation.type)")
    }
    
    private func processCategoryOperation(_ operation: OfflineOperation) async throws {
        // TODO: Implementar con CatalogService
        print("📤 Category operation: \(operation.type)")
    }
    
    private func processUnitOperation(_ operation: OfflineOperation) async throws {
        // TODO: Implementar con CatalogService
        print("📤 Unit operation: \(operation.type)")
    }
    
    private func processUserOperation(_ operation: OfflineOperation) async throws {
        // TODO: Implementar con UserService
        print("📤 User operation: \(operation.type)")
    }
}

// MARK: - Convenience Methods

extension SyncService {
    /// Encola una operación y la sincroniza si hay conexión
    /// - Parameter operation: Operación a encolar
    func enqueueAndSync(_ operation: OfflineOperation) async {
        await offlineManager.enqueue(operation)
        await updatePendingCount()
        
        // Si hay conexión, sincronizar inmediatamente
        if networkMonitor.isConnected && !isSyncing {
            await syncPendingOperations()
        }
    }
    
    /// Verifica si hay operaciones pendientes para una entidad
    /// - Parameters:
    ///   - entityType: Tipo de entidad
    ///   - entityId: ID de la entidad
    func hasPendingOperations(for entityType: EntityKind, entityId: String) async -> Bool {
        let operations = await offlineManager.getOperations(for: entityType, entityId: entityId)
        return !operations.isEmpty
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension SyncService {
    /// Imprime estado del servicio
    func printStatus() {
        print("📊 SyncService Status:")
        print("   Estado: \(state.displayName)")
        print("   Sincronizando: \(isSyncing)")
        print("   Progreso: \(Int(progress * 100))%")
        print("   Pendientes: \(pendingCount)")
        print("   Última sincronización: \(lastSyncDate?.description ?? "Nunca")")
        
        if let result = lastResult {
            print("   Último resultado:")
            print("      - Total: \(result.totalOperations)")
            print("      - Exitosas: \(result.successfulOperations)")
            print("      - Fallidas: \(result.failedOperations)")
            print("      - Duración: \(String(format: "%.2f", result.duration))s")
        }
    }
    
    /// Simula una sincronización con operaciones de prueba
    func simulateSync() async {
        print("🧪 Simulando sincronización...")
        
        // Crear operaciones de prueba
        await offlineManager.createTestOperations()
        
        // Sincronizar
        let result = await syncPendingOperations()
        
        print("🧪 Simulación completada: \(result.successfulOperations)/\(result.totalOperations)")
    }
}
#endif
