//
//  VehicleManagementView.swift
//  AmbuKit
//
//  Created by Adolfo on 17/11/25.
//  Ejemplo completo de cómo usar VehicleService desde SwiftUI

import SwiftUI

/// Vista de ejemplo que demuestra el uso de VehicleService
@MainActor
struct VehicleManagementView: View {
    @State private var vehicles: [VehicleFS] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCreateSheet = false
    
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
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Cargando vehículos...")
                } else if vehicles.isEmpty {
                    ContentUnavailableView(
                        "Sin vehículos",
                        systemImage: "car.fill",
                        description: Text("No hay vehículos registrados")
                    )
                } else {
                    vehiclesList
                }
            }
            .navigationTitle("Vehículos")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingCreateSheet = true }) {
                        Label("Nuevo", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateVehicleSheet(
                    currentUser: currentUser,
                    onCreate: { newVehicle in
                        vehicles.append(newVehicle)
                    }
                )
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .task {
                await loadVehicles()
            }
        }
    }
    
    private var vehiclesList: some View {
        List {
            ForEach(vehicles) { vehicle in
                VehicleRow(vehicle: vehicle)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                await deleteVehicle(vehicle)
                            }
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
            }
        }
        .refreshable {
            await loadVehicles()
        }
    }
    
    /// EJEMPLO 1: Obtener todos los vehículos
    private func loadVehicles() async {
        isLoading = true
        errorMessage = nil
        
        vehicles = await VehicleService.shared.getAllVehicles()
        
        isLoading = false
    }
    
    /// EJEMPLO 2: Eliminar vehículo con manejo de errores
    private func deleteVehicle(_ vehicle: VehicleFS) async {
        guard let vehicleId = vehicle.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await VehicleService.shared.delete(
                vehicleId: vehicleId,
                actor: currentUser
            )
            
            vehicles.removeAll { $0.id == vehicleId }
            
        } catch let error as VehicleServiceError {
            switch error {
            case .unauthorized(let message):
                errorMessage = message
            case .hasKits(let message):
                errorMessage = message
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = "Error inesperado"
        }
        
        isLoading = false
    }
}

// MARK: - Create Vehicle Sheet

struct CreateVehicleSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let currentUser: UserFS?
    let onCreate: (VehicleFS) -> Void
    
    @State private var code = ""
    @State private var plate = ""
    @State private var selectedType = "SVA Avanzada"
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    let vehicleTypes = ["SVB Básica", "SVAe Enfermerizada", "SVA Avanzada"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Información del Vehículo") {
                    TextField("Código (ej: SVA-2401)", text: $code)
                        .textInputAutocapitalization(.characters)
                    
                    TextField("Matrícula (opcional)", text: $plate)
                        .textInputAutocapitalization(.characters)
                    
                    Picker("Tipo", selection: $selectedType) {
                        ForEach(vehicleTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Nuevo Vehículo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task {
                            await createVehicle()
                        }
                    }
                    .disabled(code.isEmpty || isCreating)
                }
            }
            .disabled(isCreating)
        }
    }
    
    /// EJEMPLO 3: Crear nuevo vehículo
    private func createVehicle() async {
        isCreating = true
        errorMessage = nil
        
        do {
            let newVehicle = try await VehicleService.shared.create(
                code: code.uppercased(),
                plate: plate.isEmpty ? nil : plate.uppercased(),
                type: selectedType,
                baseId: nil,
                actor: currentUser
            )
            
            onCreate(newVehicle)
            dismiss()
            
        } catch let error as VehicleServiceError {
            switch error {
            case .unauthorized(let msg):
                errorMessage = msg
            case .duplicateCode(let msg):
                errorMessage = msg
            case .invalidData(let msg):
                errorMessage = msg
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = "Error inesperado"
        }
        
        isCreating = false
    }
}

// MARK: - Vehicle Row

struct VehicleRow: View {
    let vehicle: VehicleFS
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "ambulance.fill")
                    .foregroundStyle(.blue)
                
                Text(vehicle.code)
                    .font(.headline)
                
                Spacer()
                
                if let plate = vehicle.plate, !plate.isEmpty {
                    Text(plate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(vehicle.type)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                Label(
                    vehicle.hasBase ? "Con base" : "Sin base",
                    systemImage: vehicle.hasBase ? "mappin.circle.fill" : "mappin.slash.circle"
                )
                .font(.caption)
                .foregroundStyle(vehicle.hasBase ? .green : .orange)
                
                Spacer()
                
                // Eliminado vehicle.kitCountText - no existe en VehicleFS
                Text("\(vehicle.kitIds.count) kits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VehicleManagementView()
}

/*
 EJEMPLOS ADICIONALES DE USO:
 
 // EJEMPLO 4: Buscar por código
 if let vehicle = await VehicleService.shared.getVehicleByCode("SVA-2401") {
     print("Encontrado: \(vehicle.displayName)")
 }
 
 // EJEMPLO 5: Obtener vehículos de una base
 let vehicles = await VehicleService.shared.getVehiclesByBase(baseId: "base_bilbao1")
 
 // EJEMPLO 6: Actualizar vehículo
 var vehicle = await VehicleService.shared.getVehicle(id: "vehicle_id")
 vehicle?.plate = "9999-ZZZ"
 try await VehicleService.shared.update(vehicle: vehicle!, actor: currentUser)
 
 // EJEMPLO 7: Asignar a base
 try await VehicleService.shared.assignToBase(
     vehicleId: "vehicle_id",
     baseId: "base_bilbao1",
     actor: currentUser
 )
 
 // EJEMPLO 8: Obtener estadísticas
 let stats = await VehicleService.shared.getStatistics()
 print("Total: \(stats.total), Con base: \(stats.withBase)")
 */

#Preview {
    VehicleManagementView()
}








































