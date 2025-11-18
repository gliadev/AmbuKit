//
//  AuthorizationServiceFS.swift
//  AmbuKit
//
//  Created by Adolfo on 15/11/25.
//

import Foundation

/// Servicio de autorización para Firebase
/// Réplica exacta de AuthorizationService pero adaptado para UserFS y consultas async a Firestore
///
/// **Lógica de permisos (igual que AuthorizationService):**
/// - Programador → Acceso total a todo
/// - Logística → NO crear kits, NO crear/eliminar usuarios, resto permitido
/// - Sanitario → Solo lectura + actualizar stock (KitItem)
@MainActor
public enum AuthorizationServiceFS {
    
    // MARK: - Main Authorization Method
    
    /// Verifica si un usuario tiene permiso para realizar una acción sobre una entidad
    ///
    /// **Flujo de verificación:**
    /// 1. Verificar que el usuario existe
    /// 2. Obtener rol del usuario desde Firestore (con caché)
    /// 3. Si es Programador → permitir TODO
    /// 4. Buscar policy específica para la entidad
    /// 5. Verificar el permiso concreto (create/read/update/delete)
    ///
    /// - Parameters:
    ///   - action: Acción a verificar (create, read, update, delete)
    ///   - entity: Entidad sobre la que se realiza la acción (kit, user, kitItem, etc.)
    ///   - user: Usuario que intenta realizar la acción
    /// - Returns: `true` si tiene permiso, `false` si no
    ///
    /// - Example:
    /// ```swift
    /// let canCreateKit = await AuthorizationServiceFS.allowed(.create, on: .kit, for: currentUser)
    /// if canCreateKit {
    ///     // Crear kit...
    /// }
    /// ```
    public static func allowed(
        _ action: ActionKind,
        on entity: EntityKind,
        for user: UserFS?
    ) async -> Bool {
        // 1. Verificar que el usuario existe
        guard let user = user else {
            return false
        }
        
        // 2. Obtener rol desde Firestore (con caché)
        guard let role = await PolicyService.shared.getRole(id: user.roleId) else {
            return false
        }
        
        // 3. Programador tiene acceso total a TODO
        if role.kind == .programmer {
            return true
        }
        
        // 4. Buscar policy específica para esta entidad
        guard let policy = await PolicyService.shared.getPolicy(
            roleId: role.id,
            entity: entity
        ) else {
            return false
        }
        
        // 5. Verificar el permiso específico solicitado
        switch action {
        case .create:
            return policy.canCreate
        case .read:
            return policy.canRead
        case .update:
            return policy.canUpdate
        case .delete:
            return policy.canDelete
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Verifica si el usuario puede crear una entidad
    public static func canCreate(_ entity: EntityKind, user: UserFS?) async -> Bool {
        await allowed(.create, on: entity, for: user)
    }
    
    /// Verifica si el usuario puede leer una entidad
    public static func canRead(_ entity: EntityKind, user: UserFS?) async -> Bool {
        await allowed(.read, on: entity, for: user)
    }
    
    /// Verifica si el usuario puede actualizar una entidad
    public static func canUpdate(_ entity: EntityKind, user: UserFS?) async -> Bool {
        await allowed(.update, on: entity, for: user)
    }
    
    /// Verifica si el usuario puede eliminar una entidad
    public static func canDelete(_ entity: EntityKind, user: UserFS?) async -> Bool {
        await allowed(.delete, on: entity, for: user)
    }
    
    // MARK: - Batch Permission Checks
    
    /// Obtiene todos los permisos de un usuario para una entidad específica
    /// - Parameters:
    ///   - entity: Entidad a verificar
    ///   - user: Usuario
    /// - Returns: Tupla con los 4 permisos (create, read, update, delete)
    public static func permissions(
        for entity: EntityKind,
        user: UserFS?
    ) async -> (canCreate: Bool, canRead: Bool, canUpdate: Bool, canDelete: Bool) {
        guard let user = user else {
            return (false, false, false, false)
        }
        
        // Obtener rol
        guard let role = await PolicyService.shared.getRole(id: user.roleId) else {
            return (false, false, false, false)
        }
        
        // Programador tiene todo
        if role.kind == .programmer {
            return (true, true, true, true)
        }
        
        // Obtener policy
        guard let policy = await PolicyService.shared.getPolicy(roleId: role.id, entity: entity) else {
            return (false, false, false, false)
        }
        
        return (
            policy.canCreate,
            policy.canRead,
            policy.canUpdate,
            policy.canDelete
        )
    }
    
    // MARK: - Role-Specific Checks
    
    /// Verifica si el usuario es Programador
    public static func isProgrammer(_ user: UserFS?) async -> Bool {
        guard let roleId = user?.roleId else { return false }
        guard let role = await PolicyService.shared.getRole(id: roleId) else { return false }
        return role.kind == .programmer
    }
    
    /// Verifica si el usuario es Logística
    public static func isLogistics(_ user: UserFS?) async -> Bool {
        guard let roleId = user?.roleId else { return false }
        guard let role = await PolicyService.shared.getRole(id: roleId) else { return false }
        return role.kind == .logistics
    }
    
    /// Verifica si el usuario es Sanitario
    public static func isSanitary(_ user: UserFS?) async -> Bool {
        guard let roleId = user?.roleId else { return false }
        guard let role = await PolicyService.shared.getRole(id: roleId) else { return false }
        return role.kind == .sanitary
    }
    
    // MARK: - Special Business Rules
    
    /// Verifica si el usuario puede editar umbrales (min/max)
    /// **Regla de negocio:** Solo Programador y Logística
    public static func canEditThresholds(_ user: UserFS?) async -> Bool {
        guard let roleId = user?.roleId else { return false }
        guard let role = await PolicyService.shared.getRole(id: roleId) else { return false }
        
        return role.kind == .programmer || role.kind == .logistics
    }
    
    /// Verifica si el usuario puede crear kits
    /// **Regla de negocio:** Solo Programador
    public static func canCreateKits(_ user: UserFS?) async -> Bool {
        await canCreate(.kit, user: user)
    }
    
    /// Verifica si el usuario puede actualizar stock (cantidad de KitItem)
    /// **Regla de negocio:** Todos los roles activos pueden actualizar stock
    public static func canUpdateStock(_ user: UserFS?) async -> Bool {
        await canUpdate(.kitItem, user: user)
    }
    
    /// Verifica si el usuario puede gestionar usuarios (crear/eliminar)
    /// **Regla de negocio:** Solo Programador
    public static func canManageUsers(_ user: UserFS?) async -> Bool {
        let canCreate = await canCreate(.user, user: user)
        let canDelete = await canDelete(.user, user: user)
        return canCreate && canDelete
    }
}

// MARK: - UIPermissions Compatibility

/// Versión Firebase de UIPermissions para mantener compatibilidad con las vistas
/// Estas son versiones async de los métodos originales
@MainActor
public enum UIPermissionsFS {
    
    /// Verifica si el usuario puede crear kits
    public static func canCreateKits(_ user: UserFS?) async -> Bool {
        await AuthorizationServiceFS.canCreateKits(user)
    }
    
    /// Verifica si el usuario puede editar umbrales
    public static func canEditThresholds(_ user: UserFS?) async -> Bool {
        await AuthorizationServiceFS.canEditThresholds(user)
    }
    
    /// Obtiene los permisos de gestión de usuarios
    public static func userMgmt(_ user: UserFS?) async -> (create: Bool, read: Bool, update: Bool, delete: Bool) {
        let perms = await AuthorizationServiceFS.permissions(for: .user, user: user)
        return (perms.canCreate, perms.canRead, perms.canUpdate, perms.canDelete)
    }
    
    /// Obtiene los permisos para una entidad específica
    public static func permissions(for entity: EntityKind, user: UserFS?) async -> (create: Bool, read: Bool, update: Bool, delete: Bool) {
        let perms = await AuthorizationServiceFS.permissions(for: entity, user: user)
        return (perms.canCreate, perms.canRead, perms.canUpdate, perms.canDelete)
    }
}

// MARK: - Error Types

/// Errores de autorización
public enum AuthorizationError: LocalizedError {
    case unauthorized(action: ActionKind, entity: EntityKind)
    case userNotAuthenticated
    case roleNotFound
    case policyNotFound
    
    public var errorDescription: String? {
        switch self {
        case .unauthorized(let action, let entity):
            return "No tienes permisos para \(action.rawValue) en \(entity.rawValue)"
        case .userNotAuthenticated:
            return "Usuario no autenticado"
        case .roleNotFound:
            return "Rol de usuario no encontrado"
        case .policyNotFound:
            return "Política de permisos no encontrada"
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension AuthorizationServiceFS {
    /// Imprime todos los permisos de un usuario para debugging
    public static func printPermissions(for user: UserFS?) async {
        guard let user = user else {
            print("❌ Usuario no existe")
            return
        }
        
        print("\n📋 Permisos de \(user.username) (@\(user.fullName)):")
        
        guard let role = await PolicyService.shared.getRole(id: user.roleId) else {
            print("   ❌ Rol no encontrado")
            return
        }
        
        print("   Rol: \(role.displayName) (\(role.kind.rawValue))")
        
        if role.kind == .programmer {
            print("   ✅ ACCESO TOTAL (Programador)")
            return
        }
        
        print("\n   Permisos por entidad:")
        for entity in EntityKind.allCases {
            let perms = await permissions(for: entity, user: user)
            let c = perms.canCreate ? "✅" : "❌"
            let r = perms.canRead ? "✅" : "❌"
            let u = perms.canUpdate ? "✅" : "❌"
            let d = perms.canDelete ? "✅" : "❌"
            print("   \(entity.rawValue.padding(toLength: 15, withPad: " ", startingAt: 0)) C:\(c) R:\(r) U:\(u) D:\(d)")
        }
        print()
    }
    
    /// Verifica y muestra si un usuario puede realizar una acción específica
    public static func checkPermission(
        _ action: ActionKind,
        on entity: EntityKind,
        for user: UserFS?,
        verbose: Bool = true
    ) async -> Bool {
        let hasPermission = await allowed(action, on: entity, for: user)
        
        if verbose {
            let emoji = hasPermission ? "✅" : "❌"
            let username = user?.username ?? "nil"
            print("\(emoji) \(username) \(action.rawValue) \(entity.rawValue): \(hasPermission)")
        }
        
        return hasPermission
    }
}
#endif

// MARK: - Migration Helper

/// Helper para migrar de AuthorizationService (SwiftData) a AuthorizationServiceFS (Firebase)
/// Útil durante el período de transición
#if DEBUG
extension AuthorizationServiceFS {
    /// Compara los resultados entre SwiftData y Firebase para verificar consistencia
    public static func validateMigration(
        action: ActionKind,
        entity: EntityKind,
        swiftDataUser: User?,
        firebaseUser: UserFS?
    ) async -> Bool {
        let swiftDataResult = AuthorizationService.allowed(action, on: entity, for: swiftDataUser)
        let firebaseResult = await AuthorizationServiceFS.allowed(action, on: entity, for: firebaseUser)
        
        if swiftDataResult != firebaseResult {
            print("⚠️ INCONSISTENCIA DETECTADA:")
            print("   Usuario: \(swiftDataUser?.username ?? "nil") / \(firebaseUser?.username ?? "nil")")
            print("   Acción: \(action.rawValue)")
            print("   Entidad: \(entity.rawValue)")
            print("   SwiftData: \(swiftDataResult)")
            print("   Firebase: \(firebaseResult)")
            return false
        }
        
        return true
    }
}
#endif
