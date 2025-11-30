//
//  FirestoreModelsExtensions.swift
//  AmbuKit
//
//  Created by Adolfo on 17/11/25.
//

import Foundation
import FirebaseFirestore

// MARK: - VehicleFS Extensions

// MARK: - KitFS Extensions

public extension KitFS {
    /// Crea un KitFS desde un DocumentSnapshot de Firestore
    /// - Parameter snapshot: DocumentSnapshot de Firestore
    /// - Returns: KitFS si se puede decodificar, nil si no
    static func from(snapshot: DocumentSnapshot) -> KitFS? {
        guard snapshot.exists else { return nil }
        return try? snapshot.data(as: KitFS.self)
    }
}

// MARK: - KitItemFS Extensions

public extension KitItemFS {
    /// Crea un KitItemFS desde un DocumentSnapshot de Firestore
    /// - Parameter snapshot: DocumentSnapshot de Firestore
    /// - Returns: KitItemFS si se puede decodificar, nil si no
    static func from(snapshot: DocumentSnapshot) -> KitItemFS? {
        guard snapshot.exists else { return nil }
        return try? snapshot.data(as: KitItemFS.self)
    }
}

// MARK: - CatalogItemFS Extensions

public extension CatalogItemFS {
    /// Crea un CatalogItemFS desde un DocumentSnapshot de Firestore
    /// - Parameter snapshot: DocumentSnapshot de Firestore
    /// - Returns: CatalogItemFS si se puede decodificar, nil si no
    static func from(snapshot: DocumentSnapshot) -> CatalogItemFS? {
        guard snapshot.exists else { return nil }
        return try? snapshot.data(as: CatalogItemFS.self)
    }
}

// MARK: - CategoryFS Extensions

public extension CategoryFS {
    /// Crea un CategoryFS desde un DocumentSnapshot de Firestore
    /// - Parameter snapshot: DocumentSnapshot de Firestore
    /// - Returns: CategoryFS si se puede decodificar, nil si no
    static func from(snapshot: DocumentSnapshot) -> CategoryFS? {
        guard snapshot.exists else { return nil }
        return try? snapshot.data(as: CategoryFS.self)
    }
}

// MARK: - UnitOfMeasureFS Extensions

public extension UnitOfMeasureFS {
    /// Crea un UnitOfMeasureFS desde un DocumentSnapshot de Firestore
    /// - Parameter snapshot: DocumentSnapshot de Firestore
    /// - Returns: UnitOfMeasureFS si se puede decodificar, nil si no
    static func from(snapshot: DocumentSnapshot) -> UnitOfMeasureFS? {
        guard snapshot.exists else { return nil }
        return try? snapshot.data(as: UnitOfMeasureFS.self)
    }
}
