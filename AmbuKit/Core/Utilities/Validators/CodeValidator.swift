//
//  CodeValidator.swift
//  AmbuKit
//
//  Created by Adolfo on 31/12/24.
//

import Foundation

/// Validador de códigos (kits, vehículos, bases, etc.)
struct CodeValidator {
    
    // MARK: - Configuration
    
    /// Longitud mínima de código
    static let minLength = 3
    
    /// Longitud máxima de código
    static let maxLength = 20
    
    // MARK: - Validation
    
    /// Verifica que un código sea válido
    /// - Parameter code: Código a validar
    /// - Returns: true si el código es válido
    static func isValid(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // No vacío
        guard !trimmed.isEmpty else { return false }
        
        // Longitud correcta
        guard trimmed.count >= minLength && trimmed.count <= maxLength else { return false }
        
        // Solo caracteres alfanuméricos y guiones
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard trimmed.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else { return false }
        
        return true
    }
    
    /// Normaliza un código (uppercase, sin espacios)
    /// - Parameter code: Código a normalizar
    /// - Returns: Código normalizado
    static func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "-")
    }
    
    /// Mensaje de error si el código no es válido
    /// - Parameter code: Código a validar
    /// - Returns: Mensaje de error o nil si es válido
    static func errorMessage(for code: String) -> String? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "El código no puede estar vacío"
        }
        
        if trimmed.count < minLength {
            return "El código debe tener al menos \(minLength) caracteres"
        }
        
        if trimmed.count > maxLength {
            return "El código no puede tener más de \(maxLength) caracteres"
        }
        
        // Verificar caracteres válidos
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if !trimmed.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) {
            return "El código solo puede contener letras, números y guiones"
        }
        
        return nil
    }
}

// MARK: - Name Validator

/// Validador de nombres (kits, vehículos, bases, etc.)
struct NameValidator {
    
    // MARK: - Configuration
    
    /// Longitud mínima de nombre
    static let minLength = 2
    
    /// Longitud máxima de nombre
    static let maxLength = 100
    
    // MARK: - Validation
    
    /// Verifica que un nombre sea válido
    /// - Parameter name: Nombre a validar
    /// - Returns: true si el nombre es válido
    static func isValid(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // No vacío
        guard !trimmed.isEmpty else { return false }
        
        // Longitud correcta
        guard trimmed.count >= minLength && trimmed.count <= maxLength else { return false }
        
        return true
    }
    
    /// Normaliza un nombre (trim espacios, capitaliza primera letra)
    /// - Parameter name: Nombre a normalizar
    /// - Returns: Nombre normalizado
    static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Mensaje de error si el nombre no es válido
    /// - Parameter name: Nombre a validar
    /// - Returns: Mensaje de error o nil si es válido
    static func errorMessage(for name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "El nombre no puede estar vacío"
        }
        
        if trimmed.count < minLength {
            return "El nombre debe tener al menos \(minLength) caracteres"
        }
        
        if trimmed.count > maxLength {
            return "El nombre no puede tener más de \(maxLength) caracteres"
        }
        
        return nil
    }
}

// MARK: - Plate Validator (Matrículas)

/// Validador de matrículas de vehículos
struct PlateValidator {
    
    /// Verifica que una matrícula sea válida (formato español)
    /// - Parameter plate: Matrícula a validar
    /// - Returns: true si la matrícula es válida
    static func isValid(_ plate: String) -> Bool {
        let normalized = normalize(plate)
        
        // Formato nuevo español: 4 números + 3 letras (ej: 1234 ABC)
        let newFormat = "^[0-9]{4}[A-Z]{3}$"
        let newPredicate = NSPredicate(format: "SELF MATCHES %@", newFormat)
        
        // Formato antiguo español: letras + 4 números + letras (ej: M-1234-AB)
        let oldFormat = "^[A-Z]{1,2}[0-9]{4}[A-Z]{2}$"
        let oldPredicate = NSPredicate(format: "SELF MATCHES %@", oldFormat)
        
        return newPredicate.evaluate(with: normalized) || oldPredicate.evaluate(with: normalized)
    }
    
    /// Normaliza una matrícula (uppercase, sin espacios ni guiones)
    /// - Parameter plate: Matrícula a normalizar
    /// - Returns: Matrícula normalizada
    static func normalize(_ plate: String) -> String {
        plate.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
    
    /// Formatea una matrícula para mostrar (con espacio)
    /// - Parameter plate: Matrícula normalizada
    /// - Returns: Matrícula formateada (ej: "1234 ABC")
    static func format(_ plate: String) -> String {
        let normalized = normalize(plate)
        
        // Si es formato nuevo (4 números + 3 letras)
        if normalized.count == 7 {
            let numbers = normalized.prefix(4)
            let letters = normalized.suffix(3)
            return "\(numbers) \(letters)"
        }
        
        return normalized
    }
    
    /// Mensaje de error si la matrícula no es válida
    /// - Parameter plate: Matrícula a validar
    /// - Returns: Mensaje de error o nil si es válida
    static func errorMessage(for plate: String) -> String? {
        let trimmed = plate.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "La matrícula no puede estar vacía"
        }
        
        if !isValid(trimmed) {
            return "Formato de matrícula inválido (ej: 1234 ABC)"
        }
        
        return nil
    }
}
