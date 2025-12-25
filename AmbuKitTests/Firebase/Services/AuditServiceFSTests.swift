//
//  AuditServiceFSTests.swift
//  AmbuKitTests
//
//  Created by Adolfo on 27/11/25.
//


import XCTest
import FirebaseFirestore
@testable import AmbuKit

@MainActor
final class AuditServiceFSTests: XCTestCase {
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Configurar Firebase (solo la primera vez)
        FirebaseTestHelper.configureIfNeeded()
    }
    
    override func tearDown() async throws {
        // No limpiamos entre tests para evitar interferencia
        // Los tests usan UUIDs únicos para cada entidad
        try await super.tearDown()
    }
    
    // MARK: - Logging Tests
    
    func testLogCreatesEntry() async throws {
        // Given
        let entityId = UUID().uuidString
        
        // When
        await AuditServiceFS.log(
            .create,
            entity: .kit,
            entityId: entityId,
            actor: nil,
            details: "Test create"
        )
        
        // Pequeña espera para que Firestore procese
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // Then
        let logs = await AuditServiceFS.getLogsForEntity(.kit, entityId: entityId)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.action, .create)
        XCTAssertEqual(logs.first?.entity, .kit)
        XCTAssertEqual(logs.first?.entityId, entityId)
        XCTAssertEqual(logs.first?.details, "Test create")
    }
    
    func testLogWithActor() async throws {
        // Given
        let entityId = UUID().uuidString
        let actor = UserFS(
            uid: "test-uid",
            username: "testuser",
            fullName: "Test User",
            email: "test@example.com",
            roleId: "admin"
        )
        
        // When
        await AuditServiceFS.log(
            .update,
            entity: .base,
            entityId: entityId,
            actor: actor,
            details: "Test update"
        )
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Then
        let logs = await AuditServiceFS.getLogsForEntity(.base, entityId: entityId)
        XCTAssertEqual(logs.first?.actorUsername, "testuser")
        XCTAssertEqual(logs.first?.actorRole, "admin")
    }
    
    func testLogAsyncDoesNotBlock() async throws {
        // Given
        let startTime = Date()
        
        // When - fire-and-forget
        AuditServiceFS.logAsync(
            .delete,
            entity: .vehicle,
            entityId: "test-vehicle-\(UUID().uuidString)",
            actor: nil
        )
        
        // Then - should return immediately
        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, 0.1) // Menos de 100ms
    }
    
    // MARK: - Query Tests
    
    func testGetLogsWithFilters() async throws {
        // Given - crear varios logs con IDs únicos
        let kitId = UUID().uuidString
        let baseId = UUID().uuidString
        
        await AuditServiceFS.log(.create, entity: .kit, entityId: kitId, actor: nil)
        await AuditServiceFS.log(.update, entity: .kit, entityId: kitId, actor: nil)
        await AuditServiceFS.log(.create, entity: .base, entityId: baseId, actor: nil)
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // When - filtrar por entidad
        let kitLogs = await AuditServiceFS.getLogs(entity: .kit, entityId: kitId)
        
        // Then
        XCTAssertEqual(kitLogs.count, 2)
        XCTAssertTrue(kitLogs.allSatisfy { $0.entity == .kit })
    }
    
    func testGetLogsForUser() async throws {
        // Given - username único para este test
        let uniqueUsername = "sanitario_\(UUID().uuidString.prefix(8))"
        let actor = UserFS(
            uid: "user-\(UUID().uuidString)",
            username: uniqueUsername,
            fullName: "Sanitario Test",
            email: "san@example.com"
        )
        
        await AuditServiceFS.log(.create, entity: .kit, entityId: "k1-\(UUID().uuidString)", actor: actor)
        await AuditServiceFS.log(.update, entity: .kitItem, entityId: "ki1-\(UUID().uuidString)", actor: actor)
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // When
        let userLogs = await AuditServiceFS.getLogsForUser(username: uniqueUsername)
        
        // Then
        XCTAssertGreaterThanOrEqual(userLogs.count, 2)
        XCTAssertTrue(userLogs.allSatisfy { $0.actorUsername == uniqueUsername })
    }
    
    func testGetRecentLogs() async throws {
        // Given
        await AuditServiceFS.log(.read, entity: .kit, entityId: "c1-\(UUID().uuidString)", actor: nil)
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // When
        let recentLogs = await AuditServiceFS.getRecentLogs(limit: 10)
        
        // Then
        XCTAssertFalse(recentLogs.isEmpty)
        
        // Verificar que todos son de las últimas 24h
        let yesterday = Date().addingTimeInterval(-86400)
        XCTAssertTrue(recentLogs.allSatisfy { $0.timestamp > yesterday })
    }
    
    func testGetLogsWithLimit() async throws {
        // Given - crear más de 5 logs con IDs únicos
        let prefix = UUID().uuidString.prefix(8)
        for i in 1...10 {
            await AuditServiceFS.log(
                .create,
                entity: .kitItem,
                entityId: "item-\(prefix)-\(i)",
                actor: nil
            )
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s para 10 logs
        
        // When
        let limitedLogs = await AuditServiceFS.getLogs(entity: .kitItem, limit: 5)
        
        // Then
        XCTAssertLessThanOrEqual(limitedLogs.count, 5)
    }
    
    // MARK: - Date Range Tests
    
    func testGetLogsInDateRange() async throws {
        // Given
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-172800)
        
        // When
        let logs = await AuditServiceFS.getLogsInRange(from: twoDaysAgo, to: yesterday)
        
        // Then
        XCTAssertTrue(logs.allSatisfy {
            $0.timestamp >= twoDaysAgo && $0.timestamp <= yesterday
        })
    }
    
    // MARK: - Batch Tests
    
    func testLogBatch() async throws {
        // Given
        let prefix = UUID().uuidString.prefix(8)
        let entries: [(ActionKind, EntityKind, String, UserFS?, String?)] = [
            (.delete, .kitItem, "item-\(prefix)-1", nil, "Batch delete 1"),
            (.delete, .kitItem, "item-\(prefix)-2", nil, "Batch delete 2"),
            (.delete, .kitItem, "item-\(prefix)-3", nil, "Batch delete 3")
        ]
        
        let mappedEntries = entries.map {
            (action: $0.0, entity: $0.1, entityId: $0.2, actor: $0.3, details: $0.4)
        }
        
        // When
        await AuditServiceFS.logBatch(mappedEntries)
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Then
        let logs = await AuditServiceFS.getLogs(action: .delete, entity: .kitItem, limit: 10)
        XCTAssertGreaterThanOrEqual(logs.count, 3)
    }
    
    // MARK: - Statistics Tests
    
    func testGetStatistics() async throws {
        // When
        let stats = await AuditServiceFS.getStatistics()
        
        // Then
        XCTAssertGreaterThanOrEqual(stats.total, 0)
        XCTAssertEqual(
            stats.total,
            stats.creates + stats.reads + stats.updates + stats.deletes
        )
    }
    
    func testGetMostActiveUsers() async throws {
        // Given - usernames únicos
        let prefix = UUID().uuidString.prefix(8)
        let actor1 = UserFS(uid: "1", username: "user1_\(prefix)", fullName: "User 1", email: "u1@test.com")
        let actor2 = UserFS(uid: "2", username: "user2_\(prefix)", fullName: "User 2", email: "u2@test.com")
        
        // user1 hace 3 acciones
        for _ in 1...3 {
            await AuditServiceFS.log(.create, entity: .kit, entityId: UUID().uuidString, actor: actor1)
        }
        
        // user2 hace 1 acción
        await AuditServiceFS.log(.create, entity: .kit, entityId: UUID().uuidString, actor: actor2)
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // When
        let activeUsers = await AuditServiceFS.getMostActiveUsers(limit: 5)
        
        // Then
        XCTAssertFalse(activeUsers.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testLogHandlesErrorsSilently() async throws {
        // Given - datos vacíos/nil
        await AuditServiceFS.log(
            .create,
            entity: .audit,
            entityId: "",  // ID vacío
            actor: nil,
            details: nil
        )
        
        // Then - no debe lanzar excepción
        XCTAssertTrue(true)
    }
}
