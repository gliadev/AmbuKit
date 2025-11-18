//
//  UnitOfMeasureFS.swift
//  AmbuKit
//
//  Created by Adolfo on 13/11/25.
//

import Foundation
import FirebaseFirestore
import Combine

/// Modelo Firebase para Unidades de Medida
/// Representa las unidades en que se miden los items (unidad, ml, mg, etc.)
public struct UnitOfMeasureFS: Codable, Identifiable {
    // MARK: - Firestore Properties
    
    /// ID único en Firestore (auto-generado)
@DocumentID public var id: String?
    
    // MARK: - Data Properties
    
    /// Símbolo de la unidad (ej: "u", "ml", "mg", "L")
    public var symbol: String
    
    /// Nombre completo de la unidad (ej: "unidad", "mililitro", "miligramo")
    public var name: String
    
    // MARK: - Timestamps
    
    /// Fecha de creación del registro
    public var createdAt: Date
    
    /// Fecha de última actualización
    public var updatedAt: Date
    
    // MARK: - Coding Keys
    
    /// Mapeo de propiedades a nombres de campos en Firestore
    public enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case createdAt
        case updatedAt
    }
    
    // MARK: - Initializer
    
    /// Inicializador para crear nueva unidad de medida
    /// - Parameters:
    ///   - id: ID de Firestore (opcional, auto-generado si es nil)
    ///   - symbol: Símbolo de la unidad
    ///   - name: Nombre completo de la unidad
    ///   - createdAt: Fecha de creación (default: ahora)
    ///   - updatedAt: Fecha de actualización (default: ahora)
    public init(
        id: String? = nil,
        symbol: String,
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Properties

public extension UnitOfMeasureFS {
    /// Texto para mostrar en UI (símbolo preferentemente)
    var displayText: String {
        symbol
    }
    
    /// Texto largo para mostrar en detalles
    var fullDisplayText: String {
        "\(name) (\(symbol))"
    }
}

// MARK: - Helper Methods

public extension UnitOfMeasureFS {
    /// Crea una copia actualizada de la unidad
    /// - Parameter updates: Closure para modificar propiedades
    /// - Returns: Nueva instancia con cambios aplicados
    func updated(_ updates: (inout UnitOfMeasureFS) -> Void) -> UnitOfMeasureFS {
        var copy = self
        copy.updatedAt = Date()
        updates(&copy)
        return copy
    }
}

// MARK: - Firestore Collection

public extension UnitOfMeasureFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "unitOfMeasures"
}

// MARK: - Common Units

public extension UnitOfMeasureFS {
    /// Unidades de medida más comunes en emergencias médicas
    enum CommonUnit: String {
        case unit = "u"
        case milliliter = "ml"
        case milligram = "mg"
        case liter = "L"
        case gram = "g"
        case piece = "pza"
        
        var fullName: String {
            switch self {
            case .unit: return "unidad"
            case .milliliter: return "mililitro"
            case .milligram: return "miligramo"
            case .liter: return "litro"
            case .gram: return "gramo"
            case .piece: return "pieza"
            }
        }
    }
}

// MARK: - Sample Data (para previews y testing)

#if DEBUG
public extension UnitOfMeasureFS {
    /// Unidad de ejemplo: unidad
    static let sampleUnit = UnitOfMeasureFS(
        id: "uom_unit",
        symbol: "u",
        name: "unidad"
    )
    
    /// Unidad de ejemplo: mililitro
    static let sampleMilliliter = UnitOfMeasureFS(
        id: "uom_ml",
        symbol: "ml",
        name: "mililitro"
    )
    
    /// Unidad de ejemplo: miligramo
    static let sampleMilligram = UnitOfMeasureFS(
        id: "uom_mg",
        symbol: "mg",
        name: "miligramo"
    )
    
    /// Array de unidades de ejemplo
    static let samples: [UnitOfMeasureFS] = [
        sampleUnit,
        sampleMilliliter,
        sampleMilligram
    ]
}
#endif
