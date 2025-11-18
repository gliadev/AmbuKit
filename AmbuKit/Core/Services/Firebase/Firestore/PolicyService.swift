//
//  PolicyService.swift
//  AmbuKit
//
//  Created by Adolfo on 15/11/25.
//

import Foundation
import FirebaseFirestore
import Combine

/// Servicio para gestionar roles y políticas desde Firestore
/// Implementa un sistema de caché para optimizar consultas repetidas
@MainActor
final class PolicyService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = PolicyService()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    
    // MARK: - Cache
    
    /// Caché de roles (roleId -> RoleFS)
    private var roleCache: [String: RoleFS] = [:]
    
    /// Caché de policies (roleId -> [PolicyFS])
    private var policyCache: [String: [PolicyFS]] = [:]
    
    /// Tiempo de expiración del caché (5 minutos)
    private let cacheExpiration: TimeInterval = 300
    
    /// Última actualización del caché
    private var lastCacheUpdate: Date = .distantPast
    
    // MARK: - Initialization
    
    private init() {
        // Private para forzar uso del singleton
    }
    
    // MARK: - Public Methods - Roles
    
    /// Obtiene un rol desde Firestore (con caché)
    /// - Parameter id: ID del rol
    /// - Returns: RoleFS si existe, nil si no
    func getRole(id: String?) async -> RoleFS? {
        guard let roleId = id, !roleId.isEmpty else { return nil }
        
        // 1. Verificar caché
        if isCacheValid(), let cachedRole = roleCache[roleId] {
            return cachedRole
        }
        
        // 2. Consultar Firestore
        do {
            let document = try await db.collection(RoleFS.collectionName)
                .document(roleId)
                .getDocument()
            
            guard let role = try? RoleFS.from(snapshot: document) else {
                return nil
            }
            
            // 3. Actualizar caché
            roleCache[roleId] = role
            return role
            
        } catch {
            print("❌ Error obteniendo rol '\(roleId)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Obtiene todos los roles desde Firestore
    /// - Returns: Array de roles
    func getAllRoles() async -> [RoleFS] {
        do {
            let snapshot = try await db.collection(RoleFS.collectionName).getDocuments()
            
            let roles = snapshot.documents.compactMap { doc -> RoleFS? in
                try? RoleFS.from(snapshot: doc)
            }
            
            // Actualizar caché
            roles.forEach { role in
                if let id = role.id {
                    roleCache[id] = role
                }
            }
            
            return roles
            
        } catch {
            print("❌ Error obteniendo todos los roles: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Public Methods - Policies
    
    /// Obtiene todas las policies de un rol (con caché)
    /// - Parameter roleId: ID del rol
    /// - Returns: Array de policies
    func getPolicies(roleId: String?) async -> [PolicyFS] {
        guard let roleId = roleId, !roleId.isEmpty else { return [] }
        
        // 1. Verificar caché
        if isCacheValid(), let cachedPolicies = policyCache[roleId] {
            return cachedPolicies
        }
        
        // 2. Consultar Firestore
        do {
            let snapshot = try await db.collection(PolicyFS.collectionName)
                .whereField("roleId", isEqualTo: roleId)
                .getDocuments()
            
            let policies = snapshot.documents.compactMap { doc -> PolicyFS? in
                try? PolicyFS.from(snapshot: doc)
            }
            
            // 3. Actualizar caché
            policyCache[roleId] = policies
            return policies
            
        } catch {
            print("❌ Error obteniendo policies del rol '\(roleId)': \(error.localizedDescription)")
            return []
        }
    }
    
    /// Obtiene una policy específica para un rol y entidad (con caché)
    /// - Parameters:
    ///   - roleId: ID del rol
    ///   - entity: Tipo de entidad (kit, user, etc.)
    /// - Returns: PolicyFS si existe, nil si no
    func getPolicy(roleId: String?, entity: EntityKind) async -> PolicyFS? {
        guard let roleId = roleId else { return nil }
        
        // Obtener todas las policies del rol (usa caché internamente)
        let policies = await getPolicies(roleId: roleId)
        
        // Buscar la policy específica para esta entidad
        return policies.first(where: { $0.entity == entity })
    }
    
    // MARK: - Public Methods - CRUD Operations
    
    /// Crea un nuevo rol en Firestore
    /// - Parameters:
    ///   - kind: Tipo de rol (programmer, logistics, sanitary)
    ///   - displayName: Nombre para mostrar
    /// - Returns: RoleFS creado
    func createRole(kind: RoleKind, displayName: String) async throws -> RoleFS {
        var role = RoleFS(kind: kind, displayName: displayName)
        
        let docRef = try db.collection(RoleFS.collectionName).addDocument(from: role)
        role.id = docRef.documentID
        
        // Actualizar caché
        if let id = role.id {
            roleCache[id] = role
        }
        
        return role
    }
    
    /// Crea una nueva policy en Firestore
    /// - Parameters:
    ///   - roleId: ID del rol
    ///   - entity: Entidad a la que aplica
    ///   - canCreate: Permiso de creación
    ///   - canRead: Permiso de lectura
    ///   - canUpdate: Permiso de actualización
    ///   - canDelete: Permiso de eliminación
    /// - Returns: PolicyFS creada
    func createPolicy(
        roleId: String,
        entity: EntityKind,
        canCreate: Bool,
        canRead: Bool,
        canUpdate: Bool,
        canDelete: Bool
    ) async throws -> PolicyFS {
        var policy = PolicyFS(
            entity: entity,
            canCreate: canCreate,
            canRead: canRead,
            canUpdate: canUpdate,
            canDelete: canDelete,
            roleId: roleId
        )
        
        let docRef = try db.collection(PolicyFS.collectionName).addDocument(from: policy)
        policy.id = docRef.documentID
        
        // Invalidar caché de policies para este rol
        policyCache.removeValue(forKey: roleId)
        
        return policy
    }
    
    // MARK: - Cache Management
    
    /// Limpia todo el caché
    func clearCache() {
        roleCache.removeAll()
        policyCache.removeAll()
        lastCacheUpdate = .distantPast
    }
    
    /// Limpia el caché de un rol específico
    /// - Parameter roleId: ID del rol a limpiar
    func clearCache(forRole roleId: String) {
        roleCache.removeValue(forKey: roleId)
        policyCache.removeValue(forKey: roleId)
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
    
    // MARK: - Pre-loading (Optional)
    
    /// Pre-carga roles y policies más comunes
    /// Útil para llamar al inicio de la app
    func preloadCommonData() async {
        // Pre-cargar todos los roles (son pocos)
        _ = await getAllRoles()
        
        // Pre-cargar policies de roles comunes
        for role in roleCache.values {
            if let roleId = role.id {
                _ = await getPolicies(roleId: roleId)
            }
        }
        
        updateCacheTimestamp()
    }
}

// MARK: - Error Types

enum PolicyServiceError: LocalizedError {
    case roleNotFound(String)
    case policyNotFound(String, EntityKind)
    case invalidRoleId
    case firestoreError(Error)
    
    var errorDescription: String? {
        switch self {
        case .roleNotFound(let id):
            return "Rol con ID '\(id)' no encontrado"
        case .policyNotFound(let roleId, let entity):
            return "Policy para rol '\(roleId)' y entidad '\(entity)' no encontrada"
        case .invalidRoleId:
            return "ID de rol inválido"
        case .firestoreError(let error):
            return "Error de Firestore: \(error.localizedDescription)"
        }
    }
}

// MARK: - Helper Extensions

extension PolicyService {
    /// Obtiene el RoleKind de un usuario
    /// - Parameter user: Usuario
    /// - Returns: RoleKind si existe, nil si no
    func getRoleKind(for user: UserFS?) async -> RoleKind? {
        guard let roleId = user?.roleId else { return nil }
        let role = await getRole(id: roleId)
        return role?.kind
    }
    
    /// Verifica si un usuario es programador
    /// - Parameter user: Usuario
    /// - Returns: true si es programador
    func isProgrammer(_ user: UserFS?) async -> Bool {
        let kind = await getRoleKind(for: user)
        return kind == .programmer
    }
    
    /// Verifica si un usuario es logística
    /// - Parameter user: Usuario
    /// - Returns: true si es logística
    func isLogistics(_ user: UserFS?) async -> Bool {
        let kind = await getRoleKind(for: user)
        return kind == .logistics
    }
    
    /// Verifica si un usuario es sanitario
    /// - Parameter user: Usuario
    /// - Returns: true si es sanitario
    func isSanitary(_ user: UserFS?) async -> Bool {
        let kind = await getRoleKind(for: user)
        return kind == .sanitary
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension PolicyService {
    /// Imprime el estado del caché (solo para debug)
    func printCacheStatus() {
        print("📊 PolicyService Cache Status:")
        print("   Roles en caché: \(roleCache.count)")
        print("   Policies en caché: \(policyCache.count)")
        print("   Última actualización: \(lastCacheUpdate)")
        print("   Caché válido: \(isCacheValid())")
    }
    
    /// Imprime todas las policies de un rol (debug)
    func printPolicies(forRole roleId: String) async {
        let policies = await getPolicies(roleId: roleId)
        print("📋 Policies para rol '\(roleId)':")
        for policy in policies {
            print("   \(policy.entity.rawValue): C:\(policy.canCreate) R:\(policy.canRead) U:\(policy.canUpdate) D:\(policy.canDelete)")
        }
    }
}
#endif
