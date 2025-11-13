//
//  BasesRepository.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData

public struct BasesRepository { private let context: ModelContext; public init(_ context: ModelContext) { self.context = context }
    @discardableResult public func create(code: String, name: String, location: String? = nil) -> Base { let b = Base(code: code, name: name, location: location); context.insert(b); return b }
    public func fetchAll() throws -> [Base] { try context.fetch(FetchDescriptor<Base>()) }
}
