//
//  MainTabView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI
import SwiftData 

struct MainTabView: View {
    let currentUser: User

    var body: some View {
        let caps = UIPermissions.userMgmt(currentUser)
        let showAdminTab = UIPermissions.canCreateKits(currentUser)
                         || UIPermissions.canEditThresholds(currentUser)
                         || caps.create || caps.update || caps.delete

        TabView {
            InventoryView(currentUser: currentUser)
                .tabItem { Label("Inventario", systemImage: "shippingbox") }

            if showAdminTab {
                AdminView(currentUser: currentUser)
                    .tabItem { Label("Gestión", systemImage: "gearshape") }
            }

            ProfileView(currentUser: currentUser)
                .tabItem { Label("Perfil", systemImage: "person") }
        }
    }
}

#Preview("MainTab – Programmer") {
    MainTabView(currentUser: PreviewSupport.user("programmer"))
        .modelContainer(PreviewSupport.container)
}

