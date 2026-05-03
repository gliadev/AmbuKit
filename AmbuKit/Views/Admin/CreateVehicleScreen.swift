//
//  CreateVehicleScreen.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

// MARK: - Create Vehicle Screen

struct CreateVehicleScreen: View {
    let currentUser: UserFS

    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var plate = ""
    @State private var selectedType: VehicleFS.VehicleType = .svb
    @State private var selectedBaseId: String?
    @State private var bases: [BaseFS] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        Form {
            Section {
                TextField("Código (ej: AMB-001)", text: $code)
                    .textInputAutocapitalization(.characters)

                TextField("Matrícula (opcional)", text: $plate)
                    .textInputAutocapitalization(.characters)

                Picker("Tipo de Vehículo", selection: $selectedType) {
                    ForEach(VehicleFS.VehicleType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                Picker("Base (opcional)", selection: $selectedBaseId) {
                    Text("Sin asignar").tag(nil as String?)
                    ForEach(bases) { base in
                        Text("\(base.code) - \(base.name)").tag(base.id as String?)
                    }
                }
            } header: {
                Text("Datos del Vehículo")
            }

            Section {
                Button {
                    Task { await createVehicle() }
                } label: {
                    HStack {
                        Spacer()
                        if isProcessing {
                            ProgressView()
                        } else {
                            Label("Crear Vehículo", systemImage: "plus.circle.fill")
                        }
                        Spacer()
                    }
                }
                .disabled(code.isEmpty || isProcessing)
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Nuevo Vehículo")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            bases = await BaseService.shared.getActiveBases()
        }
        .alert("Vehículo Creado", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("El vehículo '\(code)' se ha creado correctamente.")
        }
    }

    private func createVehicle() async {
        isProcessing = true
        errorMessage = nil

        do {
            _ = try await VehicleService.shared.create(
                code: code,
                plate: plate.isEmpty ? nil : plate,
                type: selectedType.rawValue,
                baseId: selectedBaseId,
                actor: currentUser
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
