//
//  SeedDataLoader.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//
import Foundation
import SwiftData
public struct SeedDataLoader { public static func runIfNeeded(context: ModelContext) throws { let existing = try context.fetch(FetchDescriptor<Role>()) ; if !existing.isEmpty { return } ; let basesRepo = BasesRepository(context) ; let vehiclesRepo = VehiclesRepository(context) ; let kitsRepo = KitsRepository(context) ; let catalogRepo = CatalogRepository(context) ; let policiesRepo = PoliciesRepository(context) ; let usersRepo = UsersRepository(context)
    // Roles
    let programmer = policiesRepo.createRole(.programmer, name: "Programador")
    let logistics = policiesRepo.createRole(.logistics, name: "Logística")
    let sanitary = policiesRepo.createRole(.sanitary, name: "Sanitario")
    // Políticas explícitas
    // sanitary — control de stock: solo update de KitItem + lectura
    _ = policiesRepo.grant(sanitary, entity: .kit, create: false, read: true, update: false, delete: false)
    _ = policiesRepo.grant(sanitary, entity: .kitItem, create: false, read: true, update: true, delete: false)
    _ = policiesRepo.grant(sanitary, entity: .catalogItem, create: false, read: true, update: false, delete: false)
    _ = policiesRepo.grant(sanitary, entity: .vehicle, create: false, read: true, update: false, delete: false)
    _ = policiesRepo.grant(sanitary, entity: .base, create: false, read: true, update: false, delete: false)
    _ = policiesRepo.grant(sanitary, entity: .category, create: false, read: true, update: false, delete: false)
    _ = policiesRepo.grant(sanitary, entity: .unit, create: false, read: true, update: false, delete: false)
    _ = policiesRepo.grant(sanitary, entity: .audit, create: false, read: false, update: false, delete: false)
    _ = policiesRepo.grant(sanitary, entity: .user, create: false, read: false, update: false, delete: false)
    // logistics — NO crear kits; NO crear/eliminar usuarios; resto permitido
    _ = policiesRepo.grant(logistics, entity: .kit, create: false, read: true, update: true, delete: true)
    _ = policiesRepo.grant(logistics, entity: .kitItem, create: true, read: true, update: true, delete: true)
    _ = policiesRepo.grant(logistics, entity: .catalogItem, create: true, read: true, update: true, delete: true)
    _ = policiesRepo.grant(logistics, entity: .vehicle, create: true, read: true, update: true, delete: true)
    _ = policiesRepo.grant(logistics, entity: .base, create: true, read: true, update: true, delete: true)
    _ = policiesRepo.grant(logistics, entity: .category, create: true, read: true, update: true, delete: true)
    _ = policiesRepo.grant(logistics, entity: .unit, create: true, read: true, update: true, delete: true)
    _ = policiesRepo.grant(logistics, entity: .audit, create: false, read: true, update: false, delete: false)
    _ = policiesRepo.grant(logistics, entity: .user, create: false, read: true, update: true, delete: false)
    // programmer — admin total (sin policies necesarias)
    // UOM & Categorías
    let u = catalogRepo.createUOM(symbol: "u", name: "unidad") ; _ = catalogRepo.createUOM(symbol: "ml", name: "mililitro") ; _ = catalogRepo.createUOM(symbol: "mg", name: "miligramo")
    let catMeds = catalogRepo.createCategory(code: "CAT-MED", name: "Farmacia", icon: "pills") ; _ = catalogRepo.createCategory(code: "CAT-CUR", name: "Curas", icon: "bandage") ; _ = catalogRepo.createCategory(code: "CAT-TRA", name: "Trauma", icon: "bolt") ; _ = catalogRepo.createCategory(code: "CAT-HEM", name: "Hemostasia", icon: "drop") ; _ = catalogRepo.createCategory(code: "CAT-OX", name: "Oxígeno", icon: "lungs")
    // Catálogo crítico con min/max por defecto
    let adrenalina = catalogRepo.createItem(code: "MED-ADR-1MG", name: "Adrenalina 1 mg/ml amp.", critical: true, minStock: 2, maxStock: 8, category: catMeds, uom: u)
    let midazolam = catalogRepo.createItem(code: "MED-MDZ-5MG", name: "Midazolam 5 mg/ml amp.", critical: true, minStock: 4, maxStock: 10, category: catMeds, uom: u)
    let ketamina = catalogRepo.createItem(code: "MED-KET-50MG", name: "Ketamina 50 mg/ml amp.", critical: true, minStock: 2, maxStock: 6, category: catMeds, uom: u)
    let fentanilo = catalogRepo.createItem(code: "MED-FEN-0_05MG",name: "Fentanilo 0,05 mg/ml amp.",critical: true, minStock: 4, maxStock: 10, category: catMeds, uom: u)
    let morfina = catalogRepo.createItem(code: "MED-MOR-10MG", name: "Morfina 10 mg/ml amp.", critical: true, minStock: 4, maxStock: 10, category: catMeds, uom: u)
    _ = (adrenalina, midazolam, ketamina, fentanilo, morfina)
    // Bases & Vehículos
    let b1 = basesRepo.create(code: "2401-BIL-1", name: "Bilbao 1", location: "Bilbao") ; let b2 = basesRepo.create(code: "2402-BIL-2", name: "Bilbao 2", location: "Bilbao")
    let vSVA1 = vehiclesRepo.create(code: "VHC-SVA-01", type: "SVA", plate: "1234-ABC", base: b1) ; _ = vehiclesRepo.create(code: "VHC-SVB-01", type: "SVB", plate: "5678-DEF", base: b2)
    // Kits e ítems (seed sin control de permisos para crear kits)
    _ = kitsRepo.unsafeCreate(code: "KIT-SVA-01", name: "SVA Principal", type: .SVA, vehicle: vSVA1)
    let ampulario = kitsRepo.unsafeCreate(code: "KIT-AMP-01", name: "Ampulario SVA", type: .SVA, vehicle: vSVA1)
    _ = try kitsRepo.addItem(to: ampulario, catalogItem: adrenalina, qty: 4, min: 2, max: 8, actor: nil)
    _ = try kitsRepo.addItem(to: ampulario, catalogItem: midazolam, qty: 6, min: 4, max: 10, actor: nil)
    _ = try kitsRepo.addItem(to: ampulario, catalogItem: ketamina, qty: 2, min: 2, max: 6, actor: nil)
    _ = try kitsRepo.addItem(to: ampulario, catalogItem: fentanilo, qty: 4, min: 4, max: 10, actor: nil)
    _ = try kitsRepo.addItem(to: ampulario, catalogItem: morfina, qty: 4, min: 4, max: 10, actor: nil)
    // Usuarios (seed unsafeCreate)
    _ = usersRepo.unsafeCreate(username: "programmer", fullName: "Programador", role: programmer, base: b1)
    _ = usersRepo.unsafeCreate(username: "log.bilbao", fullName: "Logística Bilbao", role: logistics, base: b1)
    _ = usersRepo.unsafeCreate(username: "san.bilbao", fullName: "Sanitario Bilbao", role: sanitary, base: b1)
    try context.save()

#if DEBUG
    //let itemsCount = try context.fetchCount(FetchDescriptor<KitItem>())
    //assert(itemsCount > 0, "SeedDataLoader: no se crearon KitItem")
    print("⚠️ SeedDataLoader ejecutado (validación desactivada temporalmente)")
#endif
    
    }
}

