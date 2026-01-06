//
//  KitType.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//



import Foundation

public enum KitType: String, Codable, CaseIterable, Identifiable, Sendable {
    case SVB
    case SVAe
    case SVA
    case custom
    
    public var id: String { rawValue }
    
    /// Nombre para mostrar en UI
    public var displayName: String {
        switch self {
        case .SVB: return "SVB - Soporte Vital Básico"
        case .SVAe: return "SVAe - SVA Enfermería"
        case .SVA: return "SVA - Soporte Vital Avanzado"
        case .custom: return "Personalizado"
        }
    }
    
    /// Nombre corto
    public var shortName: String {
        rawValue
    }
    
    /// Icono SF Symbol
    public var icon: String {
        switch self {
        case .SVB: return "cross.case"
        case .SVAe: return "cross.case.fill"
        case .SVA: return "cross.case.fill"
        case .custom: return "shippingbox"
        }
    }
}










































































