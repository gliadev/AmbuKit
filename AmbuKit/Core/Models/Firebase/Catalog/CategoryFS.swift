//
//  CategoryFS.swift
//  AmbuKit
//
//  Created by Adolfo on 13/11/25.
//

import Foundation
import FirebaseFirestore
import Combine

/// Modelo Firebase para Categorías de productos
/// Representa una categoría de items del catálogo (Farmacia, Curas, Trauma, etc.)
public struct CategoryFS: Codable, Identifiable {
    // MARK: - Firestore Properties
    
    /// ID único en Firestore (auto-generado)
@DocumentID public var id: String?
    
    // MARK: - Data Properties
    
    /// Código único de la categoría (ej: "FARM", "CURAS")
    public var code: String
    
    /// Nombre descriptivo de la categoría (ej: "Farmacia", "Material de Curas")
    public var name: String
    
    /// Icono SF Symbol opcional para UI (ej: "cross.case.fill", "bandage.fill")
    public var icon: String?
    
    // MARK: - Timestamps
    
    /// Fecha de creación del registro
    public var createdAt: Date
    
    /// Fecha de última actualización
    public var updatedAt: Date
    
    // MARK: - Coding Keys
    
    /// Mapeo de propiedades a nombres de campos en Firestore
    public enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case icon
        case createdAt
        case updatedAt
    }
    
    // MARK: - Initializer
    
    /// Inicializador para crear nueva categoría
    /// - Parameters:
    ///   - id: ID de Firestore (opcional, auto-generado si es nil)
    ///   - code: Código único de la categoría
    ///   - name: Nombre descriptivo
    ///   - icon: Icono SF Symbol opcional
    ///   - createdAt: Fecha de creación (default: ahora)
    ///   - updatedAt: Fecha de actualización (default: ahora)
    public init(
        id: String? = nil,
        code: String,
        name: String,
        icon: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Properties

public extension CategoryFS {
    /// Indica si la categoría tiene un icono asignado
    var hasIcon: Bool {
        icon != nil && !(icon?.isEmpty ?? true)
    }
    
    /// Retorna el icono o uno por defecto
    var displayIcon: String {
        hasIcon ? icon! : "tag.fill"
    }
}

// MARK: - Helper Methods

public extension CategoryFS {
    /// Crea una copia actualizada de la categoría
    /// - Parameter updates: Closure para modificar propiedades
    /// - Returns: Nueva instancia con cambios aplicados
    func updated(_ updates: (inout CategoryFS) -> Void) -> CategoryFS {
        var copy = self
        copy.updatedAt = Date()
        updates(&copy)
        return copy
    }
}

// MARK: - Firestore Collection

public extension CategoryFS {
    /// Nombre de la colección en Firestore
    static let collectionName = "categories"
}

// MARK: - Sample Data (para previews y testing)

#if DEBUG
public extension CategoryFS {
    /// Categoría de ejemplo para Farmacia
    static let samplePharmacy = CategoryFS(
        id: "cat_pharmacy",
        code: "FARM",
        name: "Farmacia",
        icon: "cross.case.fill"
    )
    
    /// Categoría de ejemplo para Material de Curas
    static let sampleDressings = CategoryFS(
        id: "cat_dressings",
        code: "CURAS",
        name: "Material de Curas",
        icon: "bandage.fill"
    )
    
    /// Categoría de ejemplo para Trauma
    static let sampleTrauma = CategoryFS(
        id: "cat_trauma",
        code: "TRAUMA",
        name: "Trauma",
        icon: "staroflife.fill"
    )
    
    /// Array de categorías de ejemplo
    static let samples: [CategoryFS] = [
        samplePharmacy,
        sampleDressings,
        sampleTrauma
    ]
}
#endif

