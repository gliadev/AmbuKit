//
//  ErrorHelper.swift
//  AmbuKit
//
//  Created by Adolfo on 31/12/24.
//

import Foundation

/// Convierte errores técnicos de Firebase en mensajes amigables para el usuario
struct ErrorHelper {
    
    /// Convierte un error en un mensaje legible en español
    /// - Parameter error: Error a convertir
    /// - Returns: Mensaje amigable para mostrar al usuario
    static func friendlyMessage(for error: Error) -> String {
        
        // 1. Primero verificar si es un error personalizado de los servicios
        // Estos ya tienen mensajes descriptivos, solo limpiamos el prefijo
        let localizedMessage = error.localizedDescription
        if localizedMessage.hasPrefix("❌") {
            // Quitar "❌ Tipo: " del mensaje
            let cleanMessage = localizedMessage
                .replacingOccurrences(of: "❌ Sin autorización: ", with: "")
                .replacingOccurrences(of: "❌ Kit no encontrado: ", with: "")
                .replacingOccurrences(of: "❌ Item de kit no encontrado: ", with: "")
                .replacingOccurrences(of: "❌ Vehículo no encontrado: ", with: "")
                .replacingOccurrences(of: "❌ Item del catálogo no encontrado: ", with: "")
                .replacingOccurrences(of: "❌ Código duplicado: ", with: "")
                .replacingOccurrences(of: "❌ Datos inválidos: ", with: "")
                .replacingOccurrences(of: "❌ Kit tiene items: ", with: "")
                .replacingOccurrences(of: "❌ Item ya existe: ", with: "")
                .replacingOccurrences(of: "❌ Error de Firestore: ", with: "")
                .replacingOccurrences(of: "❌ ", with: "")
            return cleanMessage
        }
        
        let nsError = error as NSError
        
        // 2. Errores de red (NSURLError)
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "Sin conexión a internet. Verifica tu conexión."
            case NSURLErrorTimedOut:
                return "La operación tardó demasiado tiempo. Inténtalo de nuevo."
            case NSURLErrorCannotFindHost:
                return "No se pudo conectar al servidor."
            case NSURLErrorNetworkConnectionLost:
                return "Se perdió la conexión de red."
            case NSURLErrorCannotConnectToHost:
                return "No se puede conectar al servidor. Verifica tu conexión."
            default:
                return "Error de conexión. Verifica tu red e inténtalo de nuevo."
            }
        }
        
        // 3. Errores de Firebase Auth
        if nsError.domain == "FIRAuthErrorDomain" {
            switch nsError.code {
            case 17005: return "El usuario ha sido deshabilitado"
            case 17007: return "Este email ya está registrado"
            case 17008: return "Formato de email inválido"
            case 17009: return "Contraseña incorrecta"
            case 17011: return "No se encontró ningún usuario con este email"
            case 17020: return "La red no está disponible"
            case 17026: return "La contraseña es demasiado débil (mínimo 6 caracteres)"
            case 17052: return "Se requiere volver a autenticarse"
            default: return "Error de autenticación. Inténtalo de nuevo."
            }
        }
        
        // 4. Errores de Firestore
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 1: return "Operación cancelada"
            case 2: return "Error interno del servidor"
            case 3: return "Datos inválidos"
            case 4: return "La operación tardó demasiado tiempo"
            case 5: return "El documento no fue encontrado"
            case 6: return "Ya existe un documento con estos datos"
            case 7: return "No tienes permisos para realizar esta operación"
            case 8: return "Recursos insuficientes. Inténtalo más tarde."
            case 9: return "Falló una precondición de la operación"
            case 10: return "Operación cancelada"
            case 11: return "Error de datos fuera de rango"
            case 12: return "Esta operación no está implementada"
            case 13: return "Error interno del servidor"
            case 14: return "El servicio no está disponible temporalmente"
            case 15: return "Error de datos perdidos"
            case 16: return "Credenciales inválidas"
            default: return "Error guardando datos. Inténtalo de nuevo."
            }
        }
        
        // 5. Detección por palabras clave en el mensaje
        let errorMessage = localizedMessage.lowercased()
        
        if errorMessage.contains("unauthorized") || errorMessage.contains("permission") {
            return "No tienes permisos para realizar esta acción"
        }
        
        if errorMessage.contains("duplicate") || errorMessage.contains("already exists") {
            return "Ya existe un elemento con ese código"
        }
        
        if errorMessage.contains("not found") || errorMessage.contains("no encontrado") {
            return "El elemento solicitado no fue encontrado"
        }
        
        if errorMessage.contains("network") || errorMessage.contains("connection") {
            return "Error de conexión. Verifica tu red."
        }
        
        if errorMessage.contains("timeout") {
            return "La operación tardó demasiado tiempo"
        }
        
        // 6. Fallback - mensaje original si es legible, o genérico
        if localizedMessage.count < 100 && !localizedMessage.contains("Error Domain") {
            return localizedMessage
        }
        
        return "Ha ocurrido un error. Inténtalo de nuevo."
    }
}

// MARK: - Previews

#if DEBUG
extension ErrorHelper {
    /// Errores de ejemplo para testing/preview
    static let previewErrors: [(name: String, message: String)] = [
        ("Sin internet", friendlyMessage(for: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))),
        ("Timeout", friendlyMessage(for: NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut))),
        ("Sin permisos", friendlyMessage(for: NSError(domain: "FIRFirestoreErrorDomain", code: 7))),
        ("No encontrado", friendlyMessage(for: NSError(domain: "FIRFirestoreErrorDomain", code: 5))),
        ("Email en uso", friendlyMessage(for: NSError(domain: "FIRAuthErrorDomain", code: 17007)))
    ]
}
#endif
