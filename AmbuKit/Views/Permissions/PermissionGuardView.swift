//
//  PermissionGuardView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

struct PermissionGuardView<Content: View>: View {
    let canAccess: Bool
    let denialMessage: String
    @ViewBuilder var content: () -> Content

    init(canAccess: Bool,
         denialMessage: String = "No tienes permisos para acceder a esta sección.",
         @ViewBuilder content: @escaping () -> Content) {
        self.canAccess = canAccess
        self.denialMessage = denialMessage
        self.content = content
    }

    var body: some View {
        if canAccess { content() } else { AccessDeniedView(denialMessage) }
    }
}

extension View {
    
    @ViewBuilder func visibleWhen(_ condition: Bool) -> some View {
        if condition { self }
    }
}

