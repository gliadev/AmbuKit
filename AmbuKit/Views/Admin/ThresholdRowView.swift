//
//  ThresholdRowView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI
import SwiftData

struct ThresholdRowView: View {
    @Environment(\.modelContext) private var context
    @State private var minText = ""
    @State private var maxText = ""
    let item: KitItem
    let currentUser: User

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.catalogItem?.name ?? "—").font(.headline)
            HStack {
                TextField("Mínimo", text: Binding(
                    get: { minText.isEmpty ? String(Int(item.min)) : minText },
                    set: { minText = $0 })
                ).keyboardType(.numberPad)

                TextField("Máximo", text: Binding(
                    get: { maxText.isEmpty ? String(Int(item.max ?? 0)) : maxText },
                    set: { maxText = $0 })
                ).keyboardType(.numberPad)

                Button("Guardar") {
                    let newMin = Double(minText) ?? item.min
                    let newMax = (Double(maxText) == 0 ? nil : Double(maxText))
                    guard newMax == nil || newMin <= newMax! else { return }
                    try? KitsRepository(context).updateThresholds(
                        item, min: newMin, max: newMax, actor: currentUser
                    )
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.callout)
        }
        .padding(.vertical, 4)
        .onAppear {
            minText = String(Int(item.min))
            maxText = String(Int(item.max ?? 0))
        }
    }
}
