//
//  QuantityValidator.swift
//  AmbuKit
//
//  Created by Adolfo on 31/12/24.
//

import Foundation

/// Validador de cantidades numéricas
struct QuantityValidator {
    
    /// Verifica si una cantidad es válida
    /// - Parameters:
    ///   - quantity: Cantidad a validar
    ///   - min: Valor mínimo permitido (opcional)
    ///   - max: Valor máximo permitido (opcional)
    /// - Returns: true si la cantidad es válida
    static func isValid(_ quantity: Double, min: Double? = nil, max: Double? = nil) -> Bool {
        // Debe ser >= 0
        guard quantity >= 0 else { return false }
        
        // No puede ser infinito o NaN
        guard quantity.isFinite else { return false }
        
        // Verificar mínimo
        if let min = min, quantity < min {
            return false
        }
        
        // Verificar máximo
        if let max = max, quantity > max {
            return false
        }
        
        return true
    }
    
    /// Verifica si una cantidad entera es válida
    /// - Parameters:
    ///   - quantity: Cantidad a validar
    ///   - min: Valor mínimo permitido (opcional)
    ///   - max: Valor máximo permitido (opcional)
    /// - Returns: true si la cantidad es válida
    static func isValid(_ quantity: Int, min: Int? = nil, max: Int? = nil) -> Bool {
        // Debe ser >= 0
        guard quantity >= 0 else { return false }
        
        // Verificar mínimo
        if let min = min, quantity < min {
            return false
        }
        
        // Verificar máximo
        if let max = max, quantity > max {
            return false
        }
        
        return true
    }
    
    /// Mensaje de error si la cantidad no es válida
    /// - Parameters:
    ///   - quantity: Cantidad a validar
    ///   - min: Valor mínimo permitido
    ///   - max: Valor máximo permitido
    /// - Returns: Mensaje de error o nil si es válida
    static func errorMessage(for quantity: Double, min: Double? = nil, max: Double? = nil) -> String? {
        if !quantity.isFinite {
            return "La cantidad debe ser un número válido"
        }
        
        if quantity < 0 {
            return "La cantidad no puede ser negativa"
        }
        
        if let min = min, quantity < min {
            return "La cantidad no puede ser menor que \(formatNumber(min))"
        }
        
        if let max = max, quantity > max {
            return "La cantidad no puede ser mayor que \(formatNumber(max))"
        }
        
        return nil
    }
    
    /// Mensaje de error para cantidades enteras
    static func errorMessage(for quantity: Int, min: Int? = nil, max: Int? = nil) -> String? {
        if quantity < 0 {
            return "La cantidad no puede ser negativa"
        }
        
        if let min = min, quantity < min {
            return "La cantidad no puede ser menor que \(min)"
        }
        
        if let max = max, quantity > max {
            return "La cantidad no puede ser mayor que \(max)"
        }
        
        return nil
    }
    
    // MARK: - Stock Validation
    
    /// Verifica si un stock es válido (entre 0 y máximo si existe)
    /// - Parameters:
    ///   - current: Stock actual
    ///   - minimum: Stock mínimo requerido
    ///   - maximum: Stock máximo permitido (opcional)
    /// - Returns: true si el stock es válido
    static func isValidStock(current: Double, minimum: Double? = nil, maximum: Double? = nil) -> Bool {
        guard current >= 0 else { return false }
        
        if let max = maximum, current > max {
            return false
        }
        
        return true
    }
    
    /// Verifica si el stock está por debajo del mínimo
    /// - Parameters:
    ///   - current: Stock actual
    ///   - minimum: Stock mínimo requerido
    /// - Returns: true si está por debajo del mínimo
    static func isBelowMinimum(current: Double, minimum: Double) -> Bool {
        current < minimum
    }
    
    // MARK: - Helpers
    
    private static func formatNumber(_ number: Double) -> String {
        if number.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", number)
        }
        return String(format: "%.2f", number)
    }
}
