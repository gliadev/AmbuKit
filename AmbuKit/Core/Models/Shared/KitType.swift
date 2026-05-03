//
//  KitType.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//



import Foundation
import SwiftUI

public enum KitType: String, Codable, CaseIterable, Identifiable, Sendable {
    case SVB
    case SVAe
    case SVA
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .SVB:    return "SVB - Soporte Vital Básico"
        case .SVAe:   return "SVAe - SVA Enfermería"
        case .SVA:    return "SVA - Soporte Vital Avanzado"
        case .custom: return "Personalizado"
        }
    }

    public var shortName: String { rawValue }

    public var systemImage: String {
        switch self {
        case .SVB:    return "shippingbox.fill"
        case .SVAe:   return "cross.case.fill"
        case .SVA:    return "cross.case.fill"
        case .custom: return "shippingbox"
        }
    }

    public var color: Color {
        switch self {
        case .SVB:    return .blue
        case .SVAe:   return .orange
        case .SVA:    return .red
        case .custom: return .gray
        }
    }
}










































































