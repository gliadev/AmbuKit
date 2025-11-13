//
//  KitType.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation


public enum KitType: String, Codable, CaseIterable, Identifiable {
    case SVB, SVAe, SVA, custom; public var id: String { rawValue }
}
