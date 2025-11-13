//
//  InventoryView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI
import SwiftData

struct InventoryView: View {
    @Environment(\.modelContext) private var context
    let currentUser: User
    @Query(sort: \Kit.code) private var kits: [Kit]

    var body: some View {
        NavigationStack {
            Group {
                if kits.isEmpty {
                    EmptyStateView("No hay kits",
                                   message: "Añade kits desde la pestaña Gestión (Programador).")
                } else {
                    List {
                        ForEach(kits, id: \.code) { kit in
                            NavigationLink {
                                KitDetailView(kit: kit, currentUser: currentUser)
                            } label: {
                                HStack {
                                    Text(kit.name)
                                    Spacer()
                                    Text(kit.type.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Kits")
        }
    }
}

struct KitDetailView: View {
    @Environment(\.modelContext) private var context
    let kit: Kit
    let currentUser: User

    var body: some View {
        List {
            ForEach(kit.items.indices, id: \.self) { idx in
                let item = kit.items[idx]
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.catalogItem?.name ?? "—")
                        Text("Mín: \(Int(item.min))" + (item.max != nil ? " · Máx: \(Int(item.max!))" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper("\(Int(item.quantity))", value: Binding(
                        get: { Int(item.quantity) },
                        set: { newValue in
                            try? KitsRepository(context)
                                .updateItem(item, setQuantity: Double(newValue), actor: currentUser)
                        })
                    )
                    .labelsHidden()
                }
                .foregroundStyle((item.quantity < item.min) ? .red : .primary)
                .overlay(alignment: .trailing) {
                    if let max = item.max, item.quantity > max {
                        Text("Sobre stock").font(.caption2).foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle(kit.name)
        .toolbar {
            if AuthorizationService.allowed(.delete, on: .kit, for: currentUser) {
                Button(role: .destructive) {
                    try? KitsRepository(context).delete(kit, actor: currentUser)
                } label: { Label("Eliminar", systemImage: "trash") }
            }
        }
    }
}

#Preview("Inventory - Sanitary") {
    InventoryView(currentUser: PreviewSupport.user("san.bilbao"))
        .modelContainer(PreviewSupport.container)
}

