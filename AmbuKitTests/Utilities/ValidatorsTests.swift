//
//  ValidatorsTests.swift
//  AmbuKitTests
//
//  Created by Adolfo on 6/1/26.
//
//  Tests unitarios para Validators
//  Cobertura completa de todas las funciones de validación
//

import XCTest
@testable import AmbuKit

@MainActor
final class ValidatorsTests: XCTestCase {
    
    // MARK: - Email Validation Tests
    
    func testValidEmail_WithCorrectFormat_ReturnsTrue() {
        // Emails válidos
        XCTAssertTrue(Validators.isValidEmail("test@example.com"))
        XCTAssertTrue(Validators.isValidEmail("user.name@domain.org"))
        XCTAssertTrue(Validators.isValidEmail("user+tag@example.co.uk"))
        XCTAssertTrue(Validators.isValidEmail("nombre123@empresa.es"))
        XCTAssertTrue(Validators.isValidEmail("a@b.co"))
    }
    
    func testValidEmail_WithIncorrectFormat_ReturnsFalse() {
        // Emails inválidos
        XCTAssertFalse(Validators.isValidEmail(""))
        XCTAssertFalse(Validators.isValidEmail("   "))
        XCTAssertFalse(Validators.isValidEmail("invalid"))
        XCTAssertFalse(Validators.isValidEmail("no-arroba.com"))
        XCTAssertFalse(Validators.isValidEmail("@nodomain.com"))
        XCTAssertFalse(Validators.isValidEmail("spaces in@email.com"))
        XCTAssertFalse(Validators.isValidEmail("missing@domain"))
    }
    
    func testValidateEmail_ReturnsCorrectValidationResult() {
        // Email válido
        let validResult = Validators.validateEmail("test@example.com")
        XCTAssertTrue(validResult.isValid)
        XCTAssertNil(validResult.errorMessage)
        
        // Email vacío
        let emptyResult = Validators.validateEmail("")
        XCTAssertFalse(emptyResult.isValid)
        XCTAssertEqual(emptyResult.errorMessage, "El email no puede estar vacío")
        
        // Email sin @
        let noAtResult = Validators.validateEmail("invalidemail.com")
        XCTAssertFalse(noAtResult.isValid)
        XCTAssertEqual(noAtResult.errorMessage, "El email debe contener @")
        
        // Email con formato inválido
        let invalidResult = Validators.validateEmail("test@")
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertEqual(invalidResult.errorMessage, "Formato de email inválido")
    }
    
    // MARK: - Quantity Validation Tests
    
    func testValidQuantity_WithinRange_ReturnsTrue() {
        // Cantidades válidas con rango por defecto (0-99999)
        XCTAssertTrue(Validators.isValidQuantity(0))
        XCTAssertTrue(Validators.isValidQuantity(1))
        XCTAssertTrue(Validators.isValidQuantity(100))
        XCTAssertTrue(Validators.isValidQuantity(99999))
    }
    
    func testValidQuantity_OutsideRange_ReturnsFalse() {
        // Cantidades fuera de rango
        XCTAssertFalse(Validators.isValidQuantity(-1))
        XCTAssertFalse(Validators.isValidQuantity(-100))
        XCTAssertFalse(Validators.isValidQuantity(100000))
    }
    
    func testValidQuantity_WithCustomRange_ValidatesCorrectly() {
        // Rango personalizado 1-10
        XCTAssertTrue(Validators.isValidQuantity(1, min: 1, max: 10))
        XCTAssertTrue(Validators.isValidQuantity(5, min: 1, max: 10))
        XCTAssertTrue(Validators.isValidQuantity(10, min: 1, max: 10))
        
        XCTAssertFalse(Validators.isValidQuantity(0, min: 1, max: 10))
        XCTAssertFalse(Validators.isValidQuantity(11, min: 1, max: 10))
    }
    
    func testValidateQuantity_ReturnsCorrectErrorMessages() {
        // Cantidad válida
        let validResult = Validators.validateQuantity(5, min: 0, max: 10)
        XCTAssertTrue(validResult.isValid)
        
        // Menor que mínimo
        let tooLowResult = Validators.validateQuantity(-1, min: 0, max: 10)
        XCTAssertFalse(tooLowResult.isValid)
        XCTAssertEqual(tooLowResult.errorMessage, "Cantidad no puede ser menor que 0")
        
        // Mayor que máximo
        let tooHighResult = Validators.validateQuantity(100, min: 0, max: 10)
        XCTAssertFalse(tooHighResult.isValid)
        XCTAssertEqual(tooHighResult.errorMessage, "Cantidad no puede ser mayor que 10")
        
        // Con nombre de campo personalizado
        let customFieldResult = Validators.validateQuantity(-5, min: 0, max: 100, fieldName: "Stock")
        XCTAssertEqual(customFieldResult.errorMessage, "Stock no puede ser menor que 0")
    }
    
    func testValidQuantity_Double_ValidatesCorrectly() {
        // Cantidades decimales válidas
        XCTAssertTrue(Validators.isValidQuantity(0.0))
        XCTAssertTrue(Validators.isValidQuantity(50.5))
        XCTAssertTrue(Validators.isValidQuantity(99999.0))
        
        // Cantidades decimales inválidas
        XCTAssertFalse(Validators.isValidQuantity(-0.1))
        XCTAssertFalse(Validators.isValidQuantity(Double.nan))
        XCTAssertFalse(Validators.isValidQuantity(Double.infinity))
    }
    
    // MARK: - Date Validation Tests
    
    func testValidExpirationDate_FutureDate_ReturnsTrue() {
        // Fecha futura (mañana)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertTrue(Validators.isValidExpirationDate(tomorrow))
        
        // Fecha futura (próximo año)
        let nextYear = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        XCTAssertTrue(Validators.isValidExpirationDate(nextYear))
    }
    
    func testValidExpirationDate_Today_ReturnsTrue() {
        // Hoy es válido (no ha expirado aún)
        let today = Date()
        XCTAssertTrue(Validators.isValidExpirationDate(today))
    }
    
    func testValidExpirationDate_PastDate_ReturnsFalse() {
        // Fecha pasada (ayer)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertFalse(Validators.isValidExpirationDate(yesterday))
        
        // Fecha pasada (año anterior)
        let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        XCTAssertFalse(Validators.isValidExpirationDate(lastYear))
    }
    
    func testValidateExpirationDate_ReturnsCorrectResult() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        // Fecha válida
        let validResult = Validators.validateExpirationDate(tomorrow)
        XCTAssertTrue(validResult.isValid)
        
        // Fecha pasada
        let expiredResult = Validators.validateExpirationDate(yesterday)
        XCTAssertFalse(expiredResult.isValid)
        XCTAssertEqual(expiredResult.errorMessage, "La fecha de caducidad no puede ser anterior a hoy")
    }
    
    func testIsNotFutureDate_ValidatesCorrectly() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        
        // Fecha pasada es válida (no es futura)
        XCTAssertTrue(Validators.isNotFutureDate(yesterday))
        XCTAssertTrue(Validators.isNotFutureDate(Date()))
        
        // Fecha futura no es válida
        XCTAssertFalse(Validators.isNotFutureDate(tomorrow))
    }
    
    // MARK: - Code Validation Tests
    
    func testValidCode_WithCorrectFormat_ReturnsTrue() {
        // Códigos válidos
        XCTAssertTrue(Validators.isValidCode("KIT-001"))
        XCTAssertTrue(Validators.isValidCode("SVB"))
        XCTAssertTrue(Validators.isValidCode("ABC123"))
        XCTAssertTrue(Validators.isValidCode("kit_emergencia"))
        XCTAssertTrue(Validators.isValidCode("A1"))
    }
    
    func testValidCode_WithIncorrectFormat_ReturnsFalse() {
        // Códigos inválidos
        XCTAssertFalse(Validators.isValidCode(""))  // Vacío
        XCTAssertFalse(Validators.isValidCode("A"))  // Muy corto (min 2)
        XCTAssertFalse(Validators.isValidCode("codigo con espacios"))
        XCTAssertFalse(Validators.isValidCode("código@especial"))
        XCTAssertFalse(Validators.isValidCode("123456789012345678901"))  // Muy largo (max 20)
    }
    
    func testValidateCode_ReturnsCorrectErrorMessages() {
        // Código válido
        let validResult = Validators.validateCode("KIT-001")
        XCTAssertTrue(validResult.isValid)
        
        // Código vacío
        let emptyResult = Validators.validateCode("")
        XCTAssertFalse(emptyResult.isValid)
        XCTAssertEqual(emptyResult.errorMessage, "Código no puede estar vacío")
        
        // Código muy corto
        let shortResult = Validators.validateCode("A")
        XCTAssertFalse(shortResult.isValid)
        XCTAssertEqual(shortResult.errorMessage, "Código debe tener al menos 2 caracteres")
        
        // Código muy largo
        let longCode = String(repeating: "A", count: 25)
        let longResult = Validators.validateCode(longCode)
        XCTAssertFalse(longResult.isValid)
        XCTAssertEqual(longResult.errorMessage, "Código no puede tener más de 20 caracteres")
        
        // Código con caracteres inválidos
        let invalidResult = Validators.validateCode("kit@123")
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertEqual(invalidResult.errorMessage, "Código solo puede contener letras, números, guiones y guiones bajos")
    }
    
    // MARK: - Text Validation Tests
    
    func testIsNotEmpty_ValidatesCorrectly() {
        XCTAssertTrue(Validators.isNotEmpty("texto"))
        XCTAssertTrue(Validators.isNotEmpty("  texto con espacios  "))
        
        XCTAssertFalse(Validators.isNotEmpty(""))
        XCTAssertFalse(Validators.isNotEmpty("   "))
    }
    
    func testIsValidLength_ValidatesCorrectly() {
        // Longitud válida por defecto (1-500)
        XCTAssertTrue(Validators.isValidLength("texto"))
        XCTAssertTrue(Validators.isValidLength("a"))
        
        // Longitud personalizada
        XCTAssertTrue(Validators.isValidLength("12345", min: 5, max: 10))
        XCTAssertTrue(Validators.isValidLength("1234567890", min: 5, max: 10))
        
        XCTAssertFalse(Validators.isValidLength("1234", min: 5, max: 10))
        XCTAssertFalse(Validators.isValidLength("12345678901", min: 5, max: 10))
    }
    
    func testValidateText_ReturnsCorrectErrorMessages() {
        // Texto válido
        let validResult = Validators.validateText("Nombre válido")
        XCTAssertTrue(validResult.isValid)
        
        // Texto vacío
        let emptyResult = Validators.validateText("", fieldName: "Nombre")
        XCTAssertFalse(emptyResult.isValid)
        XCTAssertEqual(emptyResult.errorMessage, "Nombre no puede estar vacío")
        
        // Texto muy corto
        let shortResult = Validators.validateText("ab", fieldName: "Descripción", minLength: 5)
        XCTAssertFalse(shortResult.isValid)
        XCTAssertEqual(shortResult.errorMessage, "Descripción debe tener al menos 5 caracteres")
        
        // Texto muy largo
        let longText = String(repeating: "a", count: 600)
        let longResult = Validators.validateText(longText, fieldName: "Nota")
        XCTAssertFalse(longResult.isValid)
        XCTAssertEqual(longResult.errorMessage, "Nota no puede tener más de 500 caracteres")
    }
    
    // MARK: - Phone Validation Tests
    
    func testValidSpanishPhone_WithCorrectFormat_ReturnsTrue() {
        // Teléfonos españoles válidos
        XCTAssertTrue(Validators.isValidSpanishPhone("612345678"))
        XCTAssertTrue(Validators.isValidSpanishPhone("712345678"))
        XCTAssertTrue(Validators.isValidSpanishPhone("812345678"))
        XCTAssertTrue(Validators.isValidSpanishPhone("912345678"))
        
        // Con espacios o guiones (se limpian)
        XCTAssertTrue(Validators.isValidSpanishPhone("612 345 678"))
        XCTAssertTrue(Validators.isValidSpanishPhone("612-345-678"))
        XCTAssertTrue(Validators.isValidSpanishPhone("+34612345678"))
    }
    
    func testValidSpanishPhone_WithIncorrectFormat_ReturnsFalse() {
        // Teléfonos inválidos
        XCTAssertFalse(Validators.isValidSpanishPhone(""))
        XCTAssertFalse(Validators.isValidSpanishPhone("12345678"))  // No empieza por 6-9
        XCTAssertFalse(Validators.isValidSpanishPhone("512345678"))  // Empieza por 5
        XCTAssertFalse(Validators.isValidSpanishPhone("61234567"))   // Solo 8 dígitos
        XCTAssertFalse(Validators.isValidSpanishPhone("6123456789")) // 10 dígitos
    }
    
    // MARK: - Password Validation Tests
    
    func testValidPassword_WithCorrectFormat_ReturnsTrue() {
        // Contraseñas válidas (8+ chars, 1 mayúscula, 1 número)
        XCTAssertTrue(Validators.isValidPassword("Password1"))
        XCTAssertTrue(Validators.isValidPassword("Abcdefg1"))
        XCTAssertTrue(Validators.isValidPassword("MuySegura123"))
        XCTAssertTrue(Validators.isValidPassword("A1bcdefgh"))
    }
    
    func testValidPassword_WithIncorrectFormat_ReturnsFalse() {
        // Contraseñas inválidas
        XCTAssertFalse(Validators.isValidPassword(""))
        XCTAssertFalse(Validators.isValidPassword("short1A"))      // < 8 chars
        XCTAssertFalse(Validators.isValidPassword("nouppercase1")) // Sin mayúscula
        XCTAssertFalse(Validators.isValidPassword("NoNumbers"))    // Sin número
        XCTAssertFalse(Validators.isValidPassword("12345678"))     // Solo números
    }
    
    func testValidatePassword_ReturnsCorrectErrorMessages() {
        // Contraseña válida
        let validResult = Validators.validatePassword("Password123")
        XCTAssertTrue(validResult.isValid)
        
        // Muy corta
        let shortResult = Validators.validatePassword("Pass1")
        XCTAssertFalse(shortResult.isValid)
        XCTAssertEqual(shortResult.errorMessage, "La contraseña debe tener al menos 8 caracteres")
        
        // Sin mayúscula
        let noUpperResult = Validators.validatePassword("password123")
        XCTAssertFalse(noUpperResult.isValid)
        XCTAssertEqual(noUpperResult.errorMessage, "La contraseña debe contener al menos una mayúscula")
        
        // Sin número
        let noNumberResult = Validators.validatePassword("PasswordABC")
        XCTAssertFalse(noNumberResult.isValid)
        XCTAssertEqual(noNumberResult.errorMessage, "La contraseña debe contener al menos un número")
    }
    
    // MARK: - Username Validation Tests
    
    func testValidUsername_WithCorrectFormat_ReturnsTrue() {
        // Usernames válidos
        XCTAssertTrue(Validators.isValidUsername("usuario"))
        XCTAssertTrue(Validators.isValidUsername("user123"))
        XCTAssertTrue(Validators.isValidUsername("user_name"))
        XCTAssertTrue(Validators.isValidUsername("abc"))
    }
    
    func testValidUsername_WithIncorrectFormat_ReturnsFalse() {
        // Usernames inválidos
        XCTAssertFalse(Validators.isValidUsername(""))
        XCTAssertFalse(Validators.isValidUsername("ab"))            // < 3 chars
        XCTAssertFalse(Validators.isValidUsername("user-name"))     // Guión no permitido
        XCTAssertFalse(Validators.isValidUsername("user name"))     // Espacio
        XCTAssertFalse(Validators.isValidUsername("user@name"))     // Caracter especial
        XCTAssertFalse(Validators.isValidUsername("este_username_es_muy_largo")) // > 20
    }
    
    func testValidateUsername_ReturnsCorrectErrorMessages() {
        // Username válido
        let validResult = Validators.validateUsername("usuario123")
        XCTAssertTrue(validResult.isValid)
        
        // Vacío
        let emptyResult = Validators.validateUsername("")
        XCTAssertFalse(emptyResult.isValid)
        XCTAssertEqual(emptyResult.errorMessage, "El nombre de usuario no puede estar vacío")
        
        // Muy corto
        let shortResult = Validators.validateUsername("ab")
        XCTAssertFalse(shortResult.isValid)
        XCTAssertEqual(shortResult.errorMessage, "El nombre de usuario debe tener al menos 3 caracteres")
        
        // Muy largo
        let longUsername = String(repeating: "a", count: 25)
        let longResult = Validators.validateUsername(longUsername)
        XCTAssertFalse(longResult.isValid)
        XCTAssertEqual(longResult.errorMessage, "El nombre de usuario no puede tener más de 20 caracteres")
        
        // Caracteres inválidos
        let invalidResult = Validators.validateUsername("User@123")
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertEqual(invalidResult.errorMessage, "El nombre de usuario solo puede contener letras minúsculas, números y guiones bajos")
    }
    
    // MARK: - ValidationResult Tests
    
    func testValidationResult_IsValid_ReturnsCorrectValue() {
        let valid = ValidationResult.valid
        let invalid = ValidationResult.invalid("Error")
        
        XCTAssertTrue(valid.isValid)
        XCTAssertFalse(invalid.isValid)
    }
    
    func testValidationResult_ErrorMessage_ReturnsCorrectValue() {
        let valid = ValidationResult.valid
        let invalid = ValidationResult.invalid("Mensaje de error")
        
        XCTAssertNil(valid.errorMessage)
        XCTAssertEqual(invalid.errorMessage, "Mensaje de error")
    }
    
    func testValidationResult_Equatable() {
        XCTAssertEqual(ValidationResult.valid, ValidationResult.valid)
        XCTAssertEqual(ValidationResult.invalid("Error"), ValidationResult.invalid("Error"))
        XCTAssertNotEqual(ValidationResult.valid, ValidationResult.invalid("Error"))
        XCTAssertNotEqual(ValidationResult.invalid("Error1"), ValidationResult.invalid("Error2"))
    }
    
    // MARK: - FormValidator Tests
    
    func testFormValidator_AllValid_ReturnsTrue() {
        var form = FormValidator()
        form.add("Email", Validators.validateEmail("test@example.com"))
        form.add("Código", Validators.validateCode("KIT-001"))
        form.add("Cantidad", Validators.validateQuantity(5, min: 0, max: 10))
        
        XCTAssertTrue(form.isValid)
        XCTAssertNil(form.firstError)
        XCTAssertTrue(form.allErrors.isEmpty)
    }
    
    func testFormValidator_WithErrors_ReturnsFalse() {
        var form = FormValidator()
        form.add("Email", Validators.validateEmail("invalid"))
        form.add("Código", Validators.validateCode("KIT-001"))
        form.add("Cantidad", Validators.validateQuantity(-1, min: 0, max: 10))
        
        XCTAssertFalse(form.isValid)
        XCTAssertNotNil(form.firstError)
        XCTAssertEqual(form.allErrors.count, 2)
    }
    
    func testFormValidator_FirstError_ReturnsFirstInvalidField() {
        var form = FormValidator()
        form.add("Email", Validators.validateEmail("invalid"))
        form.add("Código", Validators.validateCode(""))
        
        // El primer error debería ser del email (se añadió primero)
        XCTAssertEqual(form.firstError, "El email debe contener @")
    }
    
    func testFormValidator_ErrorsByField_ReturnsCorrectMapping() {
        var form = FormValidator()
        form.add("Email", Validators.validateEmail("invalid"))
        form.add("Código", Validators.validateCode("KIT-001"))
        form.add("Cantidad", Validators.validateQuantity(-1, min: 0, max: 10))
        
        let errors = form.errorsByField
        
        XCTAssertNotNil(errors["Email"])
        XCTAssertNil(errors["Código"])  // Este es válido
        XCTAssertNotNil(errors["Cantidad"])
    }
}
