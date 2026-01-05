//
//  DateValidator.swift
//  AmbuKit
//
//  Created by Adolfo on 31/12/24.
//

import Foundation

/// Validador de fechas, especialmente para caducidades
struct DateValidator {
    
    // MARK: - Expiry Validation
    
    /// Verifica que una fecha de caducidad sea futura
    /// - Parameter date: Fecha a validar (nil es válido - sin caducidad)
    /// - Returns: true si la fecha es futura o nil
    static func isValidExpiry(_ date: Date?) -> Bool {
        guard let date = date else { return true }
        return date > Date()
    }
    
    /// Días hasta caducidad
    /// - Parameter date: Fecha de caducidad
    /// - Returns: Número de días (negativo si ya caducó)
    static func daysUntilExpiry(_ date: Date) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExpiry = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfExpiry)
        return components.day ?? 0
    }
    
    /// Verifica si está próximo a caducar
    /// - Parameters:
    ///   - date: Fecha de caducidad
    ///   - threshold: Días de umbral (default: 30)
    /// - Returns: true si caduca dentro del umbral
    static func isExpiringSoon(_ date: Date, threshold: Int = 30) -> Bool {
        let days = daysUntilExpiry(date)
        return days > 0 && days <= threshold
    }
    
    /// Verifica si ya ha caducado
    /// - Parameter date: Fecha de caducidad
    /// - Returns: true si la fecha es pasada
    static func isExpired(_ date: Date) -> Bool {
        date < Date()
    }
    
    // MARK: - General Date Validation
    
    /// Verifica que una fecha esté en el futuro
    /// - Parameter date: Fecha a validar
    /// - Returns: true si es futura
    static func isFuture(_ date: Date) -> Bool {
        date > Date()
    }
    
    /// Verifica que una fecha esté en el pasado
    /// - Parameter date: Fecha a validar
    /// - Returns: true si es pasada
    static func isPast(_ date: Date) -> Bool {
        date < Date()
    }
    
    /// Verifica si la fecha es hoy
    /// - Parameter date: Fecha a validar
    /// - Returns: true si es hoy
    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    // MARK: - Range Validation
    
    /// Verifica que una fecha esté dentro de un rango
    /// - Parameters:
    ///   - date: Fecha a validar
    ///   - start: Inicio del rango
    ///   - end: Fin del rango
    /// - Returns: true si está dentro del rango
    static func isInRange(_ date: Date, start: Date, end: Date) -> Bool {
        date >= start && date <= end
    }
    
    /// Verifica que una fecha sea posterior a otra
    /// - Parameters:
    ///   - date: Fecha a validar
    ///   - other: Fecha de referencia
    /// - Returns: true si date es posterior a other
    static func isAfter(_ date: Date, other: Date) -> Bool {
        date > other
    }
    
    /// Verifica que una fecha sea anterior a otra
    /// - Parameters:
    ///   - date: Fecha a validar
    ///   - other: Fecha de referencia
    /// - Returns: true si date es anterior a other
    static func isBefore(_ date: Date, other: Date) -> Bool {
        date < other
    }
    
    // MARK: - Error Messages
    
    /// Mensaje de error para fecha de caducidad
    /// - Parameter date: Fecha a validar
    /// - Returns: Mensaje de error o nil si es válida
    static func expiryErrorMessage(for date: Date?) -> String? {
        guard let date = date else { return nil }
        
        if isExpired(date) {
            return "La fecha de caducidad no puede ser pasada"
        }
        
        return nil
    }
    
    // MARK: - Formatting Helpers
    
    /// Texto descriptivo de la caducidad
    /// - Parameter date: Fecha de caducidad
    /// - Returns: Texto descriptivo (ej: "Caduca en 5 días", "Caducado hace 2 días")
    static func expiryDescription(_ date: Date) -> String {
        let days = daysUntilExpiry(date)
        
        if days < 0 {
            return "Caducado hace \(abs(days)) día\(abs(days) == 1 ? "" : "s")"
        } else if days == 0 {
            return "Caduca hoy"
        } else if days == 1 {
            return "Caduca mañana"
        } else if days <= 7 {
            return "Caduca en \(days) días"
        } else if days <= 30 {
            let weeks = days / 7
            return "Caduca en \(weeks) semana\(weeks == 1 ? "" : "s")"
        } else {
            let months = days / 30
            return "Caduca en \(months) mes\(months == 1 ? "" : "es")"
        }
    }
    
    /// Color indicador según proximidad a caducidad
    /// - Parameter date: Fecha de caducidad
    /// - Returns: Nombre del color (para SwiftUI)
    static func expiryColorName(_ date: Date) -> String {
        let days = daysUntilExpiry(date)
        
        if days < 0 {
            return "red" // Caducado
        } else if days <= 7 {
            return "red" // Muy próximo
        } else if days <= 30 {
            return "orange" // Próximo
        } else if days <= 90 {
            return "yellow" // Atención
        } else {
            return "green" // OK
        }
    }
}

// MARK: - Audit Date Validation

extension DateValidator {
    
    /// Verifica si necesita auditoría (última revisión hace más de X días)
    /// - Parameters:
    ///   - lastAudit: Fecha de última auditoría
    ///   - maxDays: Días máximos sin auditoría (default: 30)
    /// - Returns: true si necesita auditoría
    static func needsAudit(lastAudit: Date?, maxDays: Int = 30) -> Bool {
        guard let lastAudit = lastAudit else {
            return true // Nunca auditado
        }
        
        let daysSinceAudit = abs(daysUntilExpiry(lastAudit)) // Reutilizamos pero invertido
        return daysSinceAudit > maxDays
    }
}
