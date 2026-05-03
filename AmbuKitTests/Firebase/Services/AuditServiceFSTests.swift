//
//  AuditServiceFSTests.swift
//  AmbuKitTests
//

import Testing
@testable import AmbuKit
import Foundation
import FirebaseFirestore

@MainActor
@Suite(.tags(.firebase, .slow), .timeLimit(.minutes(2)))
struct AuditServiceFSTests {

    init() async throws {
        FirebaseTestHelper.configureIfNeeded()
    }

    // MARK: - Logging Tests

    @Test func logCreatesEntry() async throws {
        let entityId = UUID().uuidString

        await AuditServiceFS.log(
            .create,
            entity: .kit,
            entityId: entityId,
            actor: nil,
            details: "Test create"
        )

        try await Task.sleep(for: .milliseconds(500))

        let logs = await AuditServiceFS.getLogsForEntity(.kit, entityId: entityId)
        #expect(logs.count == 1)
        #expect(logs.first?.action == .create)
        #expect(logs.first?.entity == .kit)
        #expect(logs.first?.entityId == entityId)
        #expect(logs.first?.details == "Test create")
    }

    @Test func logWithActor() async throws {
        let entityId = UUID().uuidString
        let actor = UserFS(
            uid: "test-uid",
            username: "testuser",
            fullName: "Test User",
            email: "test@example.com",
            roleId: "admin"
        )

        await AuditServiceFS.log(
            .update,
            entity: .base,
            entityId: entityId,
            actor: actor,
            details: "Test update"
        )

        try await Task.sleep(for: .milliseconds(500))

        let logs = await AuditServiceFS.getLogsForEntity(.base, entityId: entityId)
        #expect(logs.first?.actorUsername == "testuser")
        #expect(logs.first?.actorRole == "admin")
    }

    @Test func logAsyncDoesNotBlock() async throws {
        let startTime = Date()

        AuditServiceFS.logAsync(
            .delete,
            entity: .vehicle,
            entityId: "test-vehicle-\(UUID().uuidString)",
            actor: nil
        )

        let elapsed = Date().timeIntervalSince(startTime)
        #expect(elapsed < 0.1)
    }

    // MARK: - Query Tests

    @Test func getLogsWithFilters() async throws {
        let kitId = UUID().uuidString
        let baseId = UUID().uuidString

        await AuditServiceFS.log(.create, entity: .kit, entityId: kitId, actor: nil)
        await AuditServiceFS.log(.update, entity: .kit, entityId: kitId, actor: nil)
        await AuditServiceFS.log(.create, entity: .base, entityId: baseId, actor: nil)

        try await Task.sleep(for: .milliseconds(500))

        let kitLogs = await AuditServiceFS.getLogs(entity: .kit, entityId: kitId)
        #expect(kitLogs.count == 2)
        #expect(kitLogs.allSatisfy { $0.entity == .kit })
    }

    @Test func getLogsForUser() async throws {
        let uniqueUsername = "sanitario_\(UUID().uuidString.prefix(8))"
        let actor = UserFS(
            uid: "user-\(UUID().uuidString)",
            username: uniqueUsername,
            fullName: "Sanitario Test",
            email: "san@example.com"
        )

        await AuditServiceFS.log(.create, entity: .kit, entityId: "k1-\(UUID().uuidString)", actor: actor)
        await AuditServiceFS.log(.update, entity: .kitItem, entityId: "ki1-\(UUID().uuidString)", actor: actor)

        try await Task.sleep(for: .milliseconds(500))

        let userLogs = await AuditServiceFS.getLogsForUser(username: uniqueUsername)
        #expect(userLogs.count >= 2)
        #expect(userLogs.allSatisfy { $0.actorUsername == uniqueUsername })
    }

    @Test func getRecentLogs() async throws {
        await AuditServiceFS.log(.read, entity: .kit, entityId: "c1-\(UUID().uuidString)", actor: nil)

        try await Task.sleep(for: .milliseconds(500))

        let recentLogs = await AuditServiceFS.getRecentLogs(limit: 10)
        #expect(!recentLogs.isEmpty)

        let yesterday = Date().addingTimeInterval(-86400)
        #expect(recentLogs.allSatisfy { $0.timestamp > yesterday })
    }

    @Test func getLogsWithLimit() async throws {
        let prefix = UUID().uuidString.prefix(8)
        for i in 1...10 {
            await AuditServiceFS.log(
                .create,
                entity: .kitItem,
                entityId: "item-\(prefix)-\(i)",
                actor: nil
            )
        }

        try await Task.sleep(for: .seconds(1))

        let limitedLogs = await AuditServiceFS.getLogs(entity: .kitItem, limit: 5)
        #expect(limitedLogs.count <= 5)
    }

    // MARK: - Date Range Tests

    @Test func getLogsInDateRange() async throws {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-172800)

        let logs = await AuditServiceFS.getLogsInRange(from: twoDaysAgo, to: yesterday)

        #expect(logs.allSatisfy {
            $0.timestamp >= twoDaysAgo && $0.timestamp <= yesterday
        })
    }

    // MARK: - Batch Tests

    @Test func logBatch() async throws {
        let prefix = UUID().uuidString.prefix(8)
        let entries: [(ActionKind, EntityKind, String, UserFS?, String?)] = [
            (.delete, .kitItem, "item-\(prefix)-1", nil, "Batch delete 1"),
            (.delete, .kitItem, "item-\(prefix)-2", nil, "Batch delete 2"),
            (.delete, .kitItem, "item-\(prefix)-3", nil, "Batch delete 3")
        ]

        let mappedEntries = entries.map {
            (action: $0.0, entity: $0.1, entityId: $0.2, actor: $0.3, details: $0.4)
        }

        await AuditServiceFS.logBatch(mappedEntries)

        try await Task.sleep(for: .milliseconds(500))

        let logs = await AuditServiceFS.getLogs(action: .delete, entity: .kitItem, limit: 10)
        #expect(logs.count >= 3)
    }

    // MARK: - Statistics Tests

    @Test func getStatistics() async throws {
        let stats = await AuditServiceFS.getStatistics()
        #expect(stats.total >= 0)
        #expect(stats.total == stats.creates + stats.reads + stats.updates + stats.deletes)
    }

    @Test func getMostActiveUsers() async throws {
        let prefix = UUID().uuidString.prefix(8)
        let actor1 = UserFS(uid: "1", username: "user1_\(prefix)", fullName: "User 1", email: "u1@test.com")
        let actor2 = UserFS(uid: "2", username: "user2_\(prefix)", fullName: "User 2", email: "u2@test.com")

        for _ in 1...3 {
            await AuditServiceFS.log(.create, entity: .kit, entityId: UUID().uuidString, actor: actor1)
        }
        await AuditServiceFS.log(.create, entity: .kit, entityId: UUID().uuidString, actor: actor2)

        try await Task.sleep(for: .seconds(1))

        let activeUsers = await AuditServiceFS.getMostActiveUsers(limit: 5)
        #expect(!activeUsers.isEmpty)
    }

    // MARK: - Error Handling Tests

    @Test func logHandlesErrorsSilently() async throws {
        await AuditServiceFS.log(
            .create,
            entity: .audit,
            entityId: "",
            actor: nil,
            details: nil
        )
        // No debe lanzar excepción
    }
}
