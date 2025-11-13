//
//  Kit.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//
import Foundation
import SwiftData

@Model
public final class Kit {
    @Attribute(.unique) public var code: String
    public var name: String
    public var typeRaw: String
    public var status: String
    public var lastAudit: Date?

    
    @Relationship(deleteRule: .cascade, inverse: \KitItem.kit)
    public var items: [KitItem] = []

   
    @Relationship(deleteRule: .nullify)
    public var vehicle: Vehicle?

    public var type: KitType {
        get { KitType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    public init(
        code: String,
        name: String,
        type: KitType,
        status: String = "ok",
        lastAudit: Date? = nil,
        vehicle: Vehicle? = nil
    ) {
        self.code = code
        self.name = name
        self.typeRaw = type.rawValue
        self.status = status
        self.lastAudit = lastAudit
        self.vehicle = vehicle
    }
}


