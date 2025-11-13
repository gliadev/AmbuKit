//
//  AdminView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI
import SwiftData

struct AdminView: View {
    @Environment(\.modelContext) private var context
    let currentUser: User

    @State private var code = ""
    @State private var name = ""
    @State private var type: KitType = .SVB
    @Query private var vehicles: [Vehicle]
    @State private var selectedVehicle: Vehicle?

    var body: some View {
        let caps = UIPermissions.userMgmt(currentUser)
        let canAccessAdmin = UIPermissions.canCreateKits(currentUser)
                           || UIPermissions.canEditThresholds(currentUser)
                           || caps.read || caps.update || caps.delete

        return PermissionGuardView(canAccess: canAccessAdmin) {
            NavigationStack {
                Form {
                    // CREAR KIT (solo Programador)
                    Section("Crear kit (solo Programador)") {
                        if UIPermissions.canCreateKits(currentUser) {
                            TextField("Código", text: $code)
                            TextField("Nombre", text: $name)
                            Picker("Tipo", selection: $type) {
                                ForEach(KitType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            Picker("Vehículo", selection: $selectedVehicle) {
                                Text("— Sin asignar —").tag(Optional<Vehicle>.none)
                                ForEach(vehicles, id: \.code) { v in
                                    Text("\(v.code) (\(v.type))").tag(Optional(v))
                                }
                            }
                            Button("Crear") {
                               _ = try? KitsRepository(context).create(
                                    code: code, name: name, type: type,
                                    vehicle: selectedVehicle, actor: currentUser
                                )
                                code = ""; name = ""; selectedVehicle = nil
                            }
                            .disabled(code.isEmpty || name.isEmpty)
                        } else {
                            Text("No tienes permisos para crear kits.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // UMBRALES (Programador/Logística)
                    Section("Umbrales min/máx (Programador/Logística)") {
                        if UIPermissions.canEditThresholds(currentUser) {
                            ThresholdsEditor(currentUser: currentUser)
                        } else {
                            Text("No tienes permisos para editar umbrales.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Gestión")
            }
        }
    }
}

private struct ThresholdsEditor: View {
    @Environment(\.modelContext) private var context
    let currentUser: User
    @Query(sort: \Kit.code) private var kits: [Kit]

    var body: some View {
        if kits.isEmpty { EmptyStateView("No hay kits") }
        ForEach(kits, id: \.code) { kit in
            Section(kit.name) {
                ForEach(kit.items.indices, id: \.self) { idx in
                    let item = kit.items[idx]
                    ThresholdRowView(item: item, currentUser: currentUser)
                }
            }
        }
    }
}

#Preview("Admin - Programmer") {
    AdminView(currentUser: PreviewSupport.user("programmer"))
        .modelContainer(PreviewSupport.container)
}

