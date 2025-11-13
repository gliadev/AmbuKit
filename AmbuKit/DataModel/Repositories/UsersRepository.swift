//
//  UsersRepository.swift
//  AmbuKit
//
//  Created by Adolfo on 11/11/25.
//

import Foundation
import SwiftData

public enum UsersRepositoryError: Error {
    case unauthorizedCreate, unauthorizedDelete
}

public struct UsersRepository {
    private let context: ModelContext
    public init(_ context: ModelContext) { self.context = context }

    // Crear (con control de permisos). 'actor' puede ser nil → se deniega.
    @discardableResult
    public func create(
        username: String,
        fullName: String,
        role: Role,
        base: Base? = nil,
        active: Bool = true,
        actor: User?
    ) throws -> User {
        guard AuthorizationService.allowed(.create, on: .user, for: actor) else {
            throw UsersRepositoryError.unauthorizedCreate
        }
        let u = User(username: username, fullName: fullName, active: active, role: role, base: base)
        context.insert(u)
        try context.save()
        return u
    }

    // Borrar (con permisos)
    public func delete(_ user: User, actor: User?) throws {
        guard AuthorizationService.allowed(.delete, on: .user, for: actor) else {
            throw UsersRepositoryError.unauthorizedDelete
        }
        context.delete(user)
        try context.save()
    }

    // Seed sin permisos
    @discardableResult
    public func unsafeCreate(
        username: String,
        fullName: String,
        role: Role,
        base: Base? = nil,
        active: Bool = true
    ) -> User {
        let u = User(username: username, fullName: fullName, active: active, role: role, base: base)
        context.insert(u)
        return u
    }

    // Buscar por username
    public func user(username: String) throws -> User? {
        try context
            .fetch(FetchDescriptor<User>(predicate: #Predicate { $0.username == username }))
            .first
    }
}
