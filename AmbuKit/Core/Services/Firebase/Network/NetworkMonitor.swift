//
//  NetworkMonitor.swift
//  AmbuKit
//
//  Created by Adolfo on 25/11/25.
//

import Foundation
import Network
import Combine

// MARK: - Connection Type

/// Tipo de conexión de red detectada
public enum ConnectionType: String, Sendable, CaseIterable {
    case wifi = "wifi"
    case cellular = "cellular"
    case ethernet = "ethernet"
    case unknown = "unknown"
    case none = "none"
    
    /// Nombre para mostrar en UI
    var displayName: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Datos móviles"
        case .ethernet: return "Ethernet"
        case .unknown: return "Desconocido"
        case .none: return "Sin conexión"
        }
    }
    
    /// Icono SF Symbol
    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .unknown: return "questionmark.circle"
        case .none: return "wifi.slash"
        }
    }
}

// MARK: - Network Monitor

/// Monitor de conexión de red en tiempo real
/// Usa NWPathMonitor para detectar cambios de conectividad
///
/// Uso:
/// ```swift
/// @StateObject private var networkMonitor = NetworkMonitor.shared
///
/// var body: some View {
///     if !networkMonitor.isConnected {
///         NetworkStatusView()
///     }
/// }
/// ```
@MainActor
final class NetworkMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Published Properties
    
    /// Indica si hay conexión a internet
    @Published private(set) var isConnected: Bool = true
    
    /// Tipo de conexión actual
    @Published private(set) var connectionType: ConnectionType = .unknown
    
    /// Indica si la conexión es costosa (datos móviles)
    @Published private(set) var isExpensive: Bool = false
    
    /// Indica si la conexión es restringida
    @Published private(set) var isConstrained: Bool = false
    
    /// Última vez que se detectó un cambio de estado
    @Published private(set) var lastStatusChange: Date = Date()
    
    // MARK: - Private Properties
    
    /// Monitor de red de Network framework
    private let monitor = NWPathMonitor()
    
    /// Cola dedicada para el monitor (no bloquea main thread)
    private let queue = DispatchQueue(label: "com.ambukit.networkmonitor", qos: .utility)
    
    /// Flag para saber si está monitoreando
    private var isMonitoring = false
    
    /// Subscribers de Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Callbacks
    
    /// Callback cuando cambia el estado de conexión
    /// Útil para que otros servicios reaccionen
    var onConnectionChange: ((Bool) -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        startMonitoring()
        print("📡 NetworkMonitor inicializado")
    }
    
    deinit {
        // No podemos llamar a stopMonitoring() directamente porque es @MainActor
        // El monitor se cancela automáticamente cuando se libera la instancia
        monitor.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Inicia el monitoreo de red
    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️ NetworkMonitor ya está monitoreando")
            return
        }
        
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handlePathUpdate(path)
            }
        }
        
        monitor.start(queue: queue)
        isMonitoring = true
        print("✅ NetworkMonitor: Monitoreo iniciado")
    }
    
    /// Detiene el monitoreo de red
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        monitor.cancel()
        isMonitoring = false
        print("🛑 NetworkMonitor: Monitoreo detenido")
    }
    
    /// Fuerza una verificación del estado actual
    /// Útil después de volver de background
    func checkCurrentStatus() {
        let path = monitor.currentPath
        handlePathUpdate(path)
    }
    
    // MARK: - Private Methods
    
    /// Procesa cambios en el estado de red
    private func handlePathUpdate(_ path: NWPath) {
        let wasConnected = isConnected
        let newIsConnected = path.status == .satisfied
        
        // Actualizar estado de conexión
        isConnected = newIsConnected
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        // Determinar tipo de conexión
        connectionType = determineConnectionType(path)
        
        // Registrar cambio de estado
        lastStatusChange = Date()
        
        // Log del cambio
        if wasConnected != newIsConnected {
            if newIsConnected {
                print("🌐 NetworkMonitor: Conexión restaurada (\(connectionType.displayName))")
            } else {
                print("📴 NetworkMonitor: Conexión perdida")
            }
            
            // Notificar a otros servicios
            onConnectionChange?(newIsConnected)
        }
    }
    
    /// Determina el tipo de conexión basado en las interfaces disponibles
    private func determineConnectionType(_ path: NWPath) -> ConnectionType {
        guard path.status == .satisfied else {
            return .none
        }
        
        // Verificar interfaces en orden de preferencia
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
}

// MARK: - Convenience Properties

extension NetworkMonitor {
    /// Indica si estamos en modo offline (sin conexión)
    var isOffline: Bool {
        !isConnected
    }
    
    /// Indica si la conexión es de baja calidad (costosa o restringida)
    var isLowQualityConnection: Bool {
        isExpensive || isConstrained
    }
    
    /// Descripción del estado actual para UI
    var statusDescription: String {
        if !isConnected {
            return "Sin conexión a internet"
        }
        
        var description = "Conectado vía \(connectionType.displayName)"
        
        if isExpensive {
            description += " (datos móviles)"
        }
        
        if isConstrained {
            description += " (limitada)"
        }
        
        return description
    }
    
    /// Tiempo desde el último cambio de estado
    var timeSinceLastChange: TimeInterval {
        Date().timeIntervalSince(lastStatusChange)
    }
}

// MARK: - Combine Publishers

extension NetworkMonitor {
    /// Publisher que emite cuando la conexión cambia
    var connectionChangedPublisher: AnyPublisher<Bool, Never> {
        $isConnected
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher que emite cuando la conexión se restaura
    var connectionRestoredPublisher: AnyPublisher<Void, Never> {
        $isConnected
            .filter { $0 == true }
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// Publisher que emite cuando la conexión se pierde
    var connectionLostPublisher: AnyPublisher<Void, Never> {
        $isConnected
            .filter { $0 == false }
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension NetworkMonitor {
    /// Imprime estado actual del monitor
    func printStatus() {
        print("📊 NetworkMonitor Status:")
        print("   Conectado: \(isConnected)")
        print("   Tipo: \(connectionType.displayName)")
        print("   Costosa: \(isExpensive)")
        print("   Restringida: \(isConstrained)")
        print("   Monitoreando: \(isMonitoring)")
        print("   Último cambio: \(lastStatusChange)")
    }
    
    /// Simula pérdida de conexión (solo para testing)
    func simulateOffline() {
        print("🧪 Simulando modo offline...")
        isConnected = false
        connectionType = .none
        lastStatusChange = Date()
        onConnectionChange?(false)
    }
    
    /// Simula restauración de conexión (solo para testing)
    func simulateOnline() {
        print("🧪 Simulando modo online...")
        isConnected = true
        connectionType = .wifi
        lastStatusChange = Date()
        onConnectionChange?(true)
    }
}
#endif
