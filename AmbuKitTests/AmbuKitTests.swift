//
//  AmbuKitTests.swift
//  AmbuKitTests
//

import Testing
@testable import AmbuKit
import Foundation

@Suite(.tags(.unit))
struct AmbuKitSmokeTests {

    @Test("Enums básicos son codificables")
    func basicEnumsAreCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for kind in RoleKind.allCases {
            let data = try encoder.encode(kind)
            let decoded = try decoder.decode(RoleKind.self, from: data)
            #expect(kind == decoded)
        }

        for action in ActionKind.allCases {
            let data = try encoder.encode(action)
            let decoded = try decoder.decode(ActionKind.self, from: data)
            #expect(action == decoded)
        }
    }
}
