//
//  VehiclesRepository.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData


public struct VehiclesRepository { private let context: ModelContext; public init(_ context: ModelContext) { self.context = context }
    @discardableResult public func create(code: String, type: String, plate: String? = nil, base: Base? = nil) -> Vehicle { let v = Vehicle(code: code, plate: plate, type: type, base: base); context.insert(v); return v }
    public func fetchAll() throws -> [Vehicle] { try context.fetch(FetchDescriptor<Vehicle>()) }
}
