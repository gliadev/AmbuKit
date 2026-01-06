//
//  PolicyService.swift
//  AmbuKit
//
//  Created by Adolfo on 15/11/25.
//


import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class PolicyService: ObservableObject {
    
    static let shared = PolicyService()
    private let db = Firestore.firestore()
    
    private var roleCache: [String: RoleFS] = [:]
    private var policyCache: [String: [PolicyFS]] = [:]
    private let cacheExpiration: TimeInterval = 300
    private var lastCacheUpdate: Date = .distantPast
    
    private init() {}
    
    // MARK: - Roles
    
    func getRole(id: String?) async -> RoleFS? {
        guard let roleId = id, !roleId.isEmpty else { return nil }
        if isCacheValid(), let cached = roleCache[roleId] { return cached }
        
        do {
            let doc = try await db.collection(RoleFS.collectionName).document(roleId).getDocument()
            guard let role = try? doc.data(as: RoleFS.self) else { return nil }
            roleCache[roleId] = role
            return role
        } catch {
            print("❌ Error obteniendo rol '\(roleId)': \(error.localizedDescription)")
            return nil
        }
    }
    
    func getAllRoles() async -> [RoleFS] {
        do {
            let snapshot = try await db.collection(RoleFS.collectionName).getDocuments()
            let roles = snapshot.documents.compactMap { try? $0.data(as: RoleFS.self) }
            roles.forEach { if let id = $0.id { roleCache[id] = $0 } }
            return roles
        } catch {
            print("❌ Error obteniendo roles: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Policies
    
    func getPolicies(roleId: String?) async -> [PolicyFS] {
        guard let roleId = roleId, !roleId.isEmpty else { return [] }
        if isCacheValid(), let cached = policyCache[roleId] { return cached }
        
        do {
            let snapshot = try await db.collection(PolicyFS.collectionName).whereField("roleId", isEqualTo: roleId).getDocuments()
            let policies = snapshot.documents.compactMap { try? $0.data(as: PolicyFS.self) }
            policyCache[roleId] = policies
            return policies
        } catch {
            print("❌ Error obteniendo policies del rol '\(roleId)': \(error.localizedDescription)")
            return []
        }
    }
    
    func getPolicy(roleId: String?, entity: EntityKind) async -> PolicyFS? {
        guard let roleId = roleId else { return nil }
        let policies = await getPolicies(roleId: roleId)
        return policies.first(where: { $0.entity == entity })
    }
    
    // MARK: - CRUD Operations
    
    func createRole(kind: RoleKind, displayName: String) async throws -> RoleFS {
        var role = RoleFS(kind: kind, displayName: displayName)
        let docRef = db.collection(RoleFS.collectionName).document()
        role.id = docRef.documentID
        
        let encodedData = try Firestore.Encoder().encode(role)
        try await docRef.setData(encodedData)
        
        roleCache[docRef.documentID] = role
        print("✅ Rol '\(displayName)' creado con ID: \(docRef.documentID)")
        return role
    }
    
    func createPolicy(
        roleId: String, entity: EntityKind,
        canCreate: Bool, canRead: Bool, canUpdate: Bool, canDelete: Bool
    ) async throws -> PolicyFS {
        var policy = PolicyFS(entity: entity, canCreate: canCreate, canRead: canRead, canUpdate: canUpdate, canDelete: canDelete, roleId: roleId)
        let docRef = db.collection(PolicyFS.collectionName).document()
        policy.id = docRef.documentID
        
        let encodedData = try Firestore.Encoder().encode(policy)
        try await docRef.setData(encodedData)
        
        policyCache.removeValue(forKey: roleId)
        print("✅ Policy para '\(entity.rawValue)' creada con ID: \(docRef.documentID)")
        return policy
    }
    
    // MARK: - Cache
    
    func clearCache() { roleCache.removeAll(); policyCache.removeAll(); lastCacheUpdate = .distantPast }
    func clearCache(forRole roleId: String) { roleCache.removeValue(forKey: roleId); policyCache.removeValue(forKey: roleId) }
    private func isCacheValid() -> Bool { Date().timeIntervalSince(lastCacheUpdate) < cacheExpiration }
    private func updateCacheTimestamp() { lastCacheUpdate = Date() }
    
    func preloadCommonData() async {
        _ = await getAllRoles()
        for role in roleCache.values {
            if let roleId = role.id { _ = await getPolicies(roleId: roleId) }
        }
        updateCacheTimestamp()
        print("📦 Roles y policies pre-cargados")
    }
}

// MARK: - Errors

enum PolicyServiceError: LocalizedError {
    case roleNotFound(String), policyNotFound(String, EntityKind), invalidRoleId, firestoreError(Error)
    
    var errorDescription: String? {
        switch self {
        case .roleNotFound(let id): return "Rol '\(id)' no encontrado"
        case .policyNotFound(let r, let e): return "Policy para rol '\(r)' y entidad '\(e)' no encontrada"
        case .invalidRoleId: return "ID de rol inválido"
        case .firestoreError(let e): return "Error de Firestore: \(e.localizedDescription)"
        }
    }
}

// MARK: - Helper Extensions

extension PolicyService {
    func getRoleKind(for user: UserFS?) async -> RoleKind? {
        guard let roleId = user?.roleId else { return nil }
        let role = await getRole(id: roleId)
        return role?.kind
    }
    
    func isProgrammer(_ user: UserFS?) async -> Bool { return await getRoleKind(for: user) == .programmer }
    func isLogistics(_ user: UserFS?) async -> Bool { return await getRoleKind(for: user) == .logistics }
    func isSanitary(_ user: UserFS?) async -> Bool { return await getRoleKind(for: user) == .sanitary }
}

#if DEBUG
extension PolicyService {
    func printCacheStatus() { print("📊 PolicyService: Roles=\(roleCache.count), Policies=\(policyCache.count)") }
    
    func printPolicies(forRole roleId: String) async {
        let policies = await getPolicies(roleId: roleId)
        print("📋 Policies para rol '\(roleId)':")
        for p in policies { print("   \(p.entity.rawValue): C:\(p.canCreate) R:\(p.canRead) U:\(p.canUpdate) D:\(p.canDelete)") }
    }
}
#endif






















