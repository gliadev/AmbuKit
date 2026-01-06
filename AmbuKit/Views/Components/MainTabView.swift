//
//  MainTabView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//
//  ACTUALIZADO TAREA 16.7: Añadido tab de Estadísticas
//  TAREA 16.9: Mejoras visuales - Tab bar colorida + MoreView con tarjetas
//  TAREA 16.9: Tab bar colorida + MoreView con tarjetas
//

import SwiftUI

// MARK: - MainTabView

struct MainTabView: View {
    
    // MARK: - Properties
    
    let currentUser: UserFS
    
    // MARK: - Environment
    
    @EnvironmentObject private var appState: AppState
    
    // MARK: - State
    
    @State private var selectedTab: Int = 0
    @State private var showAdminTab = false
    @State private var roleKind: RoleKind?
    @State private var isLoading = true
    @State private var enrichedUser: UserFS?
    @State private var alertCount: Int = 0
    
    // MARK: - Computed
    
    private var userForViews: UserFS {
        enrichedUser ?? currentUser
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else {
                mainTabView
            }
        }
        .task {
            await loadInitialData()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Cargando...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Main Tab View (Standard TabView)
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: INVENTARIO
            InventoryView(currentUser: userForViews)
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("Inventario")
                }
                .tag(0)
            
            // Tab 2: VEHÍCULOS
            VehiclesView(currentUser: userForViews)
                .tabItem {
                    Image(systemName: "car.fill")
                    Text("Vehículos")
                }
                .tag(1)
            
            // Tab 3: ALERTAS
            AlertsView(currentUser: userForViews)
                .tabItem {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Alertas")
                }
                .tag(2)
                .badge(alertCount > 0 ? alertCount : 0)
            
            // Tab 4: ESTADÍSTICAS
            StatisticsView(currentUser: userForViews)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Stats")
                }
                .tag(3)
            
            // Tab 5: MÁS
            MoreMenuView(currentUser: userForViews, showAdminTab: showAdminTab)
                .tabItem {
                    Image(systemName: "ellipsis.circle.fill")
                    Text("Más")
                }
                .tag(4)
        }
        .tint(tintColorForTab)
        .onAppear {
            // Configurar colores de la tab bar
            configureTabBarAppearance()
        }
        .task {
            await loadAlertCount()
        }
    }
    
    // MARK: - Tab Tint Color
    
    private var tintColorForTab: Color {
        switch selectedTab {
        case 0: return .blue      // Inventario
        case 1: return .green     // Vehículos
        case 2: return .orange    // Alertas
        case 3: return .purple    // Stats
        case 4: return .gray      // Más
        default: return .blue
        }
    }
    
    // MARK: - Configure Tab Bar
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // MARK: - Load Data
    
    private func loadInitialData() async {
        isLoading = true
        await loadRelatedData()
        await calculatePermissions()
        isLoading = false
    }
    
    private func loadRelatedData() async {
        var user = currentUser
        
        if let roleId = currentUser.roleId {
            if let role = await PolicyService.shared.getRole(id: roleId) {
                user.role = role
                roleKind = role.kind
            }
        }
        
        if let baseId = currentUser.baseId {
            if let base = await BaseService.shared.getBase(id: baseId) {
                user.base = base
            }
        }
        
        enrichedUser = user
    }
    
    private func calculatePermissions() async {
        let user = enrichedUser ?? currentUser
        
        let canCreateKits = await AuthorizationServiceFS.canCreateKits(user)
        let canCreateVehicles = await AuthorizationServiceFS.canCreateVehicles(user)
        let canEditThresholds = await AuthorizationServiceFS.canEditThresholds(user)
        let canManageUsers = await AuthorizationServiceFS.canManageUsers(user)
        
        showAdminTab = canCreateKits || canCreateVehicles || canEditThresholds || canManageUsers
    }
    
    private func loadAlertCount() async {
        let lowStock = await KitService.shared.getLowStockItems()
        let expiring = await KitService.shared.getExpiringItems()
        let expired = await KitService.shared.getExpiredItems()
        alertCount = lowStock.count + expiring.count + expired.count
    }
}

// MARK: - More Menu View

struct MoreMenuView: View {
    let currentUser: UserFS
    let showAdminTab: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    userHeader
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        if showAdminTab {
                            NavigationLink {
                                AdminView(currentUser: currentUser)
                            } label: {
                                MenuCard(
                                    title: "Gestión",
                                    subtitle: "Administración",
                                    icon: "gearshape.fill",
                                    color: .blue
                                )
                            }
                        }
                        
                        NavigationLink {
                            ProfileView(currentUser: currentUser)
                        } label: {
                            MenuCard(
                                title: "Mi Perfil",
                                subtitle: "Info personal",
                                icon: "person.fill",
                                color: .purple
                            )
                        }
                        
                        MenuCard(
                            title: "Ajustes",
                            subtitle: "Preferencias",
                            icon: "slider.horizontal.3",
                            color: .gray
                        )
                        .opacity(0.5)
                        
                        MenuCard(
                            title: "Ayuda",
                            subtitle: "Soporte",
                            icon: "questionmark.circle.fill",
                            color: .teal
                        )
                        .opacity(0.5)
                    }
                    .padding(.horizontal)
                    
                    versionInfo
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Más")
        }
    }
    
    private var userHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Text(currentUser.fullName.prefix(1).uppercased())
                    .font(.title.bold())
                    .foregroundStyle(roleColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(currentUser.fullName)
                    .font(.headline)
                
                Text("@\(currentUser.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let role = currentUser.role {
                    Text(role.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(roleColor.opacity(0.15))
                        .foregroundStyle(roleColor)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    private var roleColor: Color {
        guard let role = currentUser.role else { return .blue }
        switch role.kind {
        case .programmer: return .blue
        case .logistics: return .orange
        case .sanitary: return .green
        }
    }
    
    private var versionInfo: some View {
        VStack(spacing: 4) {
            Text("AmbuKit")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Versión 1.0.0 (TFG 2025)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Text("Desarrollado por Adolfo")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 32)
    }
}

// MARK: - Menu Card

struct MenuCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview("MainTabView") {
    var user = UserFS(
        id: "1", uid: "uid1", username: "admin",
        fullName: "Admin User", email: "admin@test.com",
        active: true, roleId: "role_programmer", baseId: nil
    )
    user.role = RoleFS(id: "role_programmer", kind: .programmer, displayName: "Programador")
    
    return MainTabView(currentUser: user)
        .environmentObject(AppState.shared)
}
