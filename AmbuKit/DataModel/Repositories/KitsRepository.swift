//
//  KitsRepository.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData

public enum KitsRepositoryError: Error {
    case unauthorizedCreate
    case unauthorizedDelete
    case unauthorizedMove
    case unauthorizedCreateItem
    case unauthorizedUpdateItem
    case unauthorizedDeleteItem
    case unauthorizedUpdateThresholds
}

public struct KitsRepository {
    private let context: ModelContext
    public init(_ context: ModelContext) { self.context = context }



    @discardableResult
    public func create(
        code: String,
        name: String,
        type: KitType,
        status: String = "ok",
        vehicle: Vehicle? = nil,
        actor: User?
    ) throws -> Kit {
        guard AuthorizationService.allowed(.create, on: .kit, for: actor)
        else { throw KitsRepositoryError.unauthorizedCreate }

        let k = Kit(code: code, name: name, type: type, status: status, vehicle: vehicle)
        context.insert(k)
        try context.save()
        AuditService(context).log(.create, entity: .kit, entityId: k.code, actor: actor, details: "Kit created")
        return k
    }


    @discardableResult
    public func unsafeCreate(
        code: String,
        name: String,
        type: KitType,
        status: String = "ok",
        vehicle: Vehicle? = nil
    ) -> Kit {
        let k = Kit(code: code, name: name, type: type, status: status, vehicle: vehicle)
        context.insert(k)
        return k
    }

    public func fetchAll() throws -> [Kit] {
        try context.fetch(FetchDescriptor<Kit>())
    }

 

    public func assign(_ kit: Kit, to vehicle: Vehicle?, actor: User?) throws {
        guard AuthorizationService.allowed(.update, on: .kit, for: actor)
        else { throw KitsRepositoryError.unauthorizedMove }

        kit.vehicle = vehicle
        try context.save()
        AuditService(context).log(.update, entity: .kit, entityId: kit.code, actor: actor, details: "Kit moved to vehicle: \(vehicle?.code ?? "none")")
    }


    
    @discardableResult
    public func addItem(
        to kit: Kit,
        catalogItem: CatalogItem,
        qty: Double,
        min: Double,
        max: Double? = nil,
        expiry: Date? = nil,
        lot: String? = nil,
        notes: String? = nil,
        actor: User?
    ) throws -> KitItem {
        guard actor == nil || AuthorizationService.allowed(.create, on: .kitItem, for: actor)
        else { throw KitsRepositoryError.unauthorizedCreateItem }

        let item = KitItem(
            quantity: qty,
            min: min,
            max: max,
            expiry: expiry,
            lot: lot,
            notes: notes,
            catalogItem: catalogItem,
            kit: kit
        )

        context.insert(item)
        kit.items.append(item)
        try context.save()
        AuditService(context).log(.create, entity: .kitItem, entityId: "\(kit.code)::\(catalogItem.code)", actor: actor, details: "qty=\(qty)")
        return item
    }

    
    public func updateThresholds(_ item: KitItem, min: Double? = nil, max: Double? = nil, actor: User?) throws {
        guard let kind = actor?.role?.kind, kind == .programmer || kind == .logistics
        else { throw KitsRepositoryError.unauthorizedUpdateThresholds }

        if let m = min { item.min = m }
        item.max = max
        try context.save()
        AuditService(context).log(.update, entity: .kitItem, entityId: item.catalogItem?.code ?? "unknown", actor: actor, details: "thresholds min=\(min?.description ?? "-") max=\(max?.description ?? "-")")
    }

    public func updateItem(_ item: KitItem, setQuantity qty: Double? = nil, setExpiry expiry: Date? = nil, setNotes notes: String? = nil, actor: User?) throws {
        guard AuthorizationService.allowed(.update, on: .kitItem, for: actor)
        else { throw KitsRepositoryError.unauthorizedUpdateItem }

        if let q = qty { item.quantity = q }
        if let e = expiry { item.expiry = e }
        if let n = notes { item.notes = n }
        try context.save()
        AuditService(context).log(.update, entity: .kitItem, entityId: item.catalogItem?.code ?? "unknown", actor: actor, details: "qty=\(qty ?? item.quantity)")
    }

    public func deleteItem(_ item: KitItem, actor: User?) throws {
        guard AuthorizationService.allowed(.delete, on: .kitItem, for: actor)
        else { throw KitsRepositoryError.unauthorizedDeleteItem }

        let id = item.catalogItem?.code ?? "unknown"
        context.delete(item)
        try context.save()
        AuditService(context).log(.delete, entity: .kitItem, entityId: id, actor: actor, details: "kit item removed")
    }

   
    public func delete(_ kit: Kit, actor: User?) throws {
        guard AuthorizationService.allowed(.delete, on: .kit, for: actor)
        else { throw KitsRepositoryError.unauthorizedDelete }

        let code = kit.code
        context.delete(kit)
        try context.save()
        AuditService(context).log(.delete, entity: .kit, entityId: code, actor: actor, details: "Kit deleted")
    }
}

