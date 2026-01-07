//
//  AuditKitScreen.swift
//  AmbuKit
//
//  Created by Adolfo on 7/1/26.
//  TAREA D: Sistema de Auditorías de Kits
//

import SwiftUI

// MARK: - Audit Kit Screen

/// Pantalla para registrar una auditoría de kit
///
/// Permite al usuario marcar un kit como auditado y añadir observaciones opcionales.
struct AuditKitScreen: View {
    
    // MARK: - Properties
    
    let kit: KitFS
    let currentUser: UserFS
    let onAudited: () -> Void
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var notes = ""
    @State private var isProcessing = false
    @State private var toast: Toast?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Info del kit
                kitInfoSection
                
                // Fecha última auditoría
                lastAuditSection
                
                // Observaciones
                notesSection
            }
            .navigationTitle("Auditar Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Registrar") {
                        Task { await auditKit() }
                    }
                    .disabled(isProcessing)
                }
            }
            .toast($toast)
        }
    }
    
    // MARK: - Kit Info Section
    
    private var kitInfoSection: some View {
        Section("Kit a Auditar") {
            HStack {
                Image(systemName: kitIcon)
                    .font(.title2)
                    .foregroundStyle(kitColor)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(kit.name)
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Text(kit.code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(kit.type)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(kitColor.opacity(0.15))
                            .foregroundStyle(kitColor)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Last Audit Section
    
    private var lastAuditSection: some View {
        Section {
            HStack {
                Label("Última auditoría", systemImage: "calendar")
                
                Spacer()
                
                if let lastAudit = kit.lastAudit {
                    Text(lastAudit, style: .date)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Nunca")
                        .foregroundStyle(.orange)
                }
            }
            
            HStack {
                Label("Días desde última", systemImage: "clock")
                
                Spacer()
                
                if let lastAudit = kit.lastAudit {
                    let days = Calendar.current.dateComponents([.day], from: lastAudit, to: Date()).day ?? 0
                    Text("\(days) días")
                        .foregroundStyle(days > 30 ? .orange : .secondary)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        Section {
            TextEditor(text: $notes)
                .frame(minHeight: 100)
        } header: {
            Text("Observaciones (opcional)")
        } footer: {
            Text("Añade cualquier observación sobre el estado del kit, faltantes detectados, etc.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Helpers
    
    private var kitIcon: String {
        switch kit.type.lowercased() {
        case let t where t.contains("sva"):
            return "cross.case.fill"
        case let t where t.contains("svb"):
            return "shippingbox.fill"
        case let t where t.contains("ped"):
            return "figure.and.child.holdinghands"
        case let t where t.contains("trauma"):
            return "bandage.fill"
        case let t where t.contains("ampul"):
            return "pills.fill"
        default:
            return "cross.case.fill"
        }
    }
    
    private var kitColor: Color {
        switch kit.type.lowercased() {
        case let t where t.contains("sva"):
            return .red
        case let t where t.contains("svb"):
            return .blue
        case let t where t.contains("ped"):
            return .pink
        case let t where t.contains("trauma"):
            return .orange
        case let t where t.contains("ampul"):
            return .purple
        default:
            return .blue
        }
    }
    
    // MARK: - Audit Kit
    
    private func auditKit() async {
        isProcessing = true
        
        do {
            try await KitService.shared.auditKit(
                kitId: kit.id ?? "",
                notes: notes.isEmpty ? nil : notes,
                actor: currentUser
            )
            
            toast = .success("Kit auditado correctamente")
            onAudited()
            
            try? await Task.sleep(for: .seconds(0.5))
            dismiss()
            
        } catch {
            toast = .error(error)
        }
        
        isProcessing = false
    }
}

// MARK: - Preview

#Preview("Audit Kit - Needs Audit") {
    AuditKitScreen(
        kit: KitFS(
            id: "kit_001",
            code: "AMP-SVA-001",
            name: "Ampulario SVA",
            type: "SVA",
            status: .active,
            lastAudit: Date().addingTimeInterval(-86400 * 45),
            vehicleId: nil
        ),
        currentUser: UserFS(
            id: "user_1",
            uid: "uid_1",
            username: "admin",
            fullName: "Admin",
            email: "admin@test.com",
            roleId: "role_prog"
        ),
        onAudited: {}
    )
}

#Preview("Audit Kit - Never Audited") {
    AuditKitScreen(
        kit: KitFS(
            id: "kit_002",
            code: "CUR-SVA-001",
            name: "Kit Curas SVA",
            type: "SVA",
            status: .active,
            lastAudit: nil,
            vehicleId: nil
        ),
        currentUser: UserFS(
            id: "user_1",
            uid: "uid_1",
            username: "admin",
            fullName: "Admin",
            email: "admin@test.com",
            roleId: "role_prog"
        ),
        onAudited: {}
    )
}



