//
//  MoreMenuView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

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
        currentUser.role?.kind.color ?? .blue
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
