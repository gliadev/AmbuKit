//
//  KitServiceUsageExample.swift
//  AmbuKit
//
//  Created by Adolfo on 18/11/25.
//


import SwiftUI

// MARK: - KitType Extension

extension KitType {
    var displayName: String {
        switch self {
        case .SVB: return "SVB"
        case .SVAe: return "SVAe"
        case .SVA: return "SVA"
        case .custom: return "Personalizado"
        }
    }
}

// MARK: - Main View

struct KitServiceUsageExampleView: View {
    @State private var currentUser: UserFS? = UserFS(
        id: "user_1",
        uid: "firebase_uid_user1",
        username: "jperez",
        fullName: "Juan Pérez",
        email: "juan@ambukit.com",
        active: true,
        roleId: "role_programmer"
    )
    
    var body: some View {
        TabView {
            KitManagementView(currentUser: currentUser)
                .tabItem {
                    Label("Kits", systemImage: "cross.case")
                }
            
            StockAlertsTabView()
                .tabItem {
                    Label("Alertas", systemImage: "exclamationmark.triangle")
                }
            
            KitStatisticsView()
                .tabItem {
                    Label("Estadísticas", systemImage: "chart.bar")
                }
        }
    }
}

// MARK: - Kit Management View

struct KitManagementView: View {
    let currentUser: UserFS?
    
    @State private var kits: [KitFS] = []
    @State private var searchText = ""
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredKits) { kit in
                    NavigationLink {
                        KitDetailsScreen(kit: kit, currentUser: currentUser)
                    } label: {
                        KitListRow(kit: kit)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar kits...")
            .navigationTitle("Kits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Nuevo Kit", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                CreateKitSheet(
                    currentUser: currentUser,
                    onComplete: {
                        showingAddSheet = false
                        Task { await loadKits() }
                    }
                )
            }
            .task {
                await loadKits()
            }
        }
    }
    
    private var filteredKits: [KitFS] {
        if searchText.isEmpty {
            return kits
        }
        return kits.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func loadKits() async {
        kits = await KitService.shared.getAllKits()
    }
}

// MARK: - Kit List Row

struct KitListRow: View {
    let kit: KitFS
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(kit.code)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if kit.needsAudit {
                    Text("⚠️ Auditoría")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Image(systemName: kit.statusIcon)
                    .foregroundColor(colorForStatus(kit.status))
            }
            
            Text(kit.name)
                .font(.headline)
            
            HStack {
                Text(kit.type.displayName)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                if kit.isAssigned {
                    Text("• Asignado")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status.lowercased() {
        case "ok": return .green
        case "revision": return .orange
        case "mantenimiento": return .red
        default: return .gray
        }
    }
}

// MARK: - Kit Details Screen

struct KitDetailsScreen: View {
    let kit: KitFS
    let currentUser: UserFS?
    
    @State private var items: [KitItemFS] = []
    @State private var showingAddItemSheet = false
    
    var body: some View {
        List {
            Section("Información") {
                LabeledContent("Código", value: kit.code)
                LabeledContent("Tipo", value: kit.type.displayName)
                LabeledContent("Estado", value: kit.status)
                
                if let audit = kit.lastAudit {
                    LabeledContent("Última auditoría") {
                        Text(audit, style: .date)
                    }
                }
            }
            
            Section {
                Button("Añadir Item") {
                    showingAddItemSheet = true
                }
            } header: {
                Text("Items (\(items.count))")
            }
            
            Section {
                if items.isEmpty {
                    Text("Sin items")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(items) { item in
                        KitItemListRow(item: item)
                    }
                }
            }
        }
        .navigationTitle(kit.name)
        .sheet(isPresented: $showingAddItemSheet) {
            Text("Sheet para añadir item")
        }
        .task {
            items = await KitService.shared.getKitItems(kitId: kit.id ?? "")
        }
    }
}

// MARK: - Kit Item Row

struct KitItemListRow: View {
    let item: KitItemFS
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: item.stockStatus.icon)
                    .foregroundColor(colorForStatus(item.stockStatus))
                
                Text("Cantidad: \(Int(item.quantity))")
                    .font(.headline)
                
                Spacer()
                
                if item.isExpired {
                    Text("⚠️ CADUCADO")
                        .font(.caption2)
                        .foregroundColor(.red)
                } else if item.isExpiringSoon {
                    Text("⚠️ Caduca pronto")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            HStack {
                Text("Min: \(Int(item.min))")
                if let max = item.max {
                    Text("• Max: \(Int(max))")
                }
                
                if let expiry = item.expiry {
                    Text("• Caduca: \(expiry, style: .date)")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func colorForStatus(_ status: KitItemFS.StockStatus) -> Color {
        switch status {
        case .low: return .red
        case .ok: return .green
        case .high: return .orange
        }
    }
}

// MARK: - Create Kit Sheet

struct CreateKitSheet: View {
    let currentUser: UserFS?
    let onComplete: () -> Void
    
    @State private var code = ""
    @State private var name = ""
    @State private var selectedType: KitType = .SVA
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Código (ej: KIT-SVA-001)", text: $code)
                    .textInputAutocapitalization(.characters)
                
                TextField("Nombre", text: $name)
                
                Picker("Tipo", selection: $selectedType) {
                    ForEach(KitType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }
            .navigationTitle("Nuevo Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task { await createKit() }
                    }
                    .disabled(code.isEmpty || name.isEmpty || isProcessing)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
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
            
            onComplete()
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
        }
    }
}

// MARK: - Stock Alerts Tab

struct StockAlertsTabView: View {
    @State private var lowStock: [KitItemFS] = []
    @State private var expiring: [KitItemFS] = []
    @State private var expired: [KitItemFS] = []
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if lowStock.isEmpty {
                        Text("Sin alertas")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(lowStock) { item in
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.red)
                                
                                VStack(alignment: .leading) {
                                    Text("Stock Bajo")
                                        .font(.headline)
                                    Text("Cantidad: \(Int(item.quantity)) / Min: \(Int(item.min))")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Stock Bajo (\(lowStock.count))")
                }
                
                Section {
                    if expiring.isEmpty {
                        Text("Sin alertas")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(expiring) { item in
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading) {
                                    Text("Caduca Pronto")
                                        .font(.headline)
                                    if let days = item.daysUntilExpiry {
                                        Text("\(days) días")
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Próximos a Caducar (\(expiring.count))")
                }
                
                Section {
                    if expired.isEmpty {
                        Text("Sin items caducados")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(expired) { item in
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                
                                Text("CADUCADO")
                                    .font(.headline)
                            }
                        }
                    }
                } header: {
                    Text("Caducados (\(expired.count))")
                }
            }
            .navigationTitle("Alertas de Stock")
            .task {
                await loadAlerts()
            }
        }
    }
    
    private func loadAlerts() async {
        lowStock = await KitService.shared.getLowStockItems()
        expiring = await KitService.shared.getExpiringItems()
        expired = await KitService.shared.getExpiredItems()
    }
}

// MARK: - Statistics View

struct KitStatisticsView: View {
    @State private var stats = (
        totalKits: 0,
        assignedKits: 0,
        unassignedKits: 0,
        totalItems: 0,
        lowStockItems: 0,
        expiringItems: 0,
        expiredItems: 0
    )
    
    var body: some View {
        NavigationStack {
            List {
                Section("Kits") {
                    StatisticRow(label: "Total de Kits", value: "\(stats.totalKits)")
                    StatisticRow(label: "Asignados", value: "\(stats.assignedKits)", color: .green)
                    StatisticRow(label: "Sin asignar", value: "\(stats.unassignedKits)", color: .orange)
                }
                
                Section("Items") {
                    StatisticRow(label: "Total de Items", value: "\(stats.totalItems)")
                    StatisticRow(label: "Stock Bajo", value: "\(stats.lowStockItems)", color: .red)
                    StatisticRow(label: "Próximos a caducar", value: "\(stats.expiringItems)", color: .orange)
                    StatisticRow(label: "Caducados", value: "\(stats.expiredItems)", color: .red)
                }
            }
            .navigationTitle("Estadísticas")
            .task {
                stats = await KitService.shared.getGlobalStatistics()
            }
        }
    }
}

struct StatisticRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(color)
                .bold()
        }
    }
}

// MARK: - Preview

#Preview {
    KitServiceUsageExampleView()
}








































