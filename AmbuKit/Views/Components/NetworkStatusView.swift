//
//  NetworkStatusView.swift
//  AmbuKit
//
//  Created by Adolfo on 26/11/25.
//


import SwiftUI

// MARK: - Network Status View

/// Vista que muestra el estado de conexión y sincronización
/// Se muestra como banner en la parte superior de la pantalla
///
/// Uso:
/// ```swift
/// var body: some View {
///     VStack(spacing: 0) {
///         NetworkStatusView()
///
///         // Contenido principal
///         MainContentView()
///     }
/// }
/// ```
struct NetworkStatusView: View {
    
    // MARK: - Environment & State
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var syncService = SyncService.shared
    
    /// Controla la animación de aparición/desaparición
    @State private var isVisible: Bool = false
    
    /// Controla si el banner está expandido (muestra más detalles)
    @State private var isExpanded: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if shouldShowBanner {
                bannerContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: shouldShowBanner)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onAppear {
            isVisible = true
        }
    }
    
    // MARK: - Computed Properties
    
    /// Determina si debe mostrarse el banner
    private var shouldShowBanner: Bool {
        !networkMonitor.isConnected || syncService.isSyncing || syncService.pendingCount > 0
    }
    
    /// Color de fondo según el estado
    private var backgroundColor: Color {
        if !networkMonitor.isConnected {
            return .red.opacity(0.9)
        } else if syncService.isSyncing {
            return .blue.opacity(0.9)
        } else if syncService.pendingCount > 0 {
            return .orange.opacity(0.9)
        } else {
            return .green.opacity(0.9)
        }
    }
    
    /// Icono según el estado
    private var statusIcon: String {
        if !networkMonitor.isConnected {
            return "wifi.slash"
        } else if syncService.isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if syncService.pendingCount > 0 {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    /// Mensaje principal según el estado
    private var statusMessage: String {
        if !networkMonitor.isConnected {
            return "Sin conexión"
        } else if syncService.isSyncing {
            return "Sincronizando..."
        } else if syncService.pendingCount > 0 {
            return "\(syncService.pendingCount) cambio\(syncService.pendingCount == 1 ? "" : "s") pendiente\(syncService.pendingCount == 1 ? "" : "s")"
        } else {
            return "Conectado"
        }
    }
    
    /// Mensaje secundario con más detalles
    private var detailMessage: String {
        if !networkMonitor.isConnected {
            if syncService.pendingCount > 0 {
                return "\(syncService.pendingCount) cambio\(syncService.pendingCount == 1 ? "" : "s") se sincronizará\(syncService.pendingCount == 1 ? "" : "n") al volver online"
            } else {
                return "Los cambios se guardarán localmente"
            }
        } else if syncService.isSyncing {
            if let current = syncService.currentOperation {
                return current
            }
            return "\(Int(syncService.progress * 100))% completado"
        } else if syncService.pendingCount > 0 {
            return "Toca para sincronizar ahora"
        } else {
            return networkMonitor.connectionType.displayName
        }
    }
    
    // MARK: - Views
    
    /// Contenido principal del banner
    private var bannerContent: some View {
        VStack(spacing: 0) {
            // Banner principal
            Button(action: handleTap) {
                HStack(spacing: 12) {
                    // Icono con animación
                    iconView
                    
                    // Textos
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusMessage)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(detailMessage)
                            .font(.caption)
                            .opacity(0.9)
                    }
                    
                    Spacer()
                    
                    // Barra de progreso cuando está sincronizando
                    if syncService.isSyncing {
                        progressIndicator
                    }
                    
                    // Botón de expandir/colapsar
                    if !networkMonitor.isConnected || syncService.pendingCount > 0 {
                        expandButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            // Contenido expandido
            if isExpanded && !syncService.isSyncing {
                expandedContent
            }
        }
        .background(backgroundColor)
    }
    
    /// Vista del icono con animación
    private var iconView: some View {
        Image(systemName: statusIcon)
            .font(.title3)
            .symbolEffect(.bounce, value: syncService.isSyncing)
            .rotationEffect(.degrees(syncService.isSyncing ? 360 : 0))
            .animation(
                syncService.isSyncing
                    ? .linear(duration: 1).repeatForever(autoreverses: false)
                    : .default,
                value: syncService.isSyncing
            )
    }
    
    /// Indicador de progreso circular
    private var progressIndicator: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: syncService.progress)
                .stroke(Color.white, lineWidth: 3)
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 28, height: 28)
    }
    
    /// Botón para expandir/colapsar
    private var expandButton: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(8)
            .background(Color.white.opacity(0.2))
            .clipShape(Circle())
    }
    
    /// Contenido expandido con más opciones
    private var expandedContent: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.white.opacity(0.3))
            
            if !networkMonitor.isConnected {
                offlineExpandedContent
            } else if syncService.pendingCount > 0 {
                pendingExpandedContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    /// Contenido expandido cuando está offline
    private var offlineExpandedContent: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                Text("Última conexión: \(lastConnectionText)")
                    .font(.caption)
                Spacer()
            }
            
            if syncService.pendingCount > 0 {
                HStack {
                    Image(systemName: "tray.full")
                    Text("\(syncService.pendingCount) operaciones en cola")
                        .font(.caption)
                    Spacer()
                }
            }
            
            Text("Los cambios se sincronizarán automáticamente al recuperar la conexión")
                .font(.caption2)
                .opacity(0.8)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.white)
    }
    
    /// Contenido expandido cuando hay pendientes
    private var pendingExpandedContent: some View {
        VStack(spacing: 12) {
            // Info de última sincronización
            if let lastSync = syncService.lastSyncDate {
                HStack {
                    Image(systemName: "clock")
                    Text("Última sync: \(lastSync.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                    Spacer()
                }
            }
            
            // Botón de sincronizar
            Button(action: {
                Task {
                    await syncService.syncPendingOperations()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sincronizar ahora")
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(.white)
    }
    
    /// Texto de última conexión
    private var lastConnectionText: String {
        let interval = networkMonitor.timeSinceLastChange
        
        if interval < 60 {
            return "hace un momento"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "hace \(minutes) min"
        } else {
            let hours = Int(interval / 3600)
            return "hace \(hours) hora\(hours == 1 ? "" : "s")"
        }
    }
    
    // MARK: - Actions
    
    /// Maneja tap en el banner
    private func handleTap() {
        if syncService.isSyncing {
            // No hacer nada si está sincronizando
            return
        }
        
        if networkMonitor.isConnected && syncService.pendingCount > 0 {
            // Si hay conexión y pendientes, expandir o sincronizar
            if isExpanded {
                // Ya está expandido, sincronizar
                Task {
                    await syncService.syncPendingOperations()
                }
            } else {
                // Expandir para mostrar opciones
                withAnimation {
                    isExpanded = true
                }
            }
        } else {
            // Toggle expandido
            withAnimation {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - Compact Network Status View

/// Vista compacta para mostrar en Navigation Bar o Tab Bar
struct CompactNetworkStatusView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var syncService = SyncService.shared
    
    var body: some View {
        HStack(spacing: 4) {
            // Icono de conexión
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            // Contador de pendientes
            if syncService.pendingCount > 0 {
                Text("\(syncService.pendingCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(badgeColor)
                    .clipShape(Capsule())
            }
        }
    }
    
    private var statusColor: Color {
        if !networkMonitor.isConnected {
            return .red
        } else if syncService.isSyncing {
            return .blue
        } else {
            return .green
        }
    }
    
    private var badgeColor: Color {
        !networkMonitor.isConnected ? .red : .orange
    }
}

// MARK: - Network Status Modifier

/// Modifier para añadir NetworkStatusView a cualquier vista
struct NetworkStatusModifier: ViewModifier {
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            NetworkStatusView()
            content
        }
    }
}

extension View {
    /// Añade un banner de estado de red en la parte superior
    func withNetworkStatus() -> some View {
        modifier(NetworkStatusModifier())
    }
}

// MARK: - Preview

#if DEBUG
struct NetworkStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Estado offline
            NetworkStatusPreviewWrapper(isConnected: false, pendingCount: 3)
            
            // Estado sincronizando
            NetworkStatusPreviewWrapper(isSyncing: true, progress: 0.65)
            
            // Estado con pendientes
            NetworkStatusPreviewWrapper(pendingCount: 5)
            
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}

/// Wrapper para preview con estados simulados
private struct NetworkStatusPreviewWrapper: View {
    let isConnected: Bool
    let isSyncing: Bool
    let progress: Double
    let pendingCount: Int
    
    init(
        isConnected: Bool = true,
        isSyncing: Bool = false,
        progress: Double = 0.0,
        pendingCount: Int = 0
    ) {
        self.isConnected = isConnected
        self.isSyncing = isSyncing
        self.progress = progress
        self.pendingCount = pendingCount
    }
    
    var body: some View {
        // Simular estado para preview
        NetworkStatusView()
    }
}
#endif






