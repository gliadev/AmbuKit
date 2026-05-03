//
//  CreateBaseScreen.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

// MARK: - Create Base Screen

struct CreateBaseScreen: View {
    let currentUser: UserFS

    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var name = ""
    @State private var address = ""
    @State private var isActive = true
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        Form {
            Section {
                TextField("Código (ej: 2401)", text: $code)
                    .textInputAutocapitalization(.characters)

                TextField("Nombre (ej: Bilbao Centro)", text: $name)

                TextField("Dirección (opcional)", text: $address)

                Toggle("Base activa", isOn: $isActive)
            } header: {
                Text("Datos de la Base")
            }

            Section {
                Button {
                    Task { await createBase() }
                } label: {
                    HStack {
                        Spacer()
                        if isProcessing {
                            ProgressView()
                        } else {
                            Label("Crear Base", systemImage: "plus.circle.fill")
                        }
                        Spacer()
                    }
                }
                .disabled(code.isEmpty || name.isEmpty || isProcessing)
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Nueva Base")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Base Creada", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("La base '\(name)' se ha creado correctamente.")
        }
    }

    private func createBase() async {
        isProcessing = true
        errorMessage = nil

        do {
            _ = try await BaseService.shared.create(
                code: code,
                name: name,
                address: address.isEmpty ? nil : address,
                active: isActive,
                actor: currentUser
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
