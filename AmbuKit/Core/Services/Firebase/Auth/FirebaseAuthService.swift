//
//  FirebaseAuthService.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import Foundation
import Combine
import FirebaseAuth

/// Servicio singleton para gestionar autenticación con Firebase
@MainActor
final class FirebaseAuthService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = FirebaseAuthService()
    
    // MARK: - Published Properties
    @Published private(set) var currentAuthUser: FirebaseAuth.User?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    
    // MARK: - Initialization
    private init() {
        // Verificar si hay una sesión activa al iniciar
        self.currentAuthUser = Auth.auth().currentUser
        self.isAuthenticated = currentAuthUser != nil
        
        // Listener para cambios en el estado de autenticación
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentAuthUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    // MARK: - Sign In
    
    /// Iniciar sesión con email y contraseña
    /// - Parameters:
    ///   - email: Email del usuario
    ///   - password: Contraseña
    /// - Returns: UID del usuario autenticado
    /// - Throws: AuthError con mensaje en español
    func signIn(email: String, password: String) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return result.user.uid
        } catch {
            throw mapAuthError(error)
        }
    }
    
    // MARK: - Sign Out
    
    /// Cerrar sesión
    /// - Throws: AuthError si falla el cierre de sesión
    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try Auth.auth().signOut()
        } catch {
            throw AuthError.signOutFailed
        }
    }
    
    // MARK: - Password Reset
    
    /// Enviar email de recuperación de contraseña
    /// - Parameter email: Email del usuario
    /// - Throws: AuthError con mensaje en español
    func resetPassword(email: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw mapAuthError(error)
        }
    }
    
    // MARK: - User Creation (Admin only)
    
    /// Crear nuevo usuario (solo para administradores)
    /// Nota: Este método crea el usuario en Firebase Auth
    /// El UserFS debe crearse después en Firestore
    /// - Parameters:
    ///   - email: Email del nuevo usuario
    ///   - password: Contraseña temporal
    /// - Returns: UID del usuario creado
    /// - Throws: AuthError con mensaje en español
    func createUser(email: String, password: String) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Enviar email de verificación (opcional)
            try await result.user.sendEmailVerification()
            
            return result.user.uid
        } catch {
            throw mapAuthError(error)
        }
    }
    
    // MARK: - Error Mapping
    
    /// Mapear errores de Firebase a mensajes en español
    private func mapAuthError(_ error: Error) -> AuthError {
        guard let authError = error as NSError? else {
            return .unknown(error.localizedDescription)
        }
        
        // Códigos de error de Firebase Auth
        switch authError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return .invalidCredentials
            
        case AuthErrorCode.userNotFound.rawValue:
            return .userNotFound
            
        case AuthErrorCode.invalidEmail.rawValue:
            return .invalidEmail
            
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .emailAlreadyInUse
            
        case AuthErrorCode.weakPassword.rawValue:
            return .weakPassword
            
        case AuthErrorCode.networkError.rawValue:
            return .networkError
            
        case AuthErrorCode.tooManyRequests.rawValue:
            return .tooManyRequests
            
        case AuthErrorCode.userDisabled.rawValue:
            return .userDisabled
            
        default:
            return .unknown(authError.localizedDescription)
        }
    }
}

// MARK: - Auth Errors

/// Errores de autenticación con mensajes en español
enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case userNotFound
    case invalidEmail
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case tooManyRequests
    case userDisabled
    case signOutFailed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Email o contraseña incorrectos"
        case .userNotFound:
            return "Usuario no encontrado"
        case .invalidEmail:
            return "El formato del email no es válido"
        case .emailAlreadyInUse:
            return "Este email ya está registrado"
        case .weakPassword:
            return "La contraseña debe tener al menos 6 caracteres"
        case .networkError:
            return "Error de conexión. Verifica tu internet"
        case .tooManyRequests:
            return "Demasiados intentos. Intenta más tarde"
        case .userDisabled:
            return "Esta cuenta ha sido deshabilitada"
        case .signOutFailed:
            return "Error al cerrar sesión"
        case .unknown(let message):
            return "Error desconocido: \(message)"
        }
    }
}
