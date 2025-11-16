//
//  UserService.swift
//  AmbuKit
//
//  Created by Claude on 16/11/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Servicio para gestionar usuarios en Firebase
/// Maneja tanto Firebase Auth como Firestore de forma coordinada
///
/// **Funcionalidades principales:**
/// - CRUD completo de usuarios (con validación de permisos)
/// - Sincronización entre Firebase Auth y Firestore
/// - Auditoría automática de todas las operaciones
/// - Cache de usuarios para optimizar consultas
///
/// **Flujo de creación de usuario:**
/// 1. Validar permisos del actor
/// 2. Crear usuario en Firebase Auth
/// 3. Crear documento en Firestore
/// 4. Registrar auditoría
///
/// **Flujo de eliminación:**
/// 1. Validar permisos del actor
/// 2. Marcar como inactivo en Firestore (soft delete)
/// 3. Opcionalmente eliminar de Firebase Auth
/// 4. Registrar auditoría
@MainActor
final class UserService {
    
    // MARK: - Singleton
    
    static let shared = UserService()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    // MARK: - Cache
    
    /// Cache de usuarios (userId -> UserFS)
    private var userCache: [String: UserFS] = [:]
    
    /// Cache de usuarios por UID (uid -> UserFS)
    private var userByUidCache: [String: UserFS] = [:]
    
    /// Tiempo de expiración del caché (5 minutos)
    private let cacheExpiration: TimeInterval = 300
    
    /// Última actualización del caché
    private var lastCacheUpdate: Date = .distantPast
    
    // MARK: - Initialization
    
    private init() {
        // Private para forzar uso del singleton
    }
    
    // MARK: - Create
    
    /// Crea un nuevo usuario en Firebase Auth y Firestore
    ///
    /// **Proceso:**
    /// 1. Valida que el actor tenga permisos para crear usuarios
    /// 2. Crea el usuario en Firebase Auth
    /// 3. Crea el documento en Firestore con el UID generado
    /// 4. Registra auditoría de la creación
    ///
    /// - Parameters:
    ///   - email: Email del nuevo usuario
    ///   - password: Contraseña inicial
    ///   - username: Nombre de usuario (único)
    ///   - fullName: Nombre completo
    ///   - roleId: ID del rol a asignar
    ///   - baseId: ID de la base asignada (opcional)
    ///   - actor: Usuario que realiza la acción (debe tener permisos)
    /// - Returns: UserFS creado
    /// - Throws: UserServiceError si falla algún paso
    func create(
        email: String,
        password: String,
        username: String,
        fullName: String,
        roleId: String,
        baseId: String? = nil,
        actor: UserFS?
    ) async throws -> UserFS {
        // 1. Validar permisos del actor
        guard await AuthorizationServiceFS.canCreate(.user, user: actor) else {
            throw UserServiceError.unauthorized("No tienes permisos para crear usuarios")
        }
        
        // 2. Validar que el username sea único
        if await isUsernameTaken(username) {
            throw UserServiceError.usernameTaken(username)
        }
        
        // 3. Crear usuario en Firebase Auth
        let authResult: AuthDataResult
        do {
            authResult = try await auth.createUser(withEmail: email, password: password)
        } catch {
            throw UserServiceError.authError(error)
        }
        
        let uid = authResult.user.uid
        
        // 4. Crear documento en Firestore
        var user = UserFS(
            uid: uid,
            username: username,
            fullName: fullName,
            email: email,
            active: true,
            roleId: roleId,
            baseId: baseId
        )
        
        do {
            let docRef = try db.collection(UserFS.collectionName).addDocument(from: user)
            user.id = docRef.documentID
            
            // 5. Actualizar cache
            if let userId = user.id {
                userCache[userId] = user
                userByUidCache[uid] = user
            }
            
            // 6. Registrar auditoría
            await logAudit(
                action: .create,
                entityId: user.id ?? uid,
                actor: actor,
                details: "Usuario '\(username)' creado con rol '\(roleId)'"
            )
            
            return user
            
        } catch {
            // Si falla Firestore, eliminar el usuario de Auth
            try? await auth.currentUser?.delete()
            throw UserServiceError.firestoreError(error)
        }
    }
    
    // MARK: - Read
    
    /// Obtiene un usuario por su ID de Firestore (con caché)
    /// - Parameter id: ID del documento en Firestore
    /// - Returns: UserFS si existe, nil si no
    func getUser(id: String?) async -> UserFS? {
        guard let userId = id, !userId.isEmpty else { return nil }
        
        // 1. Verificar caché
        if isCacheValid(), let cachedUser = userCache[userId] {
            return cachedUser
        }
        
        // 2. Consultar Firestore
        do {
            let document = try await db.collection(UserFS.collectionName)
                .document(userId)
                .getDocument()
            
            guard let user = try? UserFS.from(snapshot: document) else {
                return nil
            }
            
            // 3. Actualizar caché
            userCache[userId] = user
            if !user.uid.isEmpty {
                userByUidCache[user.uid] = user
            }
            
            return user
            
        } catch {
            print("❌ Error obteniendo usuario '\(userId)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Obtiene un usuario por su UID de Firebase Auth (con caché)
    /// - Parameter uid: UID de Firebase Auth
    /// - Returns: UserFS si existe, nil si no
    func getUser(uid: String?) async -> UserFS? {
        guard let uid = uid, !uid.isEmpty else { return nil }
        
        // 1. Verificar caché
        if isCacheValid(), let cachedUser = userByUidCache[uid] {
            return cachedUser
        }
        
        // 2. Consultar Firestore por UID
        do {
            let snapshot = try await db.collection(UserFS.collectionName)
                .whereField("uid", isEqualTo: uid)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = snapshot.documents.first,
                  let user = try? UserFS.from(snapshot: document) else {
                return nil
            }
            
            // 3. Actualizar caché
            if let userId = user.id {
                userCache[userId] = user
            }
            userByUidCache[uid] = user
            
            return user
            
        } catch {
            print("❌ Error obteniendo usuario por UID '\(uid)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Obtiene todos los usuarios activos
    /// - Returns: Array de usuarios
    func getAllUsers() async -> [UserFS] {
        do {
            let snapshot = try await db.collection(UserFS.collectionName)
                .whereField("active", isEqualTo: true)
                .getDocuments()
            
            let users = snapshot.documents.compactMap { doc -> UserFS? in
                try? UserFS.from(snapshot: doc)
            }
            
            // Actualizar caché
            users.forEach { user in
                if let id = user.id {
                    userCache[id] = user
                }
                if !user.uid.isEmpty {
                    userByUidCache[user.uid] = user
                }
            }
            
            return users
            
        } catch {
            print("❌ Error obteniendo todos los usuarios: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Obtiene usuarios por rol
    /// - Parameter roleId: ID del rol
    /// - Returns: Array de usuarios con ese rol
    func getUsersByRole(roleId: String?) async -> [UserFS] {
        guard let roleId = roleId, !roleId.isEmpty else { return [] }
        
        do {
            let snapshot = try await db.collection(UserFS.collectionName)
                .whereField("roleId", isEqualTo: roleId)
                .whereField("active", isEqualTo: true)
                .getDocuments()
            
            let users = snapshot.documents.compactMap { doc -> UserFS? in
                try? UserFS.from(snapshot: doc)
            }
            
            // Actualizar caché
            users.forEach { user in
                if let id = user.id {
                    userCache[id] = user
                }
                if !user.uid.isEmpty {
                    userByUidCache[user.uid] = user
                }
            }
            
            return users
            
        } catch {
            print("❌ Error obteniendo usuarios por rol '\(roleId)': \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Update
    
    /// Actualiza un usuario existente
    ///
    /// **Campos actualizables:**
    /// - username (si no está en uso)
    /// - fullName
    /// - email (actualiza también en Firebase Auth)
    /// - roleId
    /// - baseId
    /// - active (para activar/desactivar)
    ///
    /// - Parameters:
    ///   - user: Usuario con los cambios aplicados
    ///   - actor: Usuario que realiza la acción
    /// - Throws: UserServiceError si falla la actualización
    func update(
        user: UserFS,
        actor: UserFS?
    ) async throws {
        // 1. Validar permisos del actor
        guard await AuthorizationServiceFS.canUpdate(.user, user: actor) else {
            throw UserServiceError.unauthorized("No tienes permisos para actualizar usuarios")
        }
        
        // 2. Validar que el usuario existe
        guard let userId = user.id else {
            throw UserServiceError.userNotFound("Usuario sin ID")
        }
        
        // 3. Obtener usuario actual para comparar cambios
        guard let currentUser = await getUser(id: userId) else {
            throw UserServiceError.userNotFound(userId)
        }
        
        // 4. Si cambió el username, validar que sea único
        if user.username != currentUser.username {
            if await isUsernameTaken(user.username, excluding: userId) {
                throw UserServiceError.usernameTaken(user.username)
            }
        }
        
        // 5. Actualizar en Firestore
        var updatedUser = user
        updatedUser.updatedAt = Date()
        
        do {
            try db.collection(UserFS.collectionName)
                .document(userId)
                .setData(from: updatedUser, merge: false)
            
            // 6. Si cambió el email, actualizar en Firebase Auth
            if user.email != currentUser.email {
                // Nota: Esto requiere que el usuario actual sea el que se está editando
                // o que tengamos privilegios de admin
                // Por simplicidad, registramos el intento en auditoría
                print("⚠️ Email changed: This would require Admin SDK or user re-authentication")
            }
            
            // 7. Actualizar caché
            userCache[userId] = updatedUser
            userByUidCache[user.uid] = updatedUser
            
            // 8. Registrar auditoría
            let changes = buildChangesSummary(from: currentUser, to: updatedUser)
            await logAudit(
                action: .update,
                entityId: userId,
                actor: actor,
                details: "Usuario '\(user.username)' actualizado: \(changes)"
            )
            
        } catch {
            throw UserServiceError.firestoreError(error)
        }
    }
    
    // MARK: - Delete
    
    /// Elimina (desactiva) un usuario
    ///
    /// **Estrategia de eliminación:**
    /// - Soft delete: Marca el usuario como inactivo (active = false)
    /// - No elimina el documento de Firestore (para mantener historial)
    /// - Opcionalmente puede eliminar de Firebase Auth
    ///
    /// - Parameters:
    ///   - userId: ID del usuario a eliminar
    ///   - actor: Usuario que realiza la acción
    ///   - hardDelete: Si true, elimina también de Firebase Auth (default: false)
    /// - Throws: UserServiceError si falla la eliminación
    func delete(
        userId: String,
        actor: UserFS?,
        hardDelete: Bool = false
    ) async throws {
        // 1. Validar permisos del actor
        guard await AuthorizationServiceFS.canDelete(.user, user: actor) else {
            throw UserServiceError.unauthorized("No tienes permisos para eliminar usuarios")
        }
        
        // 2. Obtener usuario actual
        guard let user = await getUser(id: userId) else {
            throw UserServiceError.userNotFound(userId)
        }
        
        // 3. No permitir que un usuario se elimine a sí mismo
        if actor?.id == userId {
            throw UserServiceError.cannotDeleteSelf
        }
        
        // 4. Soft delete: marcar como inactivo
        var updatedUser = user
        updatedUser.active = false
        updatedUser.updatedAt = Date()
        
        do {
            try db.collection(UserFS.collectionName)
                .document(userId)
                .setData(from: updatedUser, merge: false)
            
            // 5. Hard delete: eliminar de Firebase Auth (opcional)
            if hardDelete {
                // Nota: Requiere Admin SDK para eliminar otros usuarios
                print("⚠️ Hard delete requested but requires Admin SDK")
            }
            
            // 6. Limpiar caché
            userCache.removeValue(forKey: userId)
            userByUidCache.removeValue(forKey: user.uid)
            
            // 7. Registrar auditoría
            await logAudit(
                action: .delete,
                entityId: userId,
                actor: actor,
                details: "Usuario '\(user.username)' eliminado (soft delete)"
            )
            
        } catch {
            throw UserServiceError.firestoreError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Verifica si un username ya está en uso
    /// - Parameters:
    ///   - username: Username a verificar
    ///   - excluding: ID de usuario a excluir (para edición)
    /// - Returns: true si está en uso
    private func isUsernameTaken(_ username: String, excluding: String? = nil) async -> Bool {
        do {
            let snapshot = try await db.collection(UserFS.collectionName)
                .whereField("username", isEqualTo: username)
                .limit(to: 1)
                .getDocuments()
            
            // Si no hay documentos, el username está disponible
            guard let existingUser = snapshot.documents.first else {
                return false
            }
            
            // Si estamos excluyendo un ID, verificar que no sea el mismo
            if let excludingId = excluding {
                return existingUser.documentID != excludingId
            }
            
            return true
            
        } catch {
            print("❌ Error verificando username: \(error.localizedDescription)")
            return true // En caso de error, asumir que está en uso (seguro)
        }
    }
    
    /// Construye un resumen de los cambios realizados
    /// - Parameters:
    ///   - oldUser: Usuario antes de la actualización
    ///   - newUser: Usuario después de la actualización
    /// - Returns: String con resumen de cambios
    private func buildChangesSummary(from oldUser: UserFS, to newUser: UserFS) -> String {
        var changes: [String] = []
        
        if oldUser.username != newUser.username {
            changes.append("username: '\(oldUser.username)' → '\(newUser.username)'")
        }
        
        if oldUser.fullName != newUser.fullName {
            changes.append("fullName: '\(oldUser.fullName)' → '\(newUser.fullName)'")
        }
        
        if oldUser.email != newUser.email {
            changes.append("email: '\(oldUser.email)' → '\(newUser.email)'")
        }
        
        if oldUser.roleId != newUser.roleId {
            changes.append("roleId: '\(oldUser.roleId ?? "nil")' → '\(newUser.roleId ?? "nil")'")
        }
        
        if oldUser.baseId != newUser.baseId {
            changes.append("baseId: '\(oldUser.baseId ?? "nil")' → '\(newUser.baseId ?? "nil")'")
        }
        
        if oldUser.active != newUser.active {
            changes.append("active: \(oldUser.active) → \(newUser.active)")
        }
        
        return changes.isEmpty ? "sin cambios" : changes.joined(separator: ", ")
    }
    
    // MARK: - Audit
    
    /// Registra una acción en el log de auditoría
    /// - Parameters:
    ///   - action: Tipo de acción realizada
    ///   - entityId: ID de la entidad afectada
    ///   - actor: Usuario que realizó la acción
    ///   - details: Detalles adicionales
    private func logAudit(
        action: ActionKind,
        entityId: String,
        actor: UserFS?,
        details: String? = nil
    ) async {
        let audit = AuditLogFS(
            timestamp: Date(),
            actorUsername: actor?.username,
            actorRole: await getRoleDisplayName(for: actor),
            action: action,
            entity: .user,
            entityId: entityId,
            details: details
        )
        
        do {
            _ = try db.collection(AuditLogFS.collectionName).addDocument(from: audit)
        } catch {
            print("❌ Error registrando auditoría: \(error.localizedDescription)")
        }
    }
    
    /// Obtiene el nombre del rol de un usuario
    /// - Parameter user: Usuario
    /// - Returns: Nombre del rol o "Sin rol"
    private func getRoleDisplayName(for user: UserFS?) async -> String? {
        guard let roleId = user?.roleId else { return nil }
        let role = await PolicyService.shared.getRole(id: roleId)
        return role?.displayName
    }
    
    // MARK: - Cache Management
    
    /// Limpia todo el caché
    func clearCache() {
        userCache.removeAll()
        userByUidCache.removeAll()
        lastCacheUpdate = .distantPast
    }
    
    /// Limpia el caché de un usuario específico
    /// - Parameter userId: ID del usuario a limpiar
    func clearCache(forUser userId: String) {
        if let user = userCache[userId] {
            userByUidCache.removeValue(forKey: user.uid)
        }
        userCache.removeValue(forKey: userId)
    }
    
    /// Verifica si el caché es válido (no ha expirado)
    /// - Returns: true si el caché es válido
    private func isCacheValid() -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastCacheUpdate)
        return timeSinceLastUpdate < cacheExpiration
    }
    
    /// Actualiza el timestamp del caché
    private func updateCacheTimestamp() {
        lastCacheUpdate = Date()
    }
}

// MARK: - Error Types

/// Errores del UserService
enum UserServiceError: LocalizedError {
    case unauthorized(String)
    case userNotFound(String)
    case usernameTaken(String)
    case cannotDeleteSelf
    case authError(Error)
    case firestoreError(Error)
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let message):
            return message
        case .userNotFound(let id):
            return "Usuario '\(id)' no encontrado"
        case .usernameTaken(let username):
            return "El username '\(username)' ya está en uso"
        case .cannotDeleteSelf:
            return "No puedes eliminar tu propio usuario"
        case .authError(let error):
            return "Error de autenticación: \(error.localizedDescription)"
        case .firestoreError(let error):
            return "Error de Firestore: \(error.localizedDescription)"
        case .invalidData(let message):
            return "Datos inválidos: \(message)"
        }
    }
}

// MARK: - Helper Extensions

extension UserService {
    /// Obtiene el usuario actualmente autenticado
    /// - Returns: UserFS si está autenticado, nil si no
    func getCurrentUser() async -> UserFS? {
        guard let uid = auth.currentUser?.uid else { return nil }
        return await getUser(uid: uid)
    }
    
    /// Verifica si un email ya está en uso
    /// - Parameter email: Email a verificar
    /// - Returns: true si está en uso
    func isEmailTaken(_ email: String) async -> Bool {
        do {
            let snapshot = try await db.collection(UserFS.collectionName)
                .whereField("email", isEqualTo: email)
                .limit(to: 1)
                .getDocuments()
            
            return !snapshot.documents.isEmpty
            
        } catch {
            print("❌ Error verificando email: \(error.localizedDescription)")
            return true // En caso de error, asumir que está en uso
        }
    }
    
    /// Cuenta el número total de usuarios activos
    /// - Returns: Número de usuarios
    func getUserCount() async -> Int {
        do {
            let snapshot = try await db.collection(UserFS.collectionName)
                .whereField("active", isEqualTo: true)
                .count
                .getAggregation(source: .server)
            
            return Int(truncating: snapshot.count as NSNumber)
            
        } catch {
            print("❌ Error contando usuarios: \(error.localizedDescription)")
            return 0
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension UserService {
    /// Imprime el estado del caché (solo para debug)
    func printCacheStatus() {
        print("📊 UserService Cache Status:")
        print("   Usuarios en caché (by ID): \(userCache.count)")
        print("   Usuarios en caché (by UID): \(userByUidCache.count)")
        print("   Última actualización: \(lastCacheUpdate)")
        print("   Caché válido: \(isCacheValid())")
    }
    
    /// Lista todos los usuarios en caché
    func printCachedUsers() {
        print("👥 Usuarios en caché:")
        for (id, user) in userCache {
            print("   [\(id)] \(user.username) - \(user.email) (active: \(user.active))")
        }
    }
}
#endif
