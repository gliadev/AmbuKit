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
        // Usar emulador de Firestore
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
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
            entityId: "test-vehicle",
            actor: nil
        )
        
        // Then - should return immediately
        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, 0.1) // Menos de 100ms
    }
    
    // MARK: - Query Tests
    
    func testGetLogsWithFilters() async throws {
        // Given - crear varios logs
        let kitId = UUID().uuidString
        let baseId = UUID().uuidString
        
        await AuditServiceFS.log(.create, entity: .kit, entityId: kitId, actor: nil)
        await AuditServiceFS.log(.update, entity: .kit, entityId: kitId, actor: nil)
        await AuditServiceFS.log(.create, entity: .base, entityId: baseId, actor: nil)
        
        // When - filtrar por entidad
        let kitLogs = await AuditServiceFS.getLogs(entity: .kit, entityId: kitId)
        
        // Then
        XCTAssertEqual(kitLogs.count, 2)
        XCTAssertTrue(kitLogs.allSatisfy { $0.entity == .kit })
    }
    
    func testGetLogsForUser() async throws {
        // Given
        let actor = UserFS(
            uid: "user-123",
            username: "sanitario1",
            fullName: "Sanitario Uno",
            email: "san1@example.com"
        )
        
        await AuditServiceFS.log(.create, entity: .kit, entityId: "k1", actor: actor)
        await AuditServiceFS.log(.update, entity: .kitItem, entityId: "ki1", actor: actor)
        
        // When
        let userLogs = await AuditServiceFS.getLogsForUser(username: "sanitario1")
        
        // Then
        XCTAssertGreaterThanOrEqual(userLogs.count, 2)
        XCTAssertTrue(userLogs.allSatisfy { $0.actorUsername == "sanitario1" })
    }
    
    func testGetRecentLogs() async throws {
        // Given
        await AuditServiceFS.log(.read, entity: .kit, entityId: "c1", actor: nil)
        
        // When
        let recentLogs = await AuditServiceFS.getRecentLogs(limit: 10)
        
        // Then
        XCTAssertFalse(recentLogs.isEmpty)
        
        // Verificar que todos son de las últimas 24h
        let yesterday = Date().addingTimeInterval(-86400)
        XCTAssertTrue(recentLogs.allSatisfy { $0.timestamp > yesterday })
    }
    
    func testGetLogsWithLimit() async throws {
        // Given - crear más de 5 logs
        for i in 1...10 {
            await AuditServiceFS.log(
                .create,
                entity: .kitItem,
                entityId: "item-\(i)",
                actor: nil
            )
        }
        
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
        let entries: [(ActionKind, EntityKind, String, UserFS?, String?)] = [
            (.delete, .kitItem, "item-1", nil, "Batch delete 1"),
            (.delete, .kitItem, "item-2", nil, "Batch delete 2"),
            (.delete, .kitItem, "item-3", nil, "Batch delete 3")
        ]
        
        let mappedEntries = entries.map {
            (action: $0.0, entity: $0.1, entityId: $0.2, actor: $0.3, details: $0.4)
        }
        
        // When
        await AuditServiceFS.logBatch(mappedEntries)
        
        // Then
        let logs = await AuditServiceFS.getLogs(action: .delete, entity: .kitItem, limit: 10)
        XCTAssertGreaterThanOrEqual(logs.count, 3)
    }
    
    // MARK: - Statistics Tests
    
    func testGetStatistics() async throws {
        // Given - algunos logs ya existen
        
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
        // Given
        let actor1 = UserFS(uid: "1", username: "user1", fullName: "User 1", email: "u1@test.com")
        let actor2 = UserFS(uid: "2", username: "user2", fullName: "User 2", email: "u2@test.com")
        
        // user1 hace 3 acciones
        for _ in 1...3 {
            await AuditServiceFS.log(.create, entity: .kit, entityId: UUID().uuidString, actor: actor1)
        }
        
        // user2 hace 1 acción
        await AuditServiceFS.log(.create, entity: .kit, entityId: UUID().uuidString, actor: actor2)
        
        // When
        let activeUsers = await AuditServiceFS.getMostActiveUsers(limit: 5)
        
        // Then
        XCTAssertFalse(activeUsers.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testLogHandlesErrorsSilently() async throws {
        // Este test verifica que el servicio no lanza excepciones
        // incluso con datos edge case
        
        // Given - datos vacíos/nil
        await AuditServiceFS.log(
            .create,
            entity: .audit,
            entityId: "",  // ID vacío
            actor: nil,
            details: nil
        )
        
        // Then - no debe lanzar excepción
        // Si llegamos aquí, el test pasa
        XCTAssertTrue(true)
    }
}
