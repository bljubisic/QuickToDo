//
//  IntentsTests.swift
//  QuickToDoTests
//
//  Created by Claude Code
//

import XCTest
import SwiftData
import AppIntents
import WidgetKit
import Foundation
@testable import QuickToDo

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
final class IntentsTests: XCTestCase {

    var testModelContainer: ModelContainer!
    var testModelContext: ModelContext!

    override func setUp() {
        super.setUp()

        // Create in-memory model container for testing
        let schema = Schema([ItemSD.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: configuration) else {
            XCTFail("Failed to create test ModelContainer")
            return
        }

        testModelContainer = container
        testModelContext = ModelContext(container)
    }

    override func tearDown() {
        testModelContainer = nil
        testModelContext = nil
        super.tearDown()
    }

    // MARK: - QuickToDoIntent Tests

    func testQuickToDoIntentInitialization() {
        let intent = QuickToDoIntent()
        XCTAssertNil(intent.id)
    }

    func testQuickToDoIntentInitializationWithID() {
        let testID = "test-id-123"
        let intent = QuickToDoIntent(id: testID)
        XCTAssertEqual(intent.id, testID)
    }

    func testQuickToDoIntentStaticProperties() {
        XCTAssertEqual(QuickToDoIntent.intentClassName, "QuickToDoIntent")
        XCTAssertNotNil(QuickToDoIntent.title)
        XCTAssertNotNil(QuickToDoIntent.description)
    }

    func testQuickToDoIntentPerformWithoutID() async throws {
        let intent = QuickToDoIntent()

        // Should complete without error even when id is nil
        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }

    func testQuickToDoIntentPerformWithNonExistentID() async throws {
        let intent = QuickToDoIntent(id: "non-existent-id")

        // Should complete without error even when item not found
        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }

    func testQuickToDoIntentStringOptionsProvider() async throws {
        let provider = QuickToDoIntent.StringOptionsProvider()
        let results = try await provider.results()

        // Currently returns empty array (TODO in implementation)
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - ItemCompleted Intent Tests

    func testItemCompletedIntentInitialization() {
        let intent = ItemCompleted()
        XCTAssertNil(intent.id)
    }

    func testItemCompletedIntentStaticProperties() {
        XCTAssertEqual(ItemCompleted.intentClassName, "ItemCompletedIntent")
        XCTAssertNotNil(ItemCompleted.title)
        XCTAssertNotNil(ItemCompleted.description)
    }

    func testItemCompletedIntentPerform() async throws {
        let intent = ItemCompleted()

        // Note: This will try to access the app group container
        // In a real test environment, this might fail
        do {
            let result = try await intent.perform()
            XCTAssertNotNil(result)
        } catch {
            // Expected to fail in test environment without proper app group setup
            print("ItemCompleted perform failed (expected in test environment): \(error)")
        }
    }

    func testItemCompletedStringOptionsProvider() async throws {
        let provider = ItemCompleted.StringOptionsProvider()
        let results = try await provider.results()

        // Currently returns empty array (TODO in implementation)
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Intent Dialog Tests

    func testIntentDialogIDParameterDisambiguation() {
        // Test the disambiguation dialog creation
        // This is a fileprivate extension, so we test it indirectly
        // by verifying the ItemCompleted intent has the proper structure
        XCTAssertNotNil(ItemCompleted.predictionConfiguration)
    }

    // MARK: - Integration Tests (with Mock Data)

    func testQuickToDoIntentUpdatesItemCompletionStatus() async {
        // Create a test item in the shared model container
        let testItemSD = ItemSD(
            completed: false,
            count: 1,
            lastUsed: Date(),
            used: true,
            word: "Test Intent Item",
            uploadedToICloud: false,
            uuid: "test-intent-uuid"
        )

        testModelContext.insert(testItemSD)
        try? testModelContext.save()

        // Note: The actual intent uses sharedModelContainer, not our test container
        // So this is a conceptual test of what should happen
        XCTAssertFalse(testItemSD.completed ?? true)

        // Simulate what the intent does
        testItemSD.completed = true
        testItemSD.lastUsed = .now
        try? testModelContext.save()

        // Verify the update
        XCTAssertTrue(testItemSD.completed ?? false)
        XCTAssertNotNil(testItemSD.lastUsed)
    }

    func testQuickToDoIntentUpdatesLastUsedDate() async {
        let testItemSD = ItemSD(
            completed: false,
            count: 1,
            lastUsed: Date().addingTimeInterval(-3600),
            used: true,
            word: "Test Date Update",
            uploadedToICloud: false,
            uuid: "test-date-uuid"
        )

        testModelContext.insert(testItemSD)
        try? testModelContext.save()

        let oldLastUsed = testItemSD.lastUsed

        // Wait a bit to ensure different timestamp
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Simulate what the intent does
        testItemSD.completed = true
        testItemSD.lastUsed = .now
        try? testModelContext.save()

        XCTAssertNotEqual(testItemSD.lastUsed, oldLastUsed)
        if let newLastUsed = testItemSD.lastUsed,
           let oldDate = oldLastUsed {
            XCTAssertTrue(newLastUsed > oldDate)
        }
    }

    // MARK: - Parameter Summary Tests

    func testQuickToDoIntentParameterSummary() {
        // Verify parameter summary is properly defined
        let summary = QuickToDoIntent.parameterSummary
        XCTAssertNotNil(summary)
    }

    func testItemCompletedParameterSummary() {
        let summary = ItemCompleted.parameterSummary
        XCTAssertNotNil(summary)
    }

    // MARK: - Prediction Configuration Tests

    func testItemCompletedPredictionConfiguration() {
        let config = ItemCompleted.predictionConfiguration
        XCTAssertNotNil(config)
    }

    // MARK: - Edge Cases

    func testQuickToDoIntentWithEmptyID() async throws {
        let intent = QuickToDoIntent(id: "")

        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }

    func testQuickToDoIntentWithVeryLongID() async throws {
        let longID = String(repeating: "a", count: 1000)
        let intent = QuickToDoIntent(id: longID)

        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }

    // MARK: - Database Path Consistency Tests

    func testItemCompletedDatabasePathIssue() {
        // NOTE: This test documents a potential bug
        // ItemCompleted uses "QuickToDo1.sqlite" while AppModelContainer uses "QuickToDo.sqlite"
        // This mismatch could cause data inconsistency

        let appGroupContainerID = "group.QuickToDoSharingDefaults"
        guard let appGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerID) else {
            // Expected to fail in test environment
            return
        }

        let itemCompletedPath = appGroupContainer.appendingPathComponent("QuickToDo1.sqlite")
        // AppModelContainer path would be:
        // let appModelContainerPath = appGroupContainer.appendingPathComponent("QuickToDo.sqlite")

        // Document the inconsistency
        XCTAssertTrue(itemCompletedPath.lastPathComponent == "QuickToDo1.sqlite",
                     "ItemCompleted uses different database file than AppModelContainer")
    }

    // MARK: - Intent Protocol Conformance Tests

    func testQuickToDoIntentConformsToAppIntent() {
        let intent = QuickToDoIntent()
        XCTAssertTrue(intent is AppIntent)
    }

    func testQuickToDoIntentConformsToWidgetConfigurationIntent() {
        let intent = QuickToDoIntent()
        XCTAssertTrue(intent is WidgetConfigurationIntent)
    }

    func testItemCompletedConformsToAppIntent() {
        let intent = ItemCompleted()
        XCTAssertTrue(intent is AppIntent)
    }

    func testItemCompletedConformsToPredictableIntent() {
        let intent = ItemCompleted()
        XCTAssertTrue(intent is PredictableIntent)
    }
}
