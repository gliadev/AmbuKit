//
//  AppState.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

/// Estado global de la aplicación
/// Gestiona el usuario autenticado y su información de Firestore
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AppState()
    
    // MARK: - Published Properties
    
    /// Usuario actual cargado desde Firestore (con rol y base)
    @Published private(set) var currentUser: UserFS?
    
    /// Indica si hay una sesión activa
    @Published private(set) var isAuthenticated = false
    
    /// Indica si se está cargando información del usuario
    @Published private(set) var isLoadingUser = false
    
    /// Error actual (si lo hay)
    @Published var currentError: AppError?
    
    // MARK: - Private Properties
    
    private let authService = FirebaseAuthService.shared
    private let db = Firestore.firestore()
    
    // MARK: - Initialization
    
    private init() {
        // Observar cambios en el estado de autenticación
        Task {
            await observeAuthState()
        }
    }
    
    // MARK: - Auth State Observer
    
    /// Observar cambios en el estado de autenticación
    private func observeAuthState() async {
        // Cuando cambia el estado de auth, cargar el usuario de Firestore
        for await isAuth in authService.$isAuthenticated.values {
            self.isAuthenticated = isAuth
            
            if isAuth, let uid = authService.currentAuthUser?.uid {
                await loadCurrentUser(uid: uid)
            } else {
                self.currentUser = nil
            }
        }
    }
    
    // MARK: - Sign In
    
    /// Iniciar sesión y cargar usuario de Firestore
    func signIn(email: String, password: String) async {
        isLoadingUser = true
        currentError = nil
        
        do {
            let uid = try await authService.signIn(email: email, password: password)
            await loadCurrentUser(uid: uid)
        } catch let error as AuthError {
            currentError = .auth(error)
        } catch {
            currentError = .unknown(error.localizedDescription)
        }
        
        isLoadingUser = false
    }
    
    // MARK: - Sign Out
    
    /// Cerrar sesión
    func signOut() async {
        currentError = nil
        
        do {
            try await authService.signOut()
            currentUser = nil
        } catch {
            currentError = .signOutFailed
        }
    }
    
    // MARK: - Load User
    
    /// Cargar usuario completo desde Firestore (con rol y base)
    private func loadCurrentUser(uid: String) async {
        isLoadingUser = true
        currentError = nil
        
        do {
            // 1. Buscar usuario por UID
            let snapshot = try await db.collection(UserFS.collectionName)
                .whereField("uid", isEqualTo: uid)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = snapshot.documents.first else {
                currentError = .userNotFoundInFirestore
                isLoadingUser = false
                return
            }
            
            // 2. Decodificar usuario
            var user = try document.data(as: UserFS.self)
            
            // 3. Cargar rol si existe
            if let roleId = user.roleId {
                user.role = try await loadRole(id: roleId)
            }
            
            // 4. Cargar base si existe
            if let baseId = user.baseId {
                user.base = try await loadBase(id: baseId)
            }
            
            // 5. Actualizar estado
            self.currentUser = user
            
        } catch {
            currentError = .loadUserFailed(error.localizedDescription)
        }
        
        isLoadingUser = false
    }
    
    // MARK: - Load Related Data
    
    /// Cargar rol desde Firestore
    private func loadRole(id: String) async throws -> RoleFS? {
        let document = try await db.collection(RoleFS.collectionName)
            .document(id)
            .getDocument()
        
        return try document.data(as: RoleFS.self)
    }
    
    /// Cargar base desde Firestore
    private func loadBase(id: String) async throws -> BaseFS? {
        let document = try await db.collection(BaseFS.collectionName)
            .document(id)
            .getDocument()
        
        return try document.data(as: BaseFS.self)
    }
    
    // MARK: - Refresh User
    
    /// Recargar información del usuario actual
    func refreshCurrentUser() async {
        guard let uid = authService.currentAuthUser?.uid else {
            currentUser = nil
            return
        }
        
        await loadCurrentUser(uid: uid)
    }
}

// MARK: - App Errors

/// Errores de la aplicación
enum AppError: LocalizedError, Equatable {
    case auth(AuthError)
    case userNotFoundInFirestore
    case loadUserFailed(String)
    case signOutFailed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .auth(let authError):
            return authError.errorDescription
        case .userNotFoundInFirestore:
            return "Usuario no encontrado en la base de datos"
        case .loadUserFailed(let message):
            return "Error al cargar usuario: \(message)"
        case .signOutFailed:
            return "Error al cerrar sesión"
        case .unknown(let message):
            return message
        }
    }
}
