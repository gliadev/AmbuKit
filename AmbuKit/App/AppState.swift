//
//  AppState.swift
//  AmbuKit
//
// 
//

import Foundation
import SwiftUI
import Combine

/// Estado global de la aplicación
/// Maneja autenticación, navegación y estado de usuario
///
/// **Responsabilidades:**
/// - Gestionar estado de autenticación
/// - Coordinar FirebaseAuthService y UserSession
/// - Proporcionar interfaz unificada para las vistas
/// - Manejar errores y estados de carga
///
/// **Uso:**
/// ```swift
/// @EnvironmentObject private var appState: AppState
///
/// // Login
/// await appState.signIn(email: email, password: password)
///
/// // Logout
/// await appState.signOut()
/// ```
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AppState()
    
    // MARK: - Services
    
    private let authService = FirebaseAuthService.shared
    private let userSession = UserSession.shared
    
    // MARK: - Published Properties
    
    /// Usuario actual autenticado
    @Published private(set) var currentUser: UserFS?
    
    /// Indica si hay un usuario autenticado
    @Published private(set) var isAuthenticated = false
    
    /// Indica si se está cargando información del usuario
    @Published private(set) var isLoadingUser = false
    
    /// Error actual
    @Published private(set) var currentError: AuthError?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupBindings()
        print("🌐 AppState inicializado")
    }
    
    // MARK: - Setup
    
    /// Configura los bindings con los servicios
    private func setupBindings() {
        // Observar usuario actual desde AuthService
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentUser)
        
        // Observar estado de autenticación
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .map { $0 != nil }
            .assign(to: &$isAuthenticated)
        
        // Observar estado de carga
        authService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoadingUser)
        
        // Observar errores
        authService.$currentError
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentError)
    }
    
    // MARK: - Public Methods - Authentication
    
    /// Inicia sesión con email y contraseña
    /// - Parameters:
    ///   - email: Email del usuario
    ///   - password: Contraseña
    func signIn(email: String, password: String) async {
        do {
            let user = try await authService.signIn(email: email, password: password)
            print("✅ AppState: Login exitoso para @\(user.username)")
        } catch let error as AuthError {
            print("❌ AppState: Error de login - \(error.errorDescription ?? "Unknown")")
            // El error ya está publicado en authService.$currentError
        } catch {
            print("❌ AppState: Error inesperado - \(error.localizedDescription)")
        }
    }
    
    /// Cierra la sesión del usuario actual
    func signOut() async {
        do {
            try await authService.signOut()
            print("✅ AppState: Logout exitoso")
        } catch let error as AuthError {
            print("❌ AppState: Error de logout - \(error.errorDescription ?? "Unknown")")
            // El error ya está publicado en authService.$currentError
        } catch {
            print("❌ AppState: Error inesperado - \(error.localizedDescription)")
        }
    }
    
    /// Recarga los datos del usuario actual
    func reloadUser() async {
        await authService.reloadUserData()
    }
    
    // MARK: - Public Methods - Error Handling
    
    /// Limpia el error actual
    func clearError() {
        currentError = nil
        authService.clearError()
    }
    
    /// Establece un error manualmente
    func setError(_ error: AuthError) {
        currentError = error
    }
    
    // MARK: - Convenience Getters
    
    /// UID del usuario actual en Firebase Auth
    var currentUID: String? {
        authService.currentUID
    }
    
    /// Username del usuario actual
    var currentUsername: String? {
        currentUser?.username
    }
    
    /// Email del usuario actual
    var currentEmail: String? {
        currentUser?.email
    }
    
    /// Nombre completo del usuario actual
    var currentFullName: String? {
        currentUser?.fullName
    }
    
    /// Indica si el usuario actual está activo
    var isUserActive: Bool {
        currentUser?.active ?? false
    }
}

// MARK: - Role & Permissions Helpers

extension AppState {
    /// Obtiene el tipo de rol del usuario actual
    func getCurrentRoleKind() async -> RoleKind? {
        guard let roleId = currentUser?.roleId else { return nil }
        let role = await PolicyService.shared.getRole(id: roleId)
        return role?.kind
    }
    
    /// Verifica si el usuario actual es programador
    func isProgrammer() async -> Bool {
        await AuthorizationServiceFS.isProgrammer(currentUser)
    }
    
    /// Verifica si el usuario actual es logística
    func isLogistics() async -> Bool {
        await AuthorizationServiceFS.isLogistics(currentUser)
    }
    
    /// Verifica si el usuario actual es sanitario
    func isSanitary() async -> Bool {
        await AuthorizationServiceFS.isSanitary(currentUser)
    }
    
    /// Verifica si el usuario puede realizar una acción
    func can(_ action: ActionKind, on entity: EntityKind) async -> Bool {
        await AuthorizationServiceFS.allowed(action, on: entity, for: currentUser)
    }
}

// MARK: - Navigation State (Opcional - para futuro)

extension AppState {
    /// Ruta de navegación actual (para deep linking futuro)
    enum Route: Equatable {
        case splash
        case login
        case main
        case profile
        case admin
        case inventory
    }
    
    // Podrías agregar:
    // @Published var currentRoute: Route = .splash
    // Y manejar navegación programática
}

// MARK: - Debug Helpers

#if DEBUG
extension AppState {
    /// Imprime el estado actual de la app (solo debug)
    func printStatus() {
        print("\n🌐 AppState Status:")
        print("   Is Authenticated: \(isAuthenticated)")
        print("   Is Loading User: \(isLoadingUser)")
        print("   Current User: \(currentUsername ?? "nil")")
        print("   Current Email: \(currentEmail ?? "nil")")
        print("   Current Error: \(currentError?.errorDescription ?? "nil")")
        print("   User Active: \(isUserActive)")
        print()
    }
    
    /// Simula un login para testing (solo debug)
    func simulateLogin(username: String = "test_user") {
        // Solo para testing en previews
        let testUser = UserFS(
            id: "test_id",
            uid: "test_uid",
            username: username,
            fullName: "Test User",
            email: "test@test.com",
            active: true,
            roleId: nil,
            baseId: nil
        )
        
        // Esto solo funciona en debug
        // En producción, siempre usar signIn()
        currentUser = testUser
        print("⚠️ DEBUG: Usuario simulado: @\(username)")
    }
}
#endif

// MARK: - Preview Support

#if DEBUG
extension AppState {
    /// Crea una instancia para previews
    static var preview: AppState {
        let state = AppState.shared
        // Podrías configurar datos de prueba aquí
        return state
    }
    
    /// Crea una instancia para previews con usuario autenticado
    static func previewAuthenticated(username: String = "preview_user") -> AppState {
        let state = AppState.shared
        state.simulateLogin(username: username)
        return state
    }
}
#endif
