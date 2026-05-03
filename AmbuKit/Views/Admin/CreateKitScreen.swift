//
//  CreateKitScreen.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

// MARK: - Create Kit Screen

struct CreateKitScreen: View {
    let currentUser: UserFS

    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var name = ""
    @State private var selectedType: KitType = .SVB
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        Form {
            Section {
                TextField("Código (ej: KIT-001)", text: $code)
                    .textInputAutocapitalization(.characters)

                TextField("Nombre (ej: Kit SVA Principal)", text: $name)

                Picker("Tipo de Kit", selection: $selectedType) {
                    ForEach(KitType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            } header: {
                Text("Datos del Kit")
            }

            Section {
                Button {
                    Task { await createKit() }
                } label: {
                    HStack {
                        Spacer()
                        if isProcessing {
                            ProgressView()
                        } else {
                            Label("Crear Kit", systemImage: "plus.circle.fill")
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
        .navigationTitle("Nuevo Kit")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Kit Creado", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("El kit '\(name)' se ha creado correctamente.")
        }
    }

    private func createKit() async {
        isProcessing = true
        errorMessage = nil

        do {
            _ = try await KitService.shared.createKit(
                code: code,
                name: name,
                type: selectedType,
                actor: currentUser
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
