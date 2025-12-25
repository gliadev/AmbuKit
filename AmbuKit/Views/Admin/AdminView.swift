//
//  AdminView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//


import SwiftUI

// MARK: - AdminView (Firebase)

/// Vista principal de gestión/administración
/// - Crear kits (solo Programador)
/// - Editar umbrales min/max (Programador y Logística)
///
/// **Migración Firebase:**
/// - Usa `UserFS` en lugar de `User` (SwiftData)
/// - Permisos verificados async con `AuthorizationServiceFS`
/// - Operaciones CRUD a través de `KitService`
struct AdminView: View {
    
    // MARK: - Properties
    
    /// Usuario actual de Firebase
    let currentUser: UserFS
    
    // MARK: - State - Permisos
    
    @State private var canCreateKits = false
    @State private var canEditThresholds = false
    @State private var isLoadingPermissions = true
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoadingPermissions {
                    loadingPermissionsView
                } else {
                    adminContent
                }
            }
            .navigationTitle("Gestión")
        }
        .task {
            await loadPermissions()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingPermissionsView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.blue)
            Text("Verificando permisos...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Admin Content
    
    @ViewBuilder
    private var adminContent: some View {
        Form {
            // Sección: Crear Kit (solo Programador)
            if canCreateKits {
                Section {
                    KitCreatorView(currentUser: currentUser)
                } header: {
                    Label("Crear Kit", systemImage: "plus.circle")
                } footer: {
                    Text("Solo los programadores pueden crear nuevos kits.")
                        .font(.caption)
                }
            }
            
            // Sección: Editar Umbrales (Programador y Logística)
            if canEditThresholds {
                Section {
                    ThresholdsEditor(currentUser: currentUser)
                } header: {
                    Label("Umbrales Min/Máx", systemImage: "slider.horizontal.3")
                } footer: {
                    Text("Programadores y Logística pueden ajustar umbrales de stock.")
                        .font(.caption)
                }
            }
            
            // Si no tiene ningún permiso
            if !canCreateKits && !canEditThresholds {
                Section {
                    noPermissionsView
                }
            }
        }
    }
    
    // MARK: - No Permissions View
    
    private var noPermissionsView: some View {
        ContentUnavailableView {
            Label("Sin permisos", systemImage: "lock.shield")
        } description: {
            Text("No tienes permisos para gestionar kits ni umbrales.")
        }
    }
    
    // MARK: - Load Permissions
    
    private func loadPermissions() async {
        isLoadingPermissions = true
        
        async let canCreateTask = AuthorizationServiceFS.canCreateKits(currentUser)
        async let canEditTask = AuthorizationServiceFS.canEditThresholds(currentUser)
        
        canCreateKits = await canCreateTask
        canEditThresholds = await canEditTask
        
        #if DEBUG
        print("📋 AdminView permisos para @\(currentUser.username):")
        print("   - canCreateKits: \(canCreateKits)")
        print("   - canEditThresholds: \(canEditThresholds)")
        #endif
        
        isLoadingPermissions = false
    }
}

// MARK: - KitCreatorView (Subvista privada)

private struct KitCreatorView: View {
    
    let currentUser: UserFS
    
    // MARK: - State - Formulario
    
    @State private var code = ""
    @State private var name = ""
    @State private var selectedType: KitType = .SVB
    @State private var selectedVehicleId: String?
    
    // MARK: - State - Datos
    
    @State private var vehicles: [VehicleFS] = []
    @State private var isLoadingVehicles = true
    
    // MARK: - State - Operación
    
    @State private var isCreating = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Campo: Código
            VStack(alignment: .leading, spacing: 4) {
                Text("Código")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Ej: KIT-SVB-001", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }
            
            // Campo: Nombre
            VStack(alignment: .leading, spacing: 4) {
                Text("Nombre")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Ej: Kit SVB Ambulancia 1", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Picker: Tipo de Kit
            // KitType tiene: SVB, SVAe, SVA, custom
            VStack(alignment: .leading, spacing: 4) {
                Text("Tipo de Kit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("Tipo", selection: $selectedType) {
                    ForEach(KitType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Picker: Vehículo (opcional)
            VStack(alignment: .leading, spacing: 4) {
                Text("Asignar a Vehículo (opcional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if isLoadingVehicles {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Cargando vehículos...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Picker("Vehículo", selection: $selectedVehicleId) {
                        Text("— Sin asignar —").tag(nil as String?)
                        ForEach(vehicles) { vehicle in
                            Text("\(vehicle.code) (\(vehicle.type))")
                                .tag(vehicle.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            // Botón: Crear Kit
            HStack {
                Button {
                    Task { await createKit() }
                } label: {
                    HStack(spacing: 8) {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text("Crear Kit")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.isEmpty || name.isEmpty || isCreating)
            }
            
            // Mensaje de éxito
            if showSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Kit creado correctamente")
                        .foregroundStyle(.green)
                }
                .font(.caption)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Mensaje de error
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                }
                .font(.caption)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.3), value: showSuccess)
        .animation(.easeInOut(duration: 0.3), value: errorMessage)
        .task {
            await loadVehicles()
        }
    }
    
    // MARK: - Load Vehicles
    
    private func loadVehicles() async {
        isLoadingVehicles = true
        vehicles = await VehicleService.shared.getAllVehicles()
        isLoadingVehicles = false
    }
    
    // MARK: - Create Kit
    
    private func createKit() async {
        isCreating = true
        showSuccess = false
        errorMessage = nil
        
        // Guardar valores en variables locales ANTES de limpiar el formulario
        let kitCode = code.uppercased().trimmingCharacters(in: .whitespaces)
        let kitName = name.trimmingCharacters(in: .whitespaces)
        let kitType = selectedType
        let vehicleId = selectedVehicleId
        
        do {
            // Crear kit usando KitService
            _ = try await KitService.shared.createKit(
                code: kitCode,
                name: kitName,
                type: kitType,
                vehicleId: vehicleId,
                actor: currentUser
            )
            
            // Éxito: limpiar formulario
            code = ""
            name = ""
            selectedVehicleId = nil
            showSuccess = true
            
            // Ocultar mensaje de éxito después de 3 segundos
            try? await Task.sleep(for: .seconds(3))
            showSuccess = false
            
        } catch let error as KitServiceError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Error inesperado: \(error.localizedDescription)"
        }
        
        isCreating = false
    }
}

// MARK: - ThresholdsEditor (Subvista privada)

private struct ThresholdsEditor: View {
    
    let currentUser: UserFS
    
    @State private var kits: [KitFS] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    private var filteredKits: [KitFS] {
        guard !searchText.isEmpty else { return kits }
        
        let lowercased = searchText.lowercased()
        return kits.filter {
            $0.code.lowercased().contains(lowercased) ||
            $0.name.lowercased().contains(lowercased)
        }
    }
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else if kits.isEmpty {
                emptyView
            } else {
                kitsListView
            }
        }
        .task {
            await loadKits()
        }
    }
    
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Cargando kits...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Reintentar") {
                Task { await loadKits() }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 16)
    }
    
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.title)
                .foregroundStyle(.secondary)
            
            Text("No hay kits")
                .font(.headline)
            
            Text("Crea tu primer kit en la sección superior.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
    }
    
    private var kitsListView: some View {
        VStack(spacing: 0) {
            if kits.count > 3 {
                TextField("Buscar kit...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.bottom, 8)
            }
            
            ForEach(filteredKits) { kit in
                NavigationLink {
                    ThresholdEditorScreen(kit: kit, currentUser: currentUser)
                } label: {
                    kitRow(kit)
                }
            }
            
            if filteredKits.isEmpty && !searchText.isEmpty {
                Text("No se encontraron kits con '\(searchText)'")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }
    
    private func kitRow(_ kit: KitFS) -> some View {
        HStack(spacing: 12) {
            Image(systemName: kitIcon(for: kit.type))
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(kit.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    Text(kit.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text(kit.type)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
    
    /// KitType: SVB, SVAe, SVA, custom
    private func kitIcon(for typeString: String) -> String {
        switch typeString {
        case "SVA":
            return "cross.case.fill"
        case "SVAe":
            return "cross.case.fill"
        case "SVB":
            return "shippingbox.fill"
        case "custom":
            return "square.grid.2x2.fill"
        default:
            return "shippingbox"
        }
    }
    
    private func loadKits() async {
        isLoading = true
        errorMessage = nil
        kits = await KitService.shared.getAllKits()
        isLoading = false
    }
}

// MARK: - Preview

#if DEBUG
struct AdminView_Previews: PreviewProvider {
    static var previews: some View {
        AdminView(currentUser: previewProgrammer)
            .previewDisplayName("Programador")
    }
    
    static let previewProgrammer = UserFS(
        id: "user_prog",
        uid: "uid_prog",
        username: "admin",
        fullName: "Administrador",
        email: "admin@ambukit.com",
        active: true,
        roleId: "role_programmer",
        baseId: nil
    )
}
#endif
