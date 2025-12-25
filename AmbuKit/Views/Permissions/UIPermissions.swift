//
//  UIPermissions.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//  TAREA 16.1: Actualizado para permitir que Logística cree kits y vehículos
//

import Foundation

/// Permisos de UI para vistas SwiftData (versión síncrona)
/// Para vistas Firebase, usar UIPermissionsFS (versión async)
///
/// **Cambios TAREA 16.1:**
/// - `canCreateKits`: Ahora permite Programador + Logística
/// - `canCreateVehicles`: NUEVO - Programador + Logística
enum UIPermissions {
    
    // MARK: - Kit Permissions
    
    /// Verifica si el usuario puede crear kits
    /// **ACTUALIZADO TAREA 16.1:** Programador + Logística pueden crear kits
    /// - ANTES: Solo Programador (via AuthorizationService.allowed)
    /// - AHORA: Programador + Logística
    static func canCreateKits(_ user: User?) -> Bool {
        guard let kind = user?.role?.kind else { return false }
        return kind == .programmer || kind == .logistics
    }
    
    // MARK: - Vehicle Permissions
    
    /// Verifica si el usuario puede crear vehículos
    /// **NUEVO TAREA 16.1:** Programador + Logística pueden crear vehículos
    static func canCreateVehicles(_ user: User?) -> Bool {
        guard let kind = user?.role?.kind else { return false }
        return kind == .programmer || kind == .logistics
    }
    
    // MARK: - Threshold Permissions
    
    /// Verifica si el usuario puede editar umbrales (min/max)
    /// **Regla de negocio:** Programador + Logística
    static func canEditThresholds(_ user: User?) -> Bool {
        guard let kind = user?.role?.kind else { return false }
        return kind == .programmer || kind == .logistics
    }
    
    // MARK: - User Management Permissions
    
    /// Obtiene los permisos de gestión de usuarios
    /// **Regla de negocio:** Solo Programador tiene acceso completo
    static func userMgmt(_ user: User?) -> (create: Bool, read: Bool, update: Bool, delete: Bool) {
        (
            AuthorizationService.allowed(.create, on: .user, for: user),
            AuthorizationService.allowed(.read, on: .user, for: user),
            AuthorizationService.allowed(.update, on: .user, for: user),
            AuthorizationService.allowed(.delete, on: .user, for: user)
        )
    }
    
    // MARK: - Admin Access
    
    /// Verifica si el usuario puede acceder al tab de Administración
    /// **ACTUALIZADO TAREA 16.1:** Considera los nuevos permisos
    static func canAccessAdmin(_ user: User?) -> Bool {
        let caps = userMgmt(user)
        return canCreateKits(user)
            || canCreateVehicles(user)
            || canEditThresholds(user)
            || caps.read
            || caps.update
            || caps.delete
    }
}

// MARK: - Resumen de Permisos por Rol
/*
 ┌─────────────────────┬─────────────┬───────────┬───────────┐
 │ Permiso             │ Programador │ Logística │ Sanitario │
 ├─────────────────────┼─────────────┼───────────┼───────────┤
 │ Crear Kits          │     ✅      │    ✅     │    ❌     │
 │ Crear Vehículos     │     ✅      │    ✅     │    ❌     │
 │ Editar Umbrales     │     ✅      │    ✅     │    ❌     │
 │ Gestionar Usuarios  │     ✅      │    ❌     │    ❌     │
 │ Actualizar Stock    │     ✅      │    ✅     │    ✅     │
 │ Ver Inventario      │     ✅      │    ✅     │    ✅     │
 │ Acceso Admin Tab    │     ✅      │    ✅     │    ❌     │
 └─────────────────────┴─────────────┴───────────┴───────────┘
 */
