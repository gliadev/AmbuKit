//
//  Vehicle.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//
import Foundation
import SwiftData

@Model
public final class Vehicle {
    @Attribute(.unique)
    public var code: String

    public var plate: String?
    public var type: String

    @Relationship(deleteRule: .nullify, inverse: \Kit.vehicle)
    public var kits: [Kit] = []

    
    @Relationship(deleteRule: .nullify)
    public var base: Base?

    public init(code: String, plate: String? = nil, type: String, base: Base? = nil) {
        self.code = code
        self.plate = plate
        self.type = type
        self.base = base
    }
}

