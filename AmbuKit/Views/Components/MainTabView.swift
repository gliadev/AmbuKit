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
    
    // MARK: - State

    @State private var selectedTab: AppTab = .inventory
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
    
    // MARK: - Subviews

    private var loadingView: some View {
        MainTabLoadingView()
    }

    private var mainTabView: some View {
        MainTabContentView(
            userForViews: userForViews,
            showAdminTab: showAdminTab,
            selectedTab: $selectedTab,
            alertCount: alertCount
        )
        .task {
            await loadAlertCount()
        }
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

// MARK: - MainTabLoadingView

private struct MainTabLoadingView: View {
    var body: some View {
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
}

// MARK: - MainTabContentView

private struct MainTabContentView: View {

    let userForViews: UserFS
    let showAdminTab: Bool
    @Binding var selectedTab: AppTab
    let alertCount: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Inventario", systemImage: "shippingbox.fill", value: AppTab.inventory) {
                InventoryView(currentUser: userForViews)
            }
            Tab("Vehículos", systemImage: "car.fill", value: AppTab.vehicles) {
                VehiclesView(currentUser: userForViews)
            }
            Tab("Alertas", systemImage: "exclamationmark.triangle.fill", value: AppTab.alerts) {
                AlertsView(currentUser: userForViews)
            }
            .badge(alertCount > 0 ? alertCount : 0)
            Tab("Stats", systemImage: "chart.bar.fill", value: AppTab.statistics) {
                StatisticsView(currentUser: userForViews)
            }
            Tab("Más", systemImage: "ellipsis.circle.fill", value: AppTab.more) {
                MoreMenuView(currentUser: userForViews, showAdminTab: showAdminTab)
            }
        }
        .tint(tintColor)
    }

    private var tintColor: Color {
        switch selectedTab {
        case .inventory:  return .blue
        case .vehicles:   return .green
        case .alerts:     return .orange
        case .statistics: return .purple
        case .more:       return .gray
        }
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
