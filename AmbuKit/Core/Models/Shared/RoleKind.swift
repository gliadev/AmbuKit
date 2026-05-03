//
//  RoleKind.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftUI

public enum RoleKind: String, Codable, CaseIterable, Identifiable {
    case programmer, logistics, sanitary
    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .programmer: return .blue
        case .logistics:  return .orange
        case .sanitary:   return .green
        }
    }
}

