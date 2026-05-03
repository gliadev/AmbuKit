//
//  FirebaseAuthService.swift
//  AmbuKit
//
//  
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Servicio de autenticación con Firebase
/// Maneja login, logout, reset password y estado de autenticación
///
/// **Funcionalidades:**
/// - Sign in con email/password
/// - Sign out
/// - Reset password
/// - Listener de cambios de autenticación
/// - Integración con UserService para obtener datos de Firestore
@MainActor
final class FirebaseAuthService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = FirebaseAuthService()
    
    // MARK: - Properties
    
    private let auth = Auth.auth()
    private let userService = UserService.shared
    
    /// Usuario de Firebase Auth actualmente autenticado
    @Published private(set) var firebaseUser: FirebaseAuth.User?
    
    /// Usuario de Firestore con datos completos
    @Published private(set) var currentUser: UserFS?
    
    /// Estado de carga
    @Published private(set) var isLoading = false
    
    /// Error actual
    @Published private(set) var currentError: AuthError?
    
    // MARK: - Computed Properties
    
    /// Indica si hay un usuario autenticado
    var isAuthenticated: Bool {
        firebaseUser != nil && currentUser != nil
    }
    
    /// UID del usuario actual
    var currentUID: String? {
        firebaseUser?.uid
    }
    
    // MARK: - Auth State Listener
    
    nonisolated(unsafe)  private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    // MARK: - Initialization
    
    private init() {
        // Configurar listener de cambios de autenticación
        setupAuthStateListener()
        
        print("🔐 FirebaseAuthService inicializado")
    }
    
    deinit {
        // Remover listener cuando se destruya el servicio
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Setup
    
    /// Configura el listener de cambios de estado de autenticación
    private func setupAuthStateListener() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.firebaseUser = user
                
                if let user = user {
                    print("🔐 Usuario autenticado: \(user.uid)")
                    await self.loadUserData(uid: user.uid)
                } else {
                    print("🔐 Usuario no autenticado")
                    self.currentUser = nil
                }
            }
        }
    }
    
    // MARK: - Public Methods - Sign In
    
    /// Inicia sesión con email y contraseña
    /// - Parameters:
    ///   - email: Email del usuario
    ///   - password: Contraseña
    /// - Returns: UserFS con datos completos de Firestore
    /// - Throws: AuthError si falla la autenticación
    func signIn(email: String, password: String) async throws -> UserFS {
        isLoading = true
        currentError = nil
        
        do {
            // 1. Autenticar con Firebase Auth
            let authResult = try await auth.signIn(withEmail: email, password: password)
            let uid = authResult.user.uid
            
            print("✅ Login exitoso: \(email)")
            
            // 2. Cargar datos del usuario desde Firestore
            guard let user = await userService.getUser(uid: uid) else {
                throw AuthError.userNotFound
            }
            
            // 3. Verificar que el usuario esté activo
            guard user.active else {
                // Si está inactivo, cerrar sesión
                try await signOut()
                throw AuthError.userInactive
            }
            
            // 4. Actualizar usuario actual
            currentUser = user
            isLoading = false
            // pre-cargar datos comunes en cache
            await AppCache.shared.preloadCommonData()
            
            print("✅ Datos de usuario cargados: @\(user.username)")
            
            return user
            
        } catch let error as NSError {
            isLoading = false
            
            // Mapear errores de Firebase a AuthError
            let authError = mapFirebaseError(error)
            currentError = authError
            
            print("❌ Error de login: \(authError.errorDescription ?? "Unknown")")
            
            throw authError
        }
    }
    
    // MARK: - Public Methods - Sign Out
    
    /// Cierra la sesión del usuario actual
    func signOut() async throws {
        isLoading = true
        currentError = nil
        
        do {
            try auth.signOut()
            
            // Limpiar datos locales
            currentUser = nil
            firebaseUser = nil
            
            // Limpiar caché de UserService
            userService.clearCache()
            AppCache.shared.invalidateAll()
            
            print("✅ Logout exitoso")
            
            isLoading = false
            
        } catch {
            isLoading = false
            
            let authError = AuthError.signOutFailed(error.localizedDescription)
            currentError = authError
            
            print("❌ Error de logout: \(error.localizedDescription)")
            
            throw authError
        }
    }
    
    // MARK: - Public Methods - Password Reset
    
    /// Envía un email para restablecer la contraseña
    /// - Parameter email: Email del usuario
    /// - Throws: AuthError si falla el envío
    func resetPassword(email: String) async throws {
        currentError = nil
        
        do {
            try await auth.sendPasswordReset(withEmail: email)
            
            print("✅ Email de reset enviado a: \(email)")
            
        } catch let error as NSError {
            let authError = mapFirebaseError(error)
            currentError = authError
            
            print("❌ Error enviando reset: \(authError.errorDescription ?? "Unknown")")
            
            throw authError
        }
    }
    
    // MARK: - Public Methods - User Data
    
    /// Recarga los datos del usuario actual desde Firestore
    func reloadUserData() async {
        guard let uid = currentUID else { return }
        await loadUserData(uid: uid)
    }
    
    /// Carga los datos del usuario desde Firestore
    /// - Parameter uid: UID del usuario en Firebase Auth
    private func loadUserData(uid: String) async {
        isLoading = true
        
        // Obtener usuario desde Firestore
        guard let user = await userService.getUser(uid: uid) else {
            print("⚠️ Usuario no encontrado en Firestore: \(uid)")
            currentError = .userNotFound
            isLoading = false
            return
        }
        
        // Verificar que esté activo
        guard user.active else {
            print("⚠️ Usuario inactivo: @\(user.username)")
            currentError = .userInactive
            
            // Cerrar sesión si está inactivo
            Task {
                do {
                    try await signOut()
                } catch {
                    print("⚠️ Sign-out fallido: \(error)")
                }
            }
            
            isLoading = false
            return
        }
        
        currentUser = user
        isLoading = false
        
        print("✅ Usuario cargado: @\(user.username)")
    }
    
    // MARK: - Helper Methods
    
    /// Mapea errores de Firebase Auth a AuthError
    /// - Parameter error: Error de Firebase
    /// - Returns: AuthError correspondiente
    private func mapFirebaseError(_ error: NSError) -> AuthError {
        guard let errorCode = AuthErrorCode(rawValue: error.code) else {
            return .unknown(error.localizedDescription)
        }
        
        switch errorCode {
        case .invalidEmail:
            return .invalidEmail
            
        case .wrongPassword:
            return .wrongPassword
            
        case .userNotFound:
            return .userNotFound
            
        case .userDisabled:
            return .userInactive
            
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
            
        case .weakPassword:
            return .weakPassword
            
        case .networkError:
            return .networkError
            
        case .tooManyRequests:
            return .tooManyRequests
            
        default:
            return .unknown(error.localizedDescription)
        }
    }
    
    // MARK: - Public Helpers
    
    /// Limpia el error actual
    func clearError() {
        currentError = nil
    }
}

// MARK: - AuthError

/// Errores de autenticación
enum AuthError: LocalizedError {
    case invalidEmail
    case wrongPassword
    case userNotFound
    case userInactive
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case tooManyRequests
    case signOutFailed(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "El email no es válido"
            
        case .wrongPassword:
            return "Contraseña incorrecta"
            
        case .userNotFound:
            return "No existe un usuario con este email"
            
        case .userInactive:
            return "Tu cuenta está desactivada. Contacta con un administrador."
            
        case .emailAlreadyInUse:
            return "Este email ya está registrado"
            
        case .weakPassword:
            return "La contraseña debe tener al menos 6 caracteres"
            
        case .networkError:
            return "Error de conexión. Verifica tu conexión a internet."
            
        case .tooManyRequests:
            return "Demasiados intentos. Inténtalo más tarde."
            
        case .signOutFailed(let message):
            return "Error al cerrar sesión: \(message)"
            
        case .unknown(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidEmail:
            return "Verifica que el email esté bien escrito"
            
        case .wrongPassword:
            return "Verifica tu contraseña o usa 'Olvidé mi contraseña'"
            
        case .userNotFound:
            return "Verifica el email o contacta con un administrador"
            
        case .userInactive:
            return "Contacta con soporte para reactivar tu cuenta"
            
        case .weakPassword:
            return "Usa una contraseña más segura"
            
        case .networkError:
            return "Verifica tu conexión a internet e intenta de nuevo"
            
        case .tooManyRequests:
            return "Espera unos minutos antes de intentar de nuevo"
            
        default:
            return nil
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension FirebaseAuthService {
    /// Imprime el estado actual del servicio (solo debug)
    func printStatus() {
        print("\n🔐 FirebaseAuthService Status:")
        print("   Firebase User: \(firebaseUser?.email ?? "nil")")
        print("   Current User: \(currentUser?.username ?? "nil")")
        print("   Is Authenticated: \(isAuthenticated)")
        print("   Is Loading: \(isLoading)")
        print("   Current Error: \(currentError?.errorDescription ?? "nil")")
        print()
    }
}
#endif






