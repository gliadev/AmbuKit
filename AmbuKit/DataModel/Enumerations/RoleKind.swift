//
//  RoleKind.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation

public enum RoleKind: String, Codable, CaseIterable, Identifiable {
    case programmer, logistics, sanitary
    public var id: String { rawValue }
}

