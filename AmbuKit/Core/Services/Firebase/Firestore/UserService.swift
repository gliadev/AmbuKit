//
//  UserService.swift
//  AmbuKit
//
//  CORREGIDO: TAREA A+B - Uso correcto de async/await en creación y actualización
//
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class UserService {
    
    static let shared = UserService()
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    private var userCache: [String: UserFS] = [:]
    private var userByUidCache: [String: UserFS] = [:]
    private let cacheExpiration: TimeInterval = 300
    private var lastCacheUpdate: Date = .distantPast
    
    private init() {}
    
    // MARK: - Create
    
    func create(
        email: String, password: String, username: String, fullName: String,
        roleId: String, baseId: String? = nil, actor: UserFS?
    ) async throws -> UserFS {
        guard await AuthorizationServiceFS.canCreate(.user, user: actor) else {
            throw UserServiceError.unauthorized("No tienes permisos para crear usuarios")
        }
        
        if await isUsernameTaken(username) {
            throw UserServiceError.usernameTaken(username)
        }
        
        let authResult: AuthDataResult
        do {
            authResult = try await auth.createUser(withEmail: email, password: password)
        } catch {
            throw UserServiceError.authError(error)
        }
        
        let uid = authResult.user.uid
        var user = UserFS(uid: uid, username: username, fullName: fullName, email: email, active: true, roleId: roleId, baseId: baseId)
        
        do {
            let docRef = db.collection(UserFS.collectionName).document()
            user.id = docRef.documentID
            
            let encodedData = try Firestore.Encoder().encode(user)
            try await docRef.setData(encodedData)
            
            userCache[docRef.documentID] = user
            userByUidCache[uid] = user
            
            await logAudit(action: .create, entityId: user.id ?? uid, actor: actor, details: "Usuario '\(username)' creado")
            print("✅ Usuario '\(username)' creado con ID: \(docRef.documentID)")
            return user
        } catch {
            try? await authResult.user.delete()
            throw UserServiceError.firestoreError(error)
        }
    }
    
    // MARK: - Read
    
    func getUser(id: String?) async -> UserFS? {
        guard let userId = id, !userId.isEmpty else { return nil }
        if isCacheValid(), let cached = userCache[userId] { return cached }
        
        do {
            let doc = try await db.collection(UserFS.collectionName).document(userId).getDocument()
            guard let user = try? doc.data(as: UserFS.self) else { return nil }
            userCache[userId] = user
            if !user.uid.isEmpty { userByUidCache[user.uid] = user }
            return user
        } catch { return nil }
    }
    
    func getUser(uid: String?) async -> UserFS? {
        guard let uid = uid, !uid.isEmpty else { return nil }
        if isCacheValid(), let cached = userByUidCache[uid] { return cached }
        
        do {
            let snapshot = try await db.collection(UserFS.collectionName).whereField("uid", isEqualTo: uid).limit(to: 1).getDocuments()
            guard let doc = snapshot.documents.first, let user = try? doc.data(as: UserFS.self) else { return nil }
            if let userId = user.id { userCache[userId] = user }
            userByUidCache[uid] = user
            return user
        } catch { return nil }
    }
    
    func getAllUsers() async -> [UserFS] {
        do {
            let snapshot = try await db.collection(UserFS.collectionName).whereField("active", isEqualTo: true).getDocuments()
            let users = snapshot.documents.compactMap { try? $0.data(as: UserFS.self) }
            users.forEach {
                if let id = $0.id { userCache[id] = $0 }
                if !$0.uid.isEmpty { userByUidCache[$0.uid] = $0 }
            }
            return users
        } catch { return [] }
    }
    
    func getUsersByRole(roleId: String?) async -> [UserFS] {
        guard let roleId = roleId, !roleId.isEmpty else { return [] }
        do {
            let snapshot = try await db.collection(UserFS.collectionName)
                .whereField("roleId", isEqualTo: roleId)
                .whereField("active", isEqualTo: true).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: UserFS.self) }
        } catch { return [] }
    }
    
    // MARK: - Update
    
    func update(user: UserFS, actor: UserFS?) async throws {
        guard await AuthorizationServiceFS.canUpdate(.user, user: actor) else {
            throw UserServiceError.unauthorized("No tienes permisos para actualizar usuarios")
        }
        guard let userId = user.id else { throw UserServiceError.userNotFound("Usuario sin ID") }
        
        guard let currentUser = await getUser(id: userId) else {
            throw UserServiceError.userNotFound(userId)
        }
        
        if user.username != currentUser.username {
            if await isUsernameTaken(user.username, excluding: userId) {
                throw UserServiceError.usernameTaken(user.username)
            }
        }
        
        var updated = user
        updated.updatedAt = Date()
        
        let encodedData = try Firestore.Encoder().encode(updated)
        try await db.collection(UserFS.collectionName).document(userId).setData(encodedData, merge: false)
        
        userCache[userId] = updated
        userByUidCache[user.uid] = updated
        
        let changes = buildChangesSummary(from: currentUser, to: updated)
        await logAudit(action: .update, entityId: userId, actor: actor, details: "Usuario actualizado: \(changes)")
        print("✅ Usuario '\(user.username)' actualizado")
    }
    
    // MARK: - Delete
    
    func delete(userId: String, actor: UserFS?, hardDelete: Bool = false) async throws {
        guard await AuthorizationServiceFS.canDelete(.user, user: actor) else {
            throw UserServiceError.unauthorized("No tienes permisos para eliminar usuarios")
        }
        guard let user = await getUser(id: userId) else {
            throw UserServiceError.userNotFound(userId)
        }
        guard actor?.id != userId else {
            throw UserServiceError.cannotDeleteSelf
        }
        
        var updated = user
        updated.active = false
        updated.updatedAt = Date()
        
        let encodedData = try Firestore.Encoder().encode(updated)
        try await db.collection(UserFS.collectionName).document(userId).setData(encodedData, merge: false)
        
        userCache.removeValue(forKey: userId)
        userByUidCache.removeValue(forKey: user.uid)
        
        await logAudit(action: .delete, entityId: userId, actor: actor, details: "Usuario '\(user.username)' eliminado")
        print("✅ Usuario '\(user.username)' eliminado")
    }
    
    // MARK: - Helpers
    
    private func isUsernameTaken(_ username: String, excluding: String? = nil) async -> Bool {
        do {
            let snapshot = try await db.collection(UserFS.collectionName).whereField("username", isEqualTo: username).limit(to: 1).getDocuments()
            guard let existing = snapshot.documents.first else { return false }
            if let excludingId = excluding { return existing.documentID != excludingId }
            return true
        } catch { return true }
    }
    
    private func buildChangesSummary(from old: UserFS, to new: UserFS) -> String {
        var changes: [String] = []
        if old.username != new.username { changes.append("username") }
        if old.fullName != new.fullName { changes.append("fullName") }
        if old.email != new.email { changes.append("email") }
        if old.roleId != new.roleId { changes.append("roleId") }
        if old.baseId != new.baseId { changes.append("baseId") }
        if old.active != new.active { changes.append("active") }
        return changes.isEmpty ? "sin cambios" : changes.joined(separator: ", ")
    }
    
    // MARK: - Audit
    
    private func logAudit(action: ActionKind, entityId: String, actor: UserFS?, details: String? = nil) async {
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
            let docRef = db.collection(AuditLogFS.collectionName).document()
            let encodedData = try Firestore.Encoder().encode(audit)
            try await docRef.setData(encodedData)
        } catch {
            print("❌ Error registrando auditoría: \(error.localizedDescription)")
        }
    }
    
    private func getRoleDisplayName(for user: UserFS?) async -> String? {
        guard let roleId = user?.roleId else { return nil }
        let role = await PolicyService.shared.getRole(id: roleId)
        return role?.displayName
    }
    
    // MARK: - Cache
    
    func clearCache() { userCache.removeAll(); userByUidCache.removeAll(); lastCacheUpdate = .distantPast }
    func clearCache(forUser userId: String) {
        if let user = userCache[userId] { userByUidCache.removeValue(forKey: user.uid) }
        userCache.removeValue(forKey: userId)
    }
    private func isCacheValid() -> Bool { Date().timeIntervalSince(lastCacheUpdate) < cacheExpiration }
    private func updateCacheTimestamp() { lastCacheUpdate = Date() }
}

// MARK: - Errors

enum UserServiceError: LocalizedError {
    case unauthorized(String), userNotFound(String), usernameTaken(String)
    case cannotDeleteSelf, authError(Error), firestoreError(Error), invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let m): return m
        case .userNotFound(let id): return "Usuario '\(id)' no encontrado"
        case .usernameTaken(let u): return "Username '\(u)' ya en uso"
        case .cannotDeleteSelf: return "No puedes eliminarte a ti mismo"
        case .authError(let e): return "Error de auth: \(e.localizedDescription)"
        case .firestoreError(let e): return "Error de Firestore: \(e.localizedDescription)"
        case .invalidData(let m): return "Datos inválidos: \(m)"
        }
    }
}

// MARK: - Extensions

extension UserService {
    func getCurrentUser() async -> UserFS? {
        guard let uid = auth.currentUser?.uid else { return nil }
        return await getUser(uid: uid)
    }
    
    func isEmailTaken(_ email: String) async -> Bool {
        do {
            let snapshot = try await db.collection(UserFS.collectionName).whereField("email", isEqualTo: email).limit(to: 1).getDocuments()
            return !snapshot.documents.isEmpty
        } catch { return true }
    }
    
    func getUserCount() async -> Int {
        do {
            let snapshot = try await db.collection(UserFS.collectionName).whereField("active", isEqualTo: true).count.getAggregation(source: .server)
            return Int(truncating: snapshot.count as NSNumber)
        } catch { return 0 }
    }
}

#if DEBUG
extension UserService {
    func printCacheStatus() { print("📊 UserService: \(userCache.count) usuarios") }
}
#endif
