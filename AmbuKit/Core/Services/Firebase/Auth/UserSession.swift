//
//  UserSession.swift
//  AmbuKit
//
//  
//

import Foundation
import Combine

/// Wrapper de la sesión de usuario actual
/// Proporciona acceso conveniente al usuario autenticado
///
/// **Uso:**
/// ```swift
/// let session = UserSession.shared
/// if let user = session.currentUser {
///     print("Usuario: @\(user.username)")
/// }
/// ```
@MainActor
final class UserSession: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = UserSession()
    
    // MARK: - Properties
    
    private let authService = FirebaseAuthService.shared
    
    /// Usuario actual (observado desde FirebaseAuthService)
    @Published private(set) var currentUser: UserFS?
    
    /// Indica si hay un usuario autenticado
    @Published private(set) var isAuthenticated = false
    
    /// Estado de carga
    @Published private(set) var isLoading = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupBindings()
        print("👤 UserSession inicializado")
    }
    
    // MARK: - Setup
    
    /// Configura los bindings con FirebaseAuthService
    private func setupBindings() {
        // Observar cambios en currentUser
        authService.$currentUser
            .assign(to: &$currentUser)
        
        // Observar cambios en isLoading
        authService.$isLoading
            .assign(to: &$isLoading)
        
        // Observar cambios en isAuthenticated
        authService.$currentUser
            .map { $0 != nil }
            .assign(to: &$isAuthenticated)
    }
    
    // MARK: - Public Methods
    
    /// Recarga los datos del usuario actual
    func reload() async {
        await authService.reloadUserData()
    }
    
    /// Limpia la sesión (solo datos locales, no hace logout)
    func clear() {
        currentUser = nil
        isAuthenticated = false
    }
    
    // MARK: - Convenience Getters
    
    /// ID del usuario actual
    var userId: String? {
        currentUser?.id
    }
    
    /// UID de Firebase Auth
    var uid: String? {
        currentUser?.uid
    }
    
    /// Username del usuario actual
    var username: String? {
        currentUser?.username
    }
    
    /// Email del usuario actual
    var email: String? {
        currentUser?.email
    }
    
    /// Nombre completo del usuario actual
    var fullName: String? {
        currentUser?.fullName
    }
    
    /// ID del rol del usuario actual
    var roleId: String? {
        currentUser?.roleId
    }
    
    /// ID de la base del usuario actual
    var baseId: String? {
        currentUser?.baseId
    }
    
    /// Indica si el usuario está activo
    var isActive: Bool {
        currentUser?.active ?? false
    }
}

// MARK: - Role Helpers

extension UserSession {
    /// Obtiene el tipo de rol del usuario actual
    func getRoleKind() async -> RoleKind? {
        guard let roleId = currentUser?.roleId else { return nil }
        let role = await PolicyService.shared.getRole(id: roleId)
        return role?.kind
    }
    
    /// Verifica si el usuario es programador
    func isProgrammer() async -> Bool {
        await AuthorizationServiceFS.isProgrammer(currentUser)
    }
    
    /// Verifica si el usuario es logística
    func isLogistics() async -> Bool {
        await AuthorizationServiceFS.isLogistics(currentUser)
    }
    
    /// Verifica si el usuario es sanitario
    func isSanitary() async -> Bool {
        await AuthorizationServiceFS.isSanitary(currentUser)
    }
}

// MARK: - Permission Helpers

extension UserSession {
    /// Verifica si el usuario puede realizar una acción sobre una entidad
    func can(_ action: ActionKind, on entity: EntityKind) async -> Bool {
        await AuthorizationServiceFS.allowed(action, on: entity, for: currentUser)
    }
    
    /// Verifica si el usuario puede crear una entidad
    func canCreate(_ entity: EntityKind) async -> Bool {
        await AuthorizationServiceFS.canCreate(entity, user: currentUser)
    }
    
    /// Verifica si el usuario puede leer una entidad
    func canRead(_ entity: EntityKind) async -> Bool {
        await AuthorizationServiceFS.canRead(entity, user: currentUser)
    }
    
    /// Verifica si el usuario puede actualizar una entidad
    func canUpdate(_ entity: EntityKind) async -> Bool {
        await AuthorizationServiceFS.canUpdate(entity, user: currentUser)
    }
    
    /// Verifica si el usuario puede eliminar una entidad
    func canDelete(_ entity: EntityKind) async -> Bool {
        await AuthorizationServiceFS.canDelete(entity, user: currentUser)
    }
    
    /// Obtiene todos los permisos para una entidad
    func permissions(for entity: EntityKind) async -> (canCreate: Bool, canRead: Bool, canUpdate: Bool, canDelete: Bool) {
        await AuthorizationServiceFS.permissions(for: entity, user: currentUser)
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension UserSession {
    /// Imprime el estado de la sesión (solo debug)
    func printStatus() {
        print("\n👤 UserSession Status:")
        print("   User: \(username ?? "nil")")
        print("   Email: \(email ?? "nil")")
        print("   Full Name: \(fullName ?? "nil")")
        print("   Is Authenticated: \(isAuthenticated)")
        print("   Is Active: \(isActive)")
        print("   Role ID: \(roleId ?? "nil")")
        print("   Base ID: \(baseId ?? "nil")")
        print()
    }
}
#endif
