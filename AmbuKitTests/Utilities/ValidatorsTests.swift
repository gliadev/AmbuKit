//
//  ValidatorsTests.swift
//  AmbuKitTests
//

import Testing
@testable import AmbuKit
import Foundation

@MainActor
@Suite(.tags(.unit))
struct ValidatorsTests {

    // MARK: - Email Validation Tests

    @Test func validEmail_WithCorrectFormat_ReturnsTrue() {
        #expect(Validators.isValidEmail("test@example.com"))
        #expect(Validators.isValidEmail("user.name@domain.org"))
        #expect(Validators.isValidEmail("user+tag@example.co.uk"))
        #expect(Validators.isValidEmail("nombre123@empresa.es"))
        #expect(Validators.isValidEmail("a@b.co"))
    }

    @Test func validEmail_WithIncorrectFormat_ReturnsFalse() {
        #expect(!Validators.isValidEmail(""))
        #expect(!Validators.isValidEmail("   "))
        #expect(!Validators.isValidEmail("invalid"))
        #expect(!Validators.isValidEmail("no-arroba.com"))
        #expect(!Validators.isValidEmail("@nodomain.com"))
        #expect(!Validators.isValidEmail("spaces in@email.com"))
        #expect(!Validators.isValidEmail("missing@domain"))
    }

    @Test func validateEmail_ReturnsCorrectValidationResult() {
        let validResult = Validators.validateEmail("test@example.com")
        #expect(validResult.isValid)
        #expect(validResult.errorMessage == nil)

        let emptyResult = Validators.validateEmail("")
        #expect(!emptyResult.isValid)
        #expect(emptyResult.errorMessage == "El email no puede estar vacío")

        let noAtResult = Validators.validateEmail("invalidemail.com")
        #expect(!noAtResult.isValid)
        #expect(noAtResult.errorMessage == "El email debe contener @")

        let invalidResult = Validators.validateEmail("test@")
        #expect(!invalidResult.isValid)
        #expect(invalidResult.errorMessage == "Formato de email inválido")
    }

    // MARK: - Quantity Validation Tests

    @Test func validQuantity_WithinRange_ReturnsTrue() {
        #expect(Validators.isValidQuantity(0))
        #expect(Validators.isValidQuantity(1))
        #expect(Validators.isValidQuantity(100))
        #expect(Validators.isValidQuantity(99999))
    }

    @Test func validQuantity_OutsideRange_ReturnsFalse() {
        #expect(!Validators.isValidQuantity(-1))
        #expect(!Validators.isValidQuantity(-100))
        #expect(!Validators.isValidQuantity(100000))
    }

    @Test func validQuantity_WithCustomRange_ValidatesCorrectly() {
        #expect(Validators.isValidQuantity(1, min: 1, max: 10))
        #expect(Validators.isValidQuantity(5, min: 1, max: 10))
        #expect(Validators.isValidQuantity(10, min: 1, max: 10))

        #expect(!Validators.isValidQuantity(0, min: 1, max: 10))
        #expect(!Validators.isValidQuantity(11, min: 1, max: 10))
    }

    @Test func validateQuantity_ReturnsCorrectErrorMessages() {
        let validResult = Validators.validateQuantity(5, min: 0, max: 10)
        #expect(validResult.isValid)

        let tooLowResult = Validators.validateQuantity(-1, min: 0, max: 10)
        #expect(!tooLowResult.isValid)
        #expect(tooLowResult.errorMessage == "Cantidad no puede ser menor que 0")

        let tooHighResult = Validators.validateQuantity(100, min: 0, max: 10)
        #expect(!tooHighResult.isValid)
        #expect(tooHighResult.errorMessage == "Cantidad no puede ser mayor que 10")

        let customFieldResult = Validators.validateQuantity(-5, min: 0, max: 100, fieldName: "Stock")
        #expect(customFieldResult.errorMessage == "Stock no puede ser menor que 0")
    }

    @Test func validQuantity_Double_ValidatesCorrectly() {
        #expect(Validators.isValidQuantity(0.0))
        #expect(Validators.isValidQuantity(50.5))
        #expect(Validators.isValidQuantity(99999.0))

        #expect(!Validators.isValidQuantity(-0.1))
        #expect(!Validators.isValidQuantity(Double.nan))
        #expect(!Validators.isValidQuantity(Double.infinity))
    }

    // MARK: - Date Validation Tests

    @Test func validExpirationDate_FutureDate_ReturnsTrue() throws {
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        #expect(Validators.isValidExpirationDate(tomorrow))

        let nextYear = try #require(Calendar.current.date(byAdding: .year, value: 1, to: Date()))
        #expect(Validators.isValidExpirationDate(nextYear))
    }

    @Test func validExpirationDate_Today_ReturnsTrue() {
        #expect(Validators.isValidExpirationDate(Date()))
    }

    @Test func validExpirationDate_PastDate_ReturnsFalse() throws {
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        #expect(!Validators.isValidExpirationDate(yesterday))

        let lastYear = try #require(Calendar.current.date(byAdding: .year, value: -1, to: Date()))
        #expect(!Validators.isValidExpirationDate(lastYear))
    }

    @Test func validateExpirationDate_ReturnsCorrectResult() throws {
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))

        let validResult = Validators.validateExpirationDate(tomorrow)
        #expect(validResult.isValid)

        let expiredResult = Validators.validateExpirationDate(yesterday)
        #expect(!expiredResult.isValid)
        #expect(expiredResult.errorMessage == "La fecha de caducidad no puede ser anterior a hoy")
    }

    @Test func isNotFutureDate_ValidatesCorrectly() throws {
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: Date()))

        #expect(Validators.isNotFutureDate(yesterday))
        #expect(Validators.isNotFutureDate(Date()))
        #expect(!Validators.isNotFutureDate(tomorrow))
    }

    // MARK: - Code Validation Tests

    @Test func validCode_WithCorrectFormat_ReturnsTrue() {
        #expect(Validators.isValidCode("KIT-001"))
        #expect(Validators.isValidCode("SVB"))
        #expect(Validators.isValidCode("ABC123"))
        #expect(Validators.isValidCode("kit_emergencia"))
        #expect(Validators.isValidCode("A1"))
    }

    @Test func validCode_WithIncorrectFormat_ReturnsFalse() {
        #expect(!Validators.isValidCode(""))
        #expect(!Validators.isValidCode("A"))
        #expect(!Validators.isValidCode("codigo con espacios"))
        #expect(!Validators.isValidCode("código@especial"))
        #expect(!Validators.isValidCode("123456789012345678901"))
    }

    @Test func validateCode_ReturnsCorrectErrorMessages() {
        let validResult = Validators.validateCode("KIT-001")
        #expect(validResult.isValid)

        let emptyResult = Validators.validateCode("")
        #expect(!emptyResult.isValid)
        #expect(emptyResult.errorMessage == "Código no puede estar vacío")

        let shortResult = Validators.validateCode("A")
        #expect(!shortResult.isValid)
        #expect(shortResult.errorMessage == "Código debe tener al menos 2 caracteres")

        let longCode = String(repeating: "A", count: 25)
        let longResult = Validators.validateCode(longCode)
        #expect(!longResult.isValid)
        #expect(longResult.errorMessage == "Código no puede tener más de 20 caracteres")

        let invalidResult = Validators.validateCode("kit@123")
        #expect(!invalidResult.isValid)
        #expect(invalidResult.errorMessage == "Código solo puede contener letras, números, guiones y guiones bajos")
    }

    // MARK: - Text Validation Tests

    @Test func isNotEmpty_ValidatesCorrectly() {
        #expect(Validators.isNotEmpty("texto"))
        #expect(Validators.isNotEmpty("  texto con espacios  "))

        #expect(!Validators.isNotEmpty(""))
        #expect(!Validators.isNotEmpty("   "))
    }

    @Test func isValidLength_ValidatesCorrectly() {
        #expect(Validators.isValidLength("texto"))
        #expect(Validators.isValidLength("a"))

        #expect(Validators.isValidLength("12345", min: 5, max: 10))
        #expect(Validators.isValidLength("1234567890", min: 5, max: 10))

        #expect(!Validators.isValidLength("1234", min: 5, max: 10))
        #expect(!Validators.isValidLength("12345678901", min: 5, max: 10))
    }

    @Test func validateText_ReturnsCorrectErrorMessages() {
        let validResult = Validators.validateText("Nombre válido")
        #expect(validResult.isValid)

        let emptyResult = Validators.validateText("", fieldName: "Nombre")
        #expect(!emptyResult.isValid)
        #expect(emptyResult.errorMessage == "Nombre no puede estar vacío")

        let shortResult = Validators.validateText("ab", fieldName: "Descripción", minLength: 5)
        #expect(!shortResult.isValid)
        #expect(shortResult.errorMessage == "Descripción debe tener al menos 5 caracteres")

        let longText = String(repeating: "a", count: 600)
        let longResult = Validators.validateText(longText, fieldName: "Nota")
        #expect(!longResult.isValid)
        #expect(longResult.errorMessage == "Nota no puede tener más de 500 caracteres")
    }

    // MARK: - Phone Validation Tests

    @Test func validSpanishPhone_WithCorrectFormat_ReturnsTrue() {
        #expect(Validators.isValidSpanishPhone("612345678"))
        #expect(Validators.isValidSpanishPhone("712345678"))
        #expect(Validators.isValidSpanishPhone("812345678"))
        #expect(Validators.isValidSpanishPhone("912345678"))

        #expect(Validators.isValidSpanishPhone("612 345 678"))
        #expect(Validators.isValidSpanishPhone("612-345-678"))
        #expect(Validators.isValidSpanishPhone("+34612345678"))
    }

    @Test func validSpanishPhone_WithIncorrectFormat_ReturnsFalse() {
        #expect(!Validators.isValidSpanishPhone(""))
        #expect(!Validators.isValidSpanishPhone("12345678"))
        #expect(!Validators.isValidSpanishPhone("512345678"))
        #expect(!Validators.isValidSpanishPhone("61234567"))
        #expect(!Validators.isValidSpanishPhone("6123456789"))
    }

    // MARK: - Password Validation Tests

    @Test func validPassword_WithCorrectFormat_ReturnsTrue() {
        #expect(Validators.isValidPassword("Password1"))
        #expect(Validators.isValidPassword("Abcdefg1"))
        #expect(Validators.isValidPassword("MuySegura123"))
        #expect(Validators.isValidPassword("A1bcdefgh"))
    }

    @Test func validPassword_WithIncorrectFormat_ReturnsFalse() {
        #expect(!Validators.isValidPassword(""))
        #expect(!Validators.isValidPassword("short1A"))
        #expect(!Validators.isValidPassword("nouppercase1"))
        #expect(!Validators.isValidPassword("NoNumbers"))
        #expect(!Validators.isValidPassword("12345678"))
    }

    @Test func validatePassword_ReturnsCorrectErrorMessages() {
        let validResult = Validators.validatePassword("Password123")
        #expect(validResult.isValid)

        let shortResult = Validators.validatePassword("Pass1")
        #expect(!shortResult.isValid)
        #expect(shortResult.errorMessage == "La contraseña debe tener al menos 8 caracteres")

        let noUpperResult = Validators.validatePassword("password123")
        #expect(!noUpperResult.isValid)
        #expect(noUpperResult.errorMessage == "La contraseña debe contener al menos una mayúscula")

        let noNumberResult = Validators.validatePassword("PasswordABC")
        #expect(!noNumberResult.isValid)
        #expect(noNumberResult.errorMessage == "La contraseña debe contener al menos un número")
    }

    // MARK: - Username Validation Tests

    @Test func validUsername_WithCorrectFormat_ReturnsTrue() {
        #expect(Validators.isValidUsername("usuario"))
        #expect(Validators.isValidUsername("user123"))
        #expect(Validators.isValidUsername("user_name"))
        #expect(Validators.isValidUsername("abc"))
    }

    @Test func validUsername_WithIncorrectFormat_ReturnsFalse() {
        #expect(!Validators.isValidUsername(""))
        #expect(!Validators.isValidUsername("ab"))
        #expect(!Validators.isValidUsername("user-name"))
        #expect(!Validators.isValidUsername("user name"))
        #expect(!Validators.isValidUsername("user@name"))
        #expect(!Validators.isValidUsername("este_username_es_muy_largo"))
    }

    @Test func validateUsername_ReturnsCorrectErrorMessages() {
        let validResult = Validators.validateUsername("usuario123")
        #expect(validResult.isValid)

        let emptyResult = Validators.validateUsername("")
        #expect(!emptyResult.isValid)
        #expect(emptyResult.errorMessage == "El nombre de usuario no puede estar vacío")

        let shortResult = Validators.validateUsername("ab")
        #expect(!shortResult.isValid)
        #expect(shortResult.errorMessage == "El nombre de usuario debe tener al menos 3 caracteres")

        let longUsername = String(repeating: "a", count: 25)
        let longResult = Validators.validateUsername(longUsername)
        #expect(!longResult.isValid)
        #expect(longResult.errorMessage == "El nombre de usuario no puede tener más de 20 caracteres")

        let invalidResult = Validators.validateUsername("User@123")
        #expect(!invalidResult.isValid)
        #expect(invalidResult.errorMessage == "El nombre de usuario solo puede contener letras minúsculas, números y guiones bajos")
    }

    // MARK: - ValidationResult Tests

    @Test func validationResult_IsValid_ReturnsCorrectValue() {
        let valid = ValidationResult.valid
        let invalid = ValidationResult.invalid("Error")

        #expect(valid.isValid)
        #expect(!invalid.isValid)
    }

    @Test func validationResult_ErrorMessage_ReturnsCorrectValue() {
        let valid = ValidationResult.valid
        let invalid = ValidationResult.invalid("Mensaje de error")

        #expect(valid.errorMessage == nil)
        #expect(invalid.errorMessage == "Mensaje de error")
    }

    @Test func validationResult_Equatable() {
        #expect(ValidationResult.valid == ValidationResult.valid)
        #expect(ValidationResult.invalid("Error") == ValidationResult.invalid("Error"))
        #expect(ValidationResult.valid != ValidationResult.invalid("Error"))
        #expect(ValidationResult.invalid("Error1") != ValidationResult.invalid("Error2"))
    }

    // MARK: - FormValidator Tests

    @Test func formValidator_AllValid_ReturnsTrue() {
        var form = FormValidator()
        form.add("Email", Validators.validateEmail("test@example.com"))
        form.add("Código", Validators.validateCode("KIT-001"))
        form.add("Cantidad", Validators.validateQuantity(5, min: 0, max: 10))

        #expect(form.isValid)
        #expect(form.firstError == nil)
        #expect(form.allErrors.isEmpty)
    }

    @Test func formValidator_WithErrors_ReturnsFalse() {
        var form = FormValidator()
        form.add("Email", Validators.validateEmail("invalid"))
        form.add("Código", Validators.validateCode("KIT-001"))
        form.add("Cantidad", Validators.validateQuantity(-1, min: 0, max: 10))

        #expect(!form.isValid)
        #expect(form.firstError != nil)
        #expect(form.allErrors.count == 2)
    }

    @Test func formValidator_FirstError_ReturnsFirstInvalidField() {
        var form = FormValidator()
        form.add("Email", Validators.validateEmail("invalid"))
        form.add("Código", Validators.validateCode(""))

        #expect(form.firstError == "El email debe contener @")
    }

    @Test func formValidator_ErrorsByField_ReturnsCorrectMapping() {
        var form = FormValidator()
        form.add("Email", Validators.validateEmail("invalid"))
        form.add("Código", Validators.validateCode("KIT-001"))
        form.add("Cantidad", Validators.validateQuantity(-1, min: 0, max: 10))

        let errors = form.errorsByField

        #expect(errors["Email"] != nil)
        #expect(errors["Código"] == nil)
        #expect(errors["Cantidad"] != nil)
    }
}
