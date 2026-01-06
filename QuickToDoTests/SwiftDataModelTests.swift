//
//  SwiftDataModelTests.swift
//  QuickToDoTests
//
//  Created by Claude Code
//

import XCTest
import SwiftData
import RxSwift
import CloudKit
@testable import QuickToDo

class SwiftDataModelTests: XCTestCase {

    var model: SwiftDataModel!
    var testModelContext: ModelContext!
    var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()

        // Create in-memory model container for testing
        let schema = Schema([ItemSD.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: configuration) else {
            XCTFail("Failed to create test ModelContainer")
            return
        }

        testModelContext = ModelContext(container)
        model = SwiftDataModel()
        model.modelContext = testModelContext

        disposeBag = DisposeBag()
    }

    override func tearDown() {
        model = nil
        testModelContext = nil
        disposeBag = nil
        super.tearDown()
    }

    // MARK: - Insert Tests

    func testInsertItem() {
        let testItem = Item(
            id: UUID(),
            name: "Test Item",
            count: 5,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let insertClosure = model.insert()
        let result = insertClosure(testItem, nil)

        XCTAssertTrue(result.1, "Insert should succeed")
        XCTAssertEqual(result.0?.name, "Test Item")
        XCTAssertEqual(result.0?.count, 5)
        XCTAssertEqual(result.0?.id, testItem.id)
    }

    func testInsertMultipleItems() {
        let items = [
            Item(id: UUID(), name: "Item 1", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()),
            Item(id: UUID(), name: "Item 2", count: 2, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()),
            Item(id: UUID(), name: "Item 3", count: 3, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())
        ]

        let insertClosure = model.insert()
        for item in items {
            let result = insertClosure(item, nil)
            XCTAssertTrue(result.1)
        }

        let (success, error) = model.getItems(withCompletion: nil)
        XCTAssertTrue(success)
        XCTAssertNil(error)
    }

    // MARK: - GetItems Tests

    func testGetItemsEmpty() {
        var itemCount = 0
        let (success, error) = model.getItems { _ in
            itemCount += 1
        }

        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertEqual(itemCount, 0)
    }

    func testGetItemsReturnsAllItems() {
        let insertClosure = model.insert()
        let expectedCount = 3

        for i in 1...expectedCount {
            let item = Item(id: UUID(), name: "Item \(i)", count: i, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())
            _ = insertClosure(item, nil)
        }

        var fetchedItemCount = 0
        let (success, error) = model.getItems { _ in
            fetchedItemCount += 1
        }

        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertEqual(fetchedItemCount, expectedCount)
    }

    func testGetItemsObservable() {
        let expectation = XCTestExpectation(description: "Items observable emits values")
        expectation.expectedFulfillmentCount = 2

        var emittedItems: [Item] = []

        model.items
            .subscribe(onNext: { item in
                if let item = item {
                    emittedItems.append(item)
                    expectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        let insertClosure = model.insert()
        _ = insertClosure(Item(id: UUID(), name: "Item 1", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()), nil)
        _ = insertClosure(Item(id: UUID(), name: "Item 2", count: 2, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()), nil)

        _ = model.getItems(withCompletion: nil)

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(emittedItems.count, 2)
    }

    // MARK: - Update Tests

    func testUpdateItem() {
        let originalItem = Item(
            id: UUID(),
            name: "Original",
            count: 1,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let insertClosure = model.insert()
        _ = insertClosure(originalItem, nil)

        let updatedItem = Item(
            id: originalItem.id,
            name: "Updated",
            count: 10,
            uploadedToICloud: true,
            done: true,
            shown: false,
            createdAt: originalItem.createdAt,
            lastUsedAt: Date()
        )

        let updateClosure = model.update()
        let result = updateClosure(originalItem, updatedItem)

        XCTAssertTrue(result.1, "Update should succeed")
        XCTAssertEqual(result.0?.name, "Updated")
        XCTAssertEqual(result.0?.count, 10)
        XCTAssertTrue(((result.0?.uploadedToICloud) != nil))
        XCTAssertTrue(((result.0?.done) != nil))
    }

    func testUpdateNonExistentItem() {
        let nonExistentItem = Item(
            id: UUID(),
            name: "Does Not Exist",
            count: 1,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let updateClosure = model.update()
        let result = updateClosure(nonExistentItem, nonExistentItem)

        XCTAssertFalse(result.1, "Update should fail for non-existent item")
    }

    // MARK: - GetItemWith Tests

    func testGetItemWithExistingName() {
        let testItem = Item(
            id: UUID(),
            name: "FindMe",
            count: 5,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let insertClosure = model.insert()
        _ = insertClosure(testItem, nil)

        let findClosure = model.getItemWith()
        let result = findClosure("FindMe")

        XCTAssertTrue(result.1, "Item should be found")
        XCTAssertEqual(result.0?.name, "FindMe")
        XCTAssertEqual(result.0?.count, 5)
    }

    func testGetItemWithNonExistentName() {
        let findClosure = model.getItemWith()
        let result = findClosure("DoesNotExist")

        XCTAssertFalse(result.1, "Item should not be found")
    }

    // MARK: - GetItemWithId Tests

    func testGetItemWithIdExisting() {
        let testId = UUID()
        let testItem = Item(
            id: testId,
            name: "Test",
            count: 3,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let insertClosure = model.insert()
        _ = insertClosure(testItem, nil)

        let findByIdClosure = model.getItemWithId()
        let result = findByIdClosure(testId)

        XCTAssertTrue(result.1, "Item should be found by ID")
        XCTAssertEqual((result.0)?.id, testId)
        XCTAssertEqual(result.0?.name, "Test")
    }

    func testGetItemWithIdNonExistent() {
        let nonExistentId = UUID()

        let findByIdClosure = model.getItemWithId()
        let result = findByIdClosure(nonExistentId)

        XCTAssertFalse(result.1, "Item should not be found")
    }

    // MARK: - GetHints Tests

    func testGetHintsNoMatches() {
        let expectation = XCTestExpectation(description: "Hints completion called")

        model.getHints(for: "xyz") { item1, item2 in
            XCTAssertEqual(item1.name, "")
            XCTAssertEqual(item2.name, "")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetHintsOneMatch() {
        let insertClosure = model.insert()
        _ = insertClosure(Item(id: UUID(), name: "Apple", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()), nil)

        let expectation = XCTestExpectation(description: "Hints completion called")

        model.getHints(for: "App") { item1, item2 in
            XCTAssertEqual(item1.name, "Apple")
            XCTAssertEqual(item2.name, "")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetHintsTwoMatches() {
        let insertClosure = model.insert()
        _ = insertClosure(Item(id: UUID(), name: "Apple", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()), nil)
        _ = insertClosure(Item(id: UUID(), name: "Application", count: 2, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()), nil)

        let expectation = XCTestExpectation(description: "Hints completion called")

        model.getHints(for: "App") { item1, item2 in
            XCTAssertTrue(item1.name.starts(with: "App"))
            XCTAssertTrue(item2.name.starts(with: "App"))
            XCTAssertNotEqual(item1.name, item2.name)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetHintsMultipleMatches() {
        let insertClosure = model.insert()
        _ = insertClosure(Item(id: UUID(), name: "Test1", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()), nil)
        _ = insertClosure(Item(id: UUID(), name: "Test2", count: 2, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()), nil)
        _ = insertClosure(Item(id: UUID(), name: "Test3", count: 3, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()), nil)

        let expectation = XCTestExpectation(description: "Hints completion called")

        model.getHints(for: "Test") { item1, item2 in
            // Should return first two matches
            XCTAssertTrue(item1.name.starts(with: "Test"))
            XCTAssertTrue(item2.name.starts(with: "Test"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - CloudKit Stub Tests

    func testPrepareShareNotSupported() async {
        let expectation = XCTestExpectation(description: "Share preparation handler called")

        do {
            try await model.prepareShare { share, container, error in
                XCTAssertNil(share)
                XCTAssertNil(container)
                XCTAssertNotNil(error)
                XCTAssertEqual((error as NSError?)?.domain, "SwiftDataModel")
                expectation.fulfill()
            }
        } catch {
            XCTFail("Should not throw, should call handler with error")
        }

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testGetRootRecordReturnsNil() {
        XCTAssertNil(model.getRootRecord())
    }

    func testGetZoneReturnsNil() {
        XCTAssertNil(model.getZone())
    }

    func testGetCurrentShareStatusReturnsNil() {
        XCTAssertNil(model.getCurrentShareStatus())
    }

    func testIsListCurrentlySharedReturnsFalse() {
        XCTAssertFalse(model.isListCurrentlyShared())
    }

    func testRefreshShareStatusReturnsNil() async throws {
        let result = try await model.refreshShareStatus()
        XCTAssertNil(result)
    }

    func testGetSharedItemsReturnsSuccess() {
        let mockRecord = CKRecord(recordType: "Mock")
        let (success, error) = model.getSharedItems(for: mockRecord, with: nil)

        XCTAssertTrue(success)
        XCTAssertNil(error)
    }

    func testFetchAllSharedItemsReturnsSuccess() {
        let (success, error) = model.fetchAllSharedItems { _ in }

        XCTAssertTrue(success)
        XCTAssertNil(error)
    }

    // MARK: - ItemSD to Item Conversion Tests

    func testItemSDToItemConversion() {
        let uuid = UUID()
        let date = Date()

        let itemSD = ItemSD(
            completed: true,
            count: 10,
            lastUsed: date,
            used: true,
            word: "TestWord",
            uploadedToICloud: true,
            uuid: uuid.uuidString
        )

        testModelContext.insert(itemSD)
        try? testModelContext.save()

        var convertedItem: Item?
        _ = model.getItems { item in
            convertedItem = item
        }

        XCTAssertNotNil(convertedItem)
        XCTAssertEqual(convertedItem?.id, uuid)
        XCTAssertEqual(convertedItem?.name, "TestWord")
        XCTAssertEqual(convertedItem?.count, 10)
        XCTAssertTrue(convertedItem?.done ?? false)
        XCTAssertTrue(convertedItem?.shown ?? false)
        XCTAssertTrue(convertedItem?.uploadedToICloud ?? false)
    }
}
