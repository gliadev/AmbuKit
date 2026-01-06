//
//  EmailValidator.swift
//  AmbuKit
//
//  Created by Adolfo on 31/12/24.
//

import Foundation

/// Validador de direcciones de email
struct EmailValidator {
    
    /// Verifica si un email tiene formato válido
    /// - Parameter email: Email a validar
    /// - Returns: true si el formato es válido
    static func isValid(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        // Regex para validación de email
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: trimmed)
    }
    
    /// Normaliza un email (lowercase, sin espacios)
    /// - Parameter email: Email a normalizar
    /// - Returns: Email normalizado
    static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    /// Mensaje de error si el email no es válido
    /// - Parameter email: Email a validar
    /// - Returns: Mensaje de error o nil si es válido
    static func errorMessage(for email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "El email no puede estar vacío"
        }
        
        if !trimmed.contains("@") {
            return "El email debe contener @"
        }
        
        if !isValid(trimmed) {
            return "Formato de email inválido"
        }
        
        return nil
    }
}
