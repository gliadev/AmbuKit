//
//  CatalogServiceUsageExample.swift
//  AmbuKit
//
//  Created by Adolfo on 17/11/25.
//


import SwiftUI

/// Vista de ejemplo mostrando todos los casos de uso de CatalogService
/// Incluye tabs para Items, Categorías y Unidades de Medida
struct CatalogServiceUsageExample: View {
    @StateObject private var service = CatalogService.shared
    
    // Usuario actual (en producción vendría de AuthService)
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
            // Tab 1: Items del Catálogo
            CatalogItemsListView(service: service, currentUser: $currentUser)
                .tabItem {
                    Label("Items", systemImage: "list.bullet")
                }
            
            // Tab 2: Categorías
            CategoriesListView(service: service, currentUser: $currentUser)
                .tabItem {
                    Label("Categorías", systemImage: "folder")
                }
            
            // Tab 3: Unidades de Medida
            UnitsListView(service: service, currentUser: $currentUser)
                .tabItem {
                    Label("Unidades", systemImage: "ruler")
                }
            
            // Tab 4: Estadísticas
            CatalogStatsView(service: service)
                .tabItem {
                    Label("Estadísticas", systemImage: "chart.bar")
                }
        }
    }
}

// MARK: - Tab 1: Items del Catálogo

struct CatalogItemsListView: View {
    @ObservedObject var service: CatalogService
    @Binding var currentUser: UserFS?
    
    @State private var items: [CatalogItemFS] = []
    @State private var searchText = ""
    @State private var showCriticalOnly = false
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Filtros
                HStack {
                    TextField("Buscar...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    
                    Toggle("Críticos", isOn: $showCriticalOnly)
                }
                .padding()
                
                // Lista
                List(filteredItems) { item in
                    CatalogItemRow(item: item)
                }
            }
            .navigationTitle("Items del Catálogo")
            .toolbar {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Nuevo", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                Text("Sheet para crear item")
            }
            .task {
                items = await service.getAllItems()
            }
        }
    }
    
    private var filteredItems: [CatalogItemFS] {
        var result = items
        
        if showCriticalOnly {
            result = result.filter { $0.critical }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.code.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
}

struct CatalogItemRow: View {
    let item: CatalogItemFS
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.code)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if item.critical {
                    Text("⚠️ CRÍTICO")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            
            Text(item.name)
                .font(.headline)
            
            if let desc = item.itemDescription {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tab 2: Categorías

struct CategoriesListView: View {
    @ObservedObject var service: CatalogService
    @Binding var currentUser: UserFS?
    
    @State private var categories: [CategoryFS] = []
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List(categories) { category in
                HStack {
                    if let icon = category.icon {
                        Image(systemName: icon)
                            .foregroundColor(.blue)
                            .frame(width: 30)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(category.name)
                            .font(.headline)
                        Text(category.code)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Categorías")
            .toolbar {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Nueva", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                Text("Sheet para crear categoría")
            }
            .task {
                categories = await service.getAllCategories()
            }
        }
    }
}

// MARK: - Tab 3: Unidades

struct UnitsListView: View {
    @ObservedObject var service: CatalogService
    @Binding var currentUser: UserFS?
    
    @State private var units: [UnitOfMeasureFS] = []
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List(units) { unit in
                HStack {
                    Text(unit.symbol)
                        .font(.headline)
                        .frame(width: 50, alignment: .leading)
                    
                    Text(unit.name)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Unidades de Medida")
            .toolbar {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Nueva", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                Text("Sheet para crear unidad")
            }
            .task {
                units = await service.getAllUOMs()
            }
        }
    }
}

// MARK: - Tab 4: Estadísticas

struct CatalogStatsView: View {
    @ObservedObject var service: CatalogService
    
    @State private var stats = (totalItems: 0, criticalItems: 0, categories: 0, uoms: 0)
    
    var body: some View {
        NavigationStack {
            List {
                Section("Items del Catálogo") {
                    HStack {
                        Text("Total de Items")
                        Spacer()
                        Text("\(stats.totalItems)")
                            .bold()
                    }
                    
                    HStack {
                        Text("Items Críticos")
                        Spacer()
                        Text("\(stats.criticalItems)")
                            .foregroundColor(.red)
                            .bold()
                    }
                }
                
                Section("Configuración") {
                    HStack {
                        Text("Categorías")
                        Spacer()
                        Text("\(stats.categories)")
                            .bold()
                    }
                    
                    HStack {
                        Text("Unidades de Medida")
                        Spacer()
                        Text("\(stats.uoms)")
                            .bold()
                    }
                }
            }
            .navigationTitle("Estadísticas")
            .task {
                stats = await service.getStatistics()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CatalogServiceUsageExample()
}
