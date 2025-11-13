//
//  AccessDeniedView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

struct AccessDeniedView: View {
    let message: String
    init(_ message: String = "No tienes permisos para acceder a esta sección.") {
        self.message = message
    }
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.largeTitle)
            Text(message).multilineTextAlignment(.center)
            Text("Si crees que es un error, contacta con Logística o Programación.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}




#Preview {
    AccessDeniedView()
}
