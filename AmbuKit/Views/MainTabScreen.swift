//
//  MainTabScreen.swift
//  AmbuKit
//
//  Created by Adolfo on 3/12/25.
//
import SwiftUI
import SwiftData

/// Vista principal con tabs para usuarios autenticados (Firebase)
///
/// **Responsabilidades:**
/// - Recibir UserFS de Firebase
/// - Cargar datos relacionados (Role, Base)
/// - Calcular permisos usando AuthorizationServiceFS
/// - Crear User temporal para vistas SwiftData existentes
/// - Mostrar tabs según permisos del usuario
///
/// **Bridge Pattern:**
/// Esta vista actúa como puente entre Firebase (UserFS) y las vistas
/// existentes de SwiftData (User). Se eliminará cuando todas las vistas
/// estén migradas a Firebase (TAREA 17).
struct MainTabScreen: View {
    
    // MARK: - Properties
    
    let currentUser: UserFS
    
    // MARK: - Environment
    
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    
    // MARK: - State
    
    /// Usuario enriquecido con datos relacionados cargados
    @State private var enrichedUser: UserFS?
    
    /// Usuario temporal de SwiftData para vistas existentes
    @State private var swiftDataUser: User?
    
    /// Estado de carga
    @State private var isLoading = true
    
    /// Error de carga
    @State private var loadError: String?
    
    /// Mostrar tab de administración
    @State private var showAdminTab = false
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = loadError {
                errorView(message: error)
            } else if let user = swiftDataUser {
                mainTabContent(user: user)
            } else {
                errorView(message: "No se pudo cargar el usuario")
            }
        }
        .task {
            await setupBridge()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.blue)
            
            Text("Preparando interfaz...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Reintentar") {
                Task { await setupBridge() }
            }
            .buttonStyle(.bordered)
            
            Button("Cerrar sesión", role: .destructive) {
                Task { await appState.signOut() }
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Main Tab Content
    
    @ViewBuilder
    private func mainTabContent(user: User) -> some View {
        TabView {
            // Tab: Inventario (siempre visible)
            InventoryView(currentUser: user)
                .tabItem {
                    Label("Inventario", systemImage: "shippingbox")
                }
            
            // Tab: Gestión (solo si tiene permisos)
            if showAdminTab {
                AdminView(currentUser: user)
                    .tabItem {
                        Label("Gestión", systemImage: "gearshape")
                    }
            }
            
            // Tab: Perfil (siempre visible)
            ProfileView(currentUser: user)
                .tabItem {
                    Label("Perfil", systemImage: "person")
                }
        }
    }
    
    // MARK: - Setup Bridge
    
    /// Configura el bridge entre Firebase y SwiftData
    private func setupBridge() async {
        isLoading = true
        loadError = nil
        
        do {
            // 1. Cargar datos relacionados (role, base)
            await loadRelatedData()
            
            // 2. Calcular permisos usando AuthorizationServiceFS
            await calculatePermissions()
            
            // 3. Crear User temporal para vistas SwiftData
            try createTemporaryUser()
            
            print("✅ Bridge configurado correctamente")
            
        } catch {
            loadError = error.localizedDescription
            print("❌ Error configurando bridge: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Load Related Data
    
    /// Carga los datos relacionados del usuario (role, base) desde Firestore
    private func loadRelatedData() async {
        var user = currentUser
        
        // Cargar Role si tiene roleId
        if let roleId = currentUser.roleId {
            if let role = await PolicyService.shared.getRole(id: roleId) {
                user.role = role
                print("📋 Role cargado: \(role.displayName) (\(role.kind.rawValue))")
            } else {
                print("⚠️ Role no encontrado: \(roleId)")
            }
        }
        
        // Cargar Base si tiene baseId
        if let baseId = currentUser.baseId {
            if let base = await BaseService.shared.getBase(id: baseId) {  // ✅ Corregido
                user.base = base
                print("🏥 Base cargada: \(base.name)")
            } else {
                print("⚠️ Base no encontrada: \(baseId)")
            }
        }
        
        enrichedUser = user
    }
    
    // MARK: - Calculate Permissions
    
    /// Calcula los permisos del usuario usando AuthorizationServiceFS
    private func calculatePermissions() async {
        let user = enrichedUser ?? currentUser
        
        // Verificar permisos de administración
        let canCreateKits = await AuthorizationServiceFS.allowed(.create, on: .kit, for: user)
        let canManageUsers = await AuthorizationServiceFS.allowed(.create, on: .user, for: user)
        let canUpdateUsers = await AuthorizationServiceFS.allowed(.update, on: .user, for: user)
        let canDeleteUsers = await AuthorizationServiceFS.allowed(.delete, on: .user, for: user)
        
        // Verificar si puede editar umbrales (programmer o logistics)
        let isProgrammer = await AuthorizationServiceFS.isProgrammer(user)
        let isLogistics = await AuthorizationServiceFS.isLogistics(user)
        let canEditThresholds = isProgrammer || isLogistics
        
        // Mostrar tab de admin si tiene algún permiso de gestión
        showAdminTab = canCreateKits || canEditThresholds || canManageUsers || canUpdateUsers || canDeleteUsers
        
        #if DEBUG
        print("📋 Permisos calculados para @\(user.username):")
        print("   - Rol: \(user.role?.kind.rawValue ?? "sin rol")")
        print("   - canCreateKits: \(canCreateKits)")
        print("   - canEditThresholds: \(canEditThresholds)")
        print("   - canManageUsers: \(canManageUsers)")
        print("   - showAdminTab: \(showAdminTab)")
        #endif
    }
    
    // MARK: - Create Temporary User
    
    /// Crea un User temporal de SwiftData para compatibilidad con vistas existentes
    /// - Throws: BridgeError si no se puede crear el usuario
    private func createTemporaryUser() throws {
        let user = enrichedUser ?? currentUser
        
        // Crear Role temporal si existe
        var tempRole: Role? = nil
        if let roleFS = user.role {
            tempRole = Role(
                kind: roleFS.kind,
                displayName: roleFS.displayName
            )
        }
        
        // Crear Base temporal si existe
        var tempBase: Base? = nil
        if let baseFS = user.base {
            tempBase = Base(
                code: baseFS.code,
                name: baseFS.name,
                location: baseFS.address
            )
        }
        
        // Crear User temporal (NO se inserta en el ModelContext)
        let tempUser = User(
            username: user.username,
            fullName: user.fullName,
            active: user.active,
            role: tempRole,
            base: tempBase
        )
        
        swiftDataUser = tempUser
        
        print("✅ User temporal creado: @\(tempUser.username)")
        print("   - Role: \(tempUser.role?.displayName ?? "nil")")
        print("   - Base: \(tempUser.base?.name ?? "nil")")
    }
}

// MARK: - Bridge Error

extension MainTabScreen {
    enum BridgeError: LocalizedError {
        case userCreationFailed
        case roleLoadFailed(String)
        case baseLoadFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .userCreationFailed:
                return "No se pudo crear el usuario temporal"
            case .roleLoadFailed(let id):
                return "No se pudo cargar el rol: \(id)"
            case .baseLoadFailed(let id):
                return "No se pudo cargar la base: \(id)"
            }
        }
    }
}

// MARK: - Preview

#Preview("MainTabScreen - Programmer") {
    // Crear usuario de prueba con rol
    var testUser = UserFS(
        id: "test_id",
        uid: "test_uid",
        username: "programmer",
        fullName: "Test Programmer",
        email: "programmer@test.com",
        active: true,
        roleId: "role_programmer",
        baseId: nil
    )
    testUser.role = RoleFS(
        id: "role_programmer",
        kind: .programmer,
        displayName: "Programador"
    )
    
    return MainTabScreen(currentUser: testUser)
        .environmentObject(AppState.shared)
        .modelContainer(PreviewSupport.container)
}

#Preview("MainTabScreen - Sanitary") {
    var testUser = UserFS(
        id: "test_id",
        uid: "test_uid",
        username: "sanitario",
        fullName: "Test Sanitario",
        email: "sanitario@test.com",
        active: true,
        roleId: "role_sanitary",
        baseId: nil
    )
    testUser.role = RoleFS(
        id: "role_sanitary",
        kind: .sanitary,
        displayName: "Sanitario"
    )
    
    return MainTabScreen(currentUser: testUser)
        .environmentObject(AppState.shared)
        .modelContainer(PreviewSupport.container)
}
