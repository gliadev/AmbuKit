//
//  AuthorizationServiceFS.swift
//  AmbuKit
//
//  Created by Adolfo on 15/11/25.
//
//  TAREA 16.1: Actualizado para permitir que Logística cree kits y vehículos
//  FIX: Verificación directa de roleId para evitar problemas con PolicyService
//

import Foundation

/// Servicio de autorización para Firebase
/// Réplica exacta de AuthorizationService pero adaptado para UserFS y consultas async a Firestore
///
/// **Lógica de permisos (ACTUALIZADA en TAREA 16.1):**
/// - Programador → Acceso total a todo
/// - Logística → Puede crear kits y vehículos, NO crear/eliminar usuarios
/// - Sanitario → Solo lectura + actualizar stock (KitItem)
@MainActor
public enum AuthorizationServiceFS {
    
    // MARK: - Role ID Constants
    
    /// IDs de roles conocidos en Firestore
    private static let programmerRoleIds = ["role_programmer", "programmer"]
    private static let logisticsRoleIds = ["role_logistics", "logistics"]
    private static let sanitaryRoleIds = ["role_sanitary", "sanitary"]
    
    // MARK: - Quick Role Checks (Direct)
    
    /// Verifica si el usuario es Programador por su roleId directamente
    /// Esta verificación es directa y no depende de PolicyService
    private static func isProgrammerDirect(_ user: UserFS?) -> Bool {
        guard let roleId = user?.roleId else { return false }
        return programmerRoleIds.contains(roleId.lowercased()) ||
               roleId.lowercased().contains("programmer")
    }
    
    /// Verifica si el usuario es Logística por su roleId directamente
    private static func isLogisticsDirect(_ user: UserFS?) -> Bool {
        guard let roleId = user?.roleId else { return false }
        return logisticsRoleIds.contains(roleId.lowercased()) ||
               roleId.lowercased().contains("logistics")
    }
    
    /// Verifica si el usuario es Sanitario por su roleId directamente
    private static func isSanitaryDirect(_ user: UserFS?) -> Bool {
        guard let roleId = user?.roleId else { return false }
        return sanitaryRoleIds.contains(roleId.lowercased()) ||
               roleId.lowercased().contains("sanitary")
    }
    
    // MARK: - Main Authorization Method
    
    /// Verifica si un usuario tiene permiso para realizar una acción sobre una entidad
    ///
    /// **Flujo de verificación (OPTIMIZADO):**
    /// 1. Verificar que el usuario existe
    /// 2. ✅ NUEVO: Verificación directa de roleId para Programador (siempre permitir)
    /// 3. Obtener rol del usuario desde Firestore (con caché)
    /// 4. Buscar policy específica para la entidad
    /// 5. Verificar el permiso concreto (create/read/update/delete)
    ///
    /// - Parameters:
    ///   - action: Acción a verificar (create, read, update, delete)
    ///   - entity: Entidad sobre la que se realiza la acción (kit, user, kitItem, etc.)
    ///   - user: Usuario que intenta realizar la acción
    /// - Returns: `true` si tiene permiso, `false` si no
    public static func allowed(
        _ action: ActionKind,
        on entity: EntityKind,
        for user: UserFS?
    ) async -> Bool {
        // 1. Verificar que el usuario existe
        guard let user = user else {
            print("⚠️ AuthorizationServiceFS: Usuario nil")
            return false
        }
        
        // 2. ✅ NUEVO: Verificación directa para Programador - SIEMPRE permitir todo
        if isProgrammerDirect(user) {
            print("✅ AuthorizationServiceFS: Programador detectado (roleId: \(user.roleId)) - Acceso total")
            return true
        }
        
        // 3. Para otros roles, intentar obtener desde PolicyService
        if let role = await PolicyService.shared.getRole(id: user.roleId) {
            // Doble verificación por si acaso
            if role.kind == .programmer {
                print("✅ AuthorizationServiceFS: Programador por PolicyService")
                return true
            }
            
            // 4. Buscar policy específica para esta entidad
            if let policy = await PolicyService.shared.getPolicy(roleId: role.id, entity: entity) {
                switch action {
                case .create: return policy.canCreate
                case .read: return policy.canRead
                case .update: return policy.canUpdate
                case .delete: return policy.canDelete
                }
            }
        }
        
        // 5. ✅ NUEVO: Fallback basado en roleId directo para Logística y Sanitario
        return fallbackPermission(action: action, entity: entity, user: user)
    }
    
    // MARK: - Fallback Permissions
    
    /// Permisos de fallback basados en el roleId cuando PolicyService falla
    private static func fallbackPermission(action: ActionKind, entity: EntityKind, user: UserFS) -> Bool {
        // Logística: CRUD en kits, vehicles, bases, kitItems, catalogItems, categories, units | Solo lectura en users/audit
        if isLogisticsDirect(user) {
            switch entity {
            case .kit, .vehicle, .base, .kitItem, .catalogItem, .category, .unit:
                return true  // CRUD completo
            case .user, .audit:
                return action == .read  // Solo lectura
            }
        }
        
        // Sanitario: Lectura + actualizar stock en kitItems
        if isSanitaryDirect(user) {
            switch entity {
            case .kitItem:
                return action == .read || action == .update  // Leer y actualizar stock
            case .kit, .vehicle, .base, .catalogItem, .category, .unit, .user, .audit:
                return action == .read  // Solo lectura en todo lo demás
            }
        }
        
        // Por defecto, solo lectura
        print("⚠️ AuthorizationServiceFS: Rol desconocido '\(user.roleId)' - Solo lectura")
        return action == .read
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
    public static func permissions(
        for entity: EntityKind,
        user: UserFS?
    ) async -> (canCreate: Bool, canRead: Bool, canUpdate: Bool, canDelete: Bool) {
        guard let user = user else {
            return (false, false, false, false)
        }
        
        // ✅ OPTIMIZADO: Programador tiene todo
        if isProgrammerDirect(user) {
            return (true, true, true, true)
        }
        
        // Obtener permisos individualmente (usa el fallback automáticamente)
        async let c = allowed(.create, on: entity, for: user)
        async let r = allowed(.read, on: entity, for: user)
        async let u = allowed(.update, on: entity, for: user)
        async let d = allowed(.delete, on: entity, for: user)
        
        return await (c, r, u, d)
    }
    
    // MARK: - Role-Specific Checks (Public)
    
    /// Verifica si el usuario es Programador
    public static func isProgrammer(_ user: UserFS?) async -> Bool {
        // Verificación directa primero
        if isProgrammerDirect(user) { return true }
        
        // Fallback a PolicyService
        guard let roleId = user?.roleId else { return false }
        guard let role = await PolicyService.shared.getRole(id: roleId) else { return false }
        return role.kind == .programmer
    }
    
    /// Verifica si el usuario es Logística
    public static func isLogistics(_ user: UserFS?) async -> Bool {
        if isLogisticsDirect(user) { return true }
        guard let roleId = user?.roleId else { return false }
        guard let role = await PolicyService.shared.getRole(id: roleId) else { return false }
        return role.kind == .logistics
    }
    
    /// Verifica si el usuario es Sanitario
    public static func isSanitary(_ user: UserFS?) async -> Bool {
        if isSanitaryDirect(user) { return true }
        guard let roleId = user?.roleId else { return false }
        guard let role = await PolicyService.shared.getRole(id: roleId) else { return false }
        return role.kind == .sanitary
    }
    
    // MARK: - Special Business Rules
    
    /// Verifica si el usuario puede editar umbrales (min/max)
    /// **Regla de negocio:** Solo Programador y Logística
    public static func canEditThresholds(_ user: UserFS?) async -> Bool {
        // ✅ Verificación directa
        if isProgrammerDirect(user) || isLogisticsDirect(user) {
            return true
        }
        
        // Fallback a PolicyService
        guard let roleId = user?.roleId else { return false }
        guard let role = await PolicyService.shared.getRole(id: roleId) else { return false }
        return role.kind == .programmer || role.kind == .logistics
    }
    
    /// Verifica si el usuario puede crear kits
    /// **Regla de negocio:** Programador y Logística
    public static func canCreateKits(_ user: UserFS?) async -> Bool {
        if isProgrammerDirect(user) || isLogisticsDirect(user) {
            return true
        }
        guard let roleId = user?.roleId else { return false }
        guard let role = await PolicyService.shared.getRole(id: roleId) else { return false }
        return role.kind == .programmer || role.kind == .logistics
    }
    
    /// Verifica si el usuario puede crear vehículos
    /// **Regla de negocio:** Programador y Logística
    public static func canCreateVehicles(_ user: UserFS?) async -> Bool {
        if isProgrammerDirect(user) || isLogisticsDirect(user) {
            return true
        }
        guard let roleId = user?.roleId else { return false }
        guard let role = await PolicyService.shared.getRole(id: roleId) else { return false }
        return role.kind == .programmer || role.kind == .logistics
    }
    
    /// Verifica si el usuario puede actualizar stock (cantidad de KitItem)
    /// **Regla de negocio:** Todos los roles activos pueden actualizar stock
    public static func canUpdateStock(_ user: UserFS?) async -> Bool {
        await canUpdate(.kitItem, user: user)
    }
    
    /// Verifica si el usuario puede gestionar usuarios (crear/eliminar)
    /// **Regla de negocio:** Solo Programador
    public static func canManageUsers(_ user: UserFS?) async -> Bool {
        // ✅ Solo programador puede gestionar usuarios
        if isProgrammerDirect(user) {
            return true
        }
        return await isProgrammer(user)
    }
}

// MARK: - UIPermissions Compatibility

/// Versión Firebase de UIPermissions para mantener compatibilidad con las vistas
@MainActor
public enum UIPermissionsFS {
    
    /// Verifica si el usuario puede crear kits
    public static func canCreateKits(_ user: UserFS?) async -> Bool {
        await AuthorizationServiceFS.canCreateKits(user)
    }
    
    /// Verifica si el usuario puede crear vehículos
    public static func canCreateVehicles(_ user: UserFS?) async -> Bool {
        await AuthorizationServiceFS.canCreateVehicles(user)
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
        print("   RoleId: \(user.roleId)")
        print("   Es Programador (directo): \(isProgrammerDirect(user))")
        print("   Es Logística (directo): \(isLogisticsDirect(user))")
        print("   Es Sanitario (directo): \(isSanitaryDirect(user))")
        
        if isProgrammerDirect(user) {
            print("   ✅ ACCESO TOTAL (Programador detectado por roleId)")
            return
        }
        
        // Mostrar permisos especiales
        print("\n   Permisos especiales:")
        let canCreateKits = await canCreateKits(user)
        let canCreateVehicles = await canCreateVehicles(user)
        let canEditThresholds = await canEditThresholds(user)
        let canManageUsers = await canManageUsers(user)
        
        print("   - Crear Kits: \(canCreateKits ? "✅" : "❌")")
        print("   - Crear Vehículos: \(canCreateVehicles ? "✅" : "❌")")
        print("   - Editar Umbrales: \(canEditThresholds ? "✅" : "❌")")
        print("   - Gestionar Usuarios: \(canManageUsers ? "✅" : "❌")")
        
        print("\n   Permisos por entidad:")
        for entity in EntityKind.allCases {
            let perms = await permissions(for: entity, user: user)
            let c = perms.canCreate ? "✅" : "❌"
            let r = perms.canRead ? "✅" : "❌"
            let u = perms.canUpdate ? "✅" : "❌"
            let d = perms.canDelete ? "✅" : "❌"
            print("   \(entity.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0)): C:\(c) R:\(r) U:\(u) D:\(d)")
        }
    }
}
#endif
