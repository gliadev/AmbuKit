//
//  Validators.swift
//  AmbuKit
//
//  Created by Adolfo on 5/1/26.
//  Validaciones reutilizables para formularios y datos
//  Compatible con Swift 6 strict concurrency
//

import Foundation

/// Validaciones reutilizables para la aplicación
///
/// Uso:
/// ```swift
/// // Email
/// Validators.isValidEmail("test@example.com")  // true
///
/// // Cantidad
/// Validators.isValidQuantity(5, min: 0, max: 100)  // true
///
/// // Fecha de caducidad
/// Validators.isValidExpirationDate(futureDate)  // true
///
/// // Código
/// Validators.isValidCode("KIT-001")  // true
/// ```
enum Validators {
    
    // MARK: - Email Validation
    
    /// Valida formato de email
    /// - Parameter email: Email a validar
    /// - Returns: true si el formato es válido
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        
        // Regex para validar email
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: trimmed)
    }
    
    /// Resultado de validación de email con mensaje
    static func validateEmail(_ email: String) -> ValidationResult {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty {
            return .invalid("El email no puede estar vacío")
        }
        
        if !trimmed.contains("@") {
            return .invalid("El email debe contener @")
        }
        
        if !isValidEmail(trimmed) {
            return .invalid("Formato de email inválido")
        }
        
        return .valid
    }
    
    // MARK: - Quantity Validation
    
    /// Valida que una cantidad esté en rango
    /// - Parameters:
    ///   - quantity: Cantidad a validar
    ///   - min: Mínimo permitido (default: 0)
    ///   - max: Máximo permitido (default: 99999)
    /// - Returns: true si está en rango
    static func isValidQuantity(_ quantity: Int, min: Int = 0, max: Int = 99999) -> Bool {
        quantity >= min && quantity <= max
    }
    
    /// Valida cantidad con mensaje de error
    static func validateQuantity(_ quantity: Int, min: Int = 0, max: Int = 99999, fieldName: String = "Cantidad") -> ValidationResult {
        if quantity < min {
            return .invalid("\(fieldName) no puede ser menor que \(min)")
        }
        
        if quantity > max {
            return .invalid("\(fieldName) no puede ser mayor que \(max)")
        }
        
        return .valid
    }
    
    /// Valida cantidad decimal
    static func isValidQuantity(_ quantity: Double, min: Double = 0, max: Double = 99999) -> Bool {
        quantity >= min && quantity <= max && !quantity.isNaN && !quantity.isInfinite
    }
    
    // MARK: - Date Validation
    
    /// Valida que una fecha de caducidad no haya pasado
    /// - Parameter date: Fecha a validar
    /// - Returns: true si la fecha es futura o hoy
    static func isValidExpirationDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expirationDay = calendar.startOfDay(for: date)
        return expirationDay >= today
    }
    
    /// Valida fecha de caducidad con mensaje
    static func validateExpirationDate(_ date: Date) -> ValidationResult {
        if !isValidExpirationDate(date) {
            return .invalid("La fecha de caducidad no puede ser anterior a hoy")
        }
        return .valid
    }
    
    /// Valida que una fecha esté en un rango
    static func isValidDate(_ date: Date, from: Date? = nil, to: Date? = nil) -> Bool {
        if let from = from, date < from {
            return false
        }
        if let to = to, date > to {
            return false
        }
        return true
    }
    
    /// Valida que una fecha no sea futura (ej: fecha de nacimiento)
    static func isNotFutureDate(_ date: Date) -> Bool {
        date <= Date()
    }
    
    // MARK: - Code Validation
    
    /// Valida formato de código (alfanumérico con guiones)
    /// - Parameters:
    ///   - code: Código a validar
    ///   - minLength: Longitud mínima (default: 2)
    ///   - maxLength: Longitud máxima (default: 20)
    /// - Returns: true si el formato es válido
    static func isValidCode(_ code: String, minLength: Int = 2, maxLength: Int = 20) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= minLength && trimmed.count <= maxLength else { return false }
        
        // Solo letras, números, guiones y guiones bajos
        let codeRegex = #"^[A-Za-z0-9_-]+$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", codeRegex)
        return predicate.evaluate(with: trimmed)
    }
    
    /// Valida código con mensaje
    static func validateCode(_ code: String, fieldName: String = "Código", minLength: Int = 2, maxLength: Int = 20) -> ValidationResult {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty {
            return .invalid("\(fieldName) no puede estar vacío")
        }
        
        if trimmed.count < minLength {
            return .invalid("\(fieldName) debe tener al menos \(minLength) caracteres")
        }
        
        if trimmed.count > maxLength {
            return .invalid("\(fieldName) no puede tener más de \(maxLength) caracteres")
        }
        
        if !isValidCode(trimmed, minLength: minLength, maxLength: maxLength) {
            return .invalid("\(fieldName) solo puede contener letras, números, guiones y guiones bajos")
        }
        
        return .valid
    }
    
    // MARK: - Text Validation
    
    /// Valida que un texto no esté vacío
    static func isNotEmpty(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Valida longitud de texto
    static func isValidLength(_ text: String, min: Int = 1, max: Int = 500) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= min && trimmed.count <= max
    }
    
    /// Valida texto con mensaje
    static func validateText(_ text: String, fieldName: String = "Campo", minLength: Int = 1, maxLength: Int = 500) -> ValidationResult {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty && minLength > 0 {
            return .invalid("\(fieldName) no puede estar vacío")
        }
        
        if trimmed.count < minLength {
            return .invalid("\(fieldName) debe tener al menos \(minLength) caracteres")
        }
        
        if trimmed.count > maxLength {
            return .invalid("\(fieldName) no puede tener más de \(maxLength) caracteres")
        }
        
        return .valid
    }
    
    // MARK: - Phone Validation
    
    /// Valida formato de teléfono español
    static func isValidSpanishPhone(_ phone: String) -> Bool {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "+34", with: "")
        
        // 9 dígitos, empieza por 6, 7, 8 o 9
        let phoneRegex = #"^[6-9]\d{8}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return predicate.evaluate(with: cleaned)
    }
    
    // MARK: - Password Validation
    
    /// Valida fortaleza de contraseña
    /// - Parameter password: Contraseña a validar
    /// - Returns: true si cumple requisitos mínimos (8+ caracteres, 1 mayúscula, 1 número)
    static func isValidPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        
        return hasUppercase && hasNumber
    }
    
    /// Valida contraseña con mensaje detallado
    static func validatePassword(_ password: String) -> ValidationResult {
        if password.count < 8 {
            return .invalid("La contraseña debe tener al menos 8 caracteres")
        }
        
        if password.range(of: "[A-Z]", options: .regularExpression) == nil {
            return .invalid("La contraseña debe contener al menos una mayúscula")
        }
        
        if password.range(of: "[0-9]", options: .regularExpression) == nil {
            return .invalid("La contraseña debe contener al menos un número")
        }
        
        return .valid
    }
    
    // MARK: - Username Validation
    
    /// Valida formato de nombre de usuario
    static func isValidUsername(_ username: String) -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 3 && trimmed.count <= 20 else { return false }
        
        // Solo letras minúsculas, números y guiones bajos
        let usernameRegex = #"^[a-z0-9_]+$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return predicate.evaluate(with: trimmed)
    }
    
    /// Valida username con mensaje
    static func validateUsername(_ username: String) -> ValidationResult {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty {
            return .invalid("El nombre de usuario no puede estar vacío")
        }
        
        if trimmed.count < 3 {
            return .invalid("El nombre de usuario debe tener al menos 3 caracteres")
        }
        
        if trimmed.count > 20 {
            return .invalid("El nombre de usuario no puede tener más de 20 caracteres")
        }
        
        if !isValidUsername(trimmed) {
            return .invalid("El nombre de usuario solo puede contener letras minúsculas, números y guiones bajos")
        }
        
        return .valid
    }
}

// MARK: - Validation Result

/// Resultado de una validación
enum ValidationResult: Equatable {
    case valid
    case invalid(String)
    
    /// Si la validación es exitosa
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
    
    /// Mensaje de error (nil si es válido)
    var errorMessage: String? {
        if case .invalid(let message) = self { return message }
        return nil
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

extension Validators {
    
    /// Crea un binding con validación para TextField
    /// - Parameters:
    ///   - text: Binding al texto
    ///   - validation: Función de validación
    ///   - errorMessage: Binding al mensaje de error
    /// - Returns: Binding modificado que valida al cambiar
    static func validated(
        _ text: Binding<String>,
        using validation: @escaping (String) -> ValidationResult,
        errorMessage: Binding<String?>
    ) -> Binding<String> {
        Binding(
            get: { text.wrappedValue },
            set: { newValue in
                text.wrappedValue = newValue
                errorMessage.wrappedValue = validation(newValue).errorMessage
            }
        )
    }
}

// MARK: - Form Validation Helper

/// Helper para validar múltiples campos de un formulario
struct FormValidator {
    
    private var validations: [(String, ValidationResult)] = []
    
    /// Añade una validación
    mutating func add(_ fieldName: String, _ result: ValidationResult) {
        validations.append((fieldName, result))
    }
    
    /// Verifica si todo el formulario es válido
    var isValid: Bool {
        validations.allSatisfy { $0.1.isValid }
    }
    
    /// Primer error encontrado (nil si todo es válido)
    var firstError: String? {
        validations.first(where: { !$0.1.isValid })?.1.errorMessage
    }
    
    /// Todos los errores encontrados
    var allErrors: [String] {
        validations.compactMap { $0.1.errorMessage }
    }
    
    /// Errores por campo
    var errorsByField: [String: String] {
        var result: [String: String] = [:]
        for (field, validation) in validations {
            if let error = validation.errorMessage {
                result[field] = error
            }
        }
        return result
    }
}
