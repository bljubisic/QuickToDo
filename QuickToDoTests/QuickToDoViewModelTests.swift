//
//  QuickToDoViewModelTests.swift
//  QuickToDoTests
//
//  Created by Claude Code
//

import XCTest
import RxSwift
import CloudKit
@testable import QuickToDo

class QuickToDoViewModelTests: XCTestCase {

    var viewModel: QuickToDoViewModel!
    var mockModel: MockQuickToDoModel!
    var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        mockModel = MockQuickToDoModel()
        viewModel = QuickToDoViewModel(mockModel)
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        viewModel = nil
        mockModel = nil
        disposeBag = nil
        super.tearDown()
    }

    // MARK: - Helper

    private func makeItem(
        id: UUID = UUID(),
        name: String = "Test",
        count: Int = 1,
        done: Bool = false,
        shown: Bool = true,
        lastUsedAt: Date = Date()
    ) -> Item {
        Item(id: id, name: name, count: count, uploadedToICloud: false, done: done, shown: shown, createdAt: Date(), lastUsedAt: lastUsedAt)
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(viewModel)
        XCTAssertTrue(viewModel.itemsArray.isEmpty)
        XCTAssertNotNil(viewModel.inputs)
        XCTAssertNotNil(viewModel.outputs)
    }

    func testInitialItemsArrayIsEmpty() {
        XCTAssertEqual(viewModel.outputs.itemsArray.count, 0)
        XCTAssertEqual(viewModel.outputs.totalItemsNum, 0)
        XCTAssertEqual(viewModel.outputs.doneItemsNum, 0)
    }

    // MARK: - Add Tests

    func testAddItemDelegatesToModel() {
        let item = makeItem(name: "Groceries")
        let (success, error) = viewModel.inputs.add(item)

        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertEqual(mockModel.addCallCount, 1)
        XCTAssertTrue(mockModel.lastAddToCloud)
    }

    // MARK: - Update Tests

    func testUpdateExistingItemInArray() {
        let id = UUID()
        let original = makeItem(id: id, name: "Original", done: false)
        viewModel.itemsArray.append(original)

        let updated = makeItem(id: id, name: "Updated", done: true)
        var completionCalled = false

        let (success, error) = viewModel.inputs.update(original, withItem: updated) {
            completionCalled = true
        }

        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertTrue(completionCalled)
        XCTAssertEqual(viewModel.itemsArray.count, 1)
        XCTAssertEqual(viewModel.itemsArray.first?.name, "Updated")
        XCTAssertTrue(viewModel.itemsArray.first?.done ?? false)
    }

    func testUpdateNonExistentItemDoesNotAddIt() {
        let item = makeItem(name: "Ghost")
        let updated = makeItem(id: item.id, name: "Ghost Updated")
        var completionCalled = false

        _ = viewModel.inputs.update(item, withItem: updated) {
            completionCalled = true
        }

        XCTAssertTrue(completionCalled)
        XCTAssertTrue(viewModel.itemsArray.isEmpty)
    }

    func testUpdateDelegatesToModel() {
        let item = makeItem()
        viewModel.itemsArray.append(item)
        let updated = makeItem(id: item.id, name: "New Name")

        _ = viewModel.inputs.update(item, withItem: updated) {}

        XCTAssertEqual(mockModel.updateCallCount, 1)
    }

    // MARK: - ClearList Tests

    func testClearListRemovesAllItems() {
        viewModel.itemsArray = [
            makeItem(name: "Item 1"),
            makeItem(name: "Item 2"),
            makeItem(name: "Item 3")
        ]

        let result = viewModel.inputs.clearList()

        XCTAssertTrue(result)
        XCTAssertTrue(viewModel.itemsArray.isEmpty)
    }

    func testClearListCallsUpdateForEachItem() {
        viewModel.itemsArray = [
            makeItem(name: "Item 1"),
            makeItem(name: "Item 2")
        ]

        _ = viewModel.inputs.clearList()

        XCTAssertEqual(mockModel.updateCallCount, 2)
    }

    func testClearListSetsShownToFalse() {
        let item = makeItem(name: "Visible", shown: true)
        viewModel.itemsArray = [item]

        _ = viewModel.inputs.clearList()

        // Verify the model received an update with shown = false
        XCTAssertEqual(mockModel.lastUpdatedNewItem?.shown, false)
    }

    func testClearListPassesDifferentOldAndNewItems() {
        let item = makeItem(name: "Item", shown: true)
        viewModel.itemsArray = [item]

        _ = viewModel.inputs.clearList()

        // The old item should have shown = true, the new item shown = false
        XCTAssertEqual(mockModel.lastUpdatedOldItem?.shown, true)
        XCTAssertEqual(mockModel.lastUpdatedNewItem?.shown, false)
    }

    func testClearListOnEmptyArray() {
        let result = viewModel.inputs.clearList()

        XCTAssertTrue(result)
        XCTAssertEqual(mockModel.updateCallCount, 0)
    }

    // MARK: - ShowOrHideAllDoneItems Tests

    func testShowOrHideAllDoneItemsHidesDone() {
        viewModel.itemsArray = [
            makeItem(name: "Done", done: true),
            makeItem(name: "Not Done", done: false)
        ]

        let result = viewModel.inputs.showOrHideAllDoneItems(shown: true)

        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.itemsArray.count, 1)
        XCTAssertEqual(viewModel.itemsArray.first?.name, "Not Done")
    }

    func testShowOrHideAllDoneItemsShowsAll() {
        viewModel.itemsArray = [
            makeItem(name: "Done", done: true),
            makeItem(name: "Not Done", done: false)
        ]

        let result = viewModel.inputs.showOrHideAllDoneItems(shown: false)

        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.itemsArray.count, 1)
        XCTAssertEqual(viewModel.itemsArray.first?.name, "Done")
    }

    // MARK: - Remove Tests

    func testRemoveItem() {
        let item = makeItem(name: "Remove Me")
        viewModel.itemsArray = [item, makeItem(name: "Keep Me")]

        let (success, error) = viewModel.inputs.remove(updated: item)

        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertEqual(viewModel.itemsArray.count, 1)
        XCTAssertEqual(viewModel.itemsArray.first?.name, "Keep Me")
    }

    func testRemoveNonExistentItem() {
        viewModel.itemsArray = [makeItem(name: "Existing")]
        let ghost = makeItem(name: "Ghost")

        let (success, _) = viewModel.inputs.remove(updated: ghost)

        XCTAssertTrue(success)
        XCTAssertEqual(viewModel.itemsArray.count, 1)
    }

    // MARK: - GetHints Tests

    func testGetHintsNoMatches() {
        viewModel.itemsArray = [
            makeItem(name: "Apple"),
            makeItem(name: "Banana")
        ]

        let expectation = XCTestExpectation(description: "Hints returned")

        viewModel.inputs.getHints(for: "Xyz") { hint1, hint2 in
            XCTAssertEqual(hint1, "")
            XCTAssertEqual(hint2, "")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetHintsOneMatch() {
        viewModel.itemsArray = [
            makeItem(name: "Apple"),
            makeItem(name: "Banana")
        ]

        let expectation = XCTestExpectation(description: "Hints returned")

        viewModel.inputs.getHints(for: "App") { hint1, hint2 in
            XCTAssertEqual(hint1, "Apple")
            XCTAssertEqual(hint2, "")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetHintsTwoMatches() {
        viewModel.itemsArray = [
            makeItem(name: "Apple"),
            makeItem(name: "Application"),
            makeItem(name: "Banana")
        ]

        let expectation = XCTestExpectation(description: "Hints returned")

        viewModel.inputs.getHints(for: "App") { hint1, hint2 in
            XCTAssertEqual(hint1, "Apple")
            XCTAssertEqual(hint2, "Application")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - GetItemsArray Tests

    func testGetItemsArrayWithoutFilter() {
        viewModel.itemsArray = [
            makeItem(name: "Shown", shown: true),
            makeItem(name: "Hidden", shown: false)
        ]

        let result = viewModel.inputs.getItemsArray(withFilter: false)

        XCTAssertEqual(result.count, 2)
    }

    func testGetItemsArrayWithFilter() {
        viewModel.itemsArray = [
            makeItem(name: "Shown", shown: true),
            makeItem(name: "Hidden", shown: false)
        ]

        let result = viewModel.inputs.getItemsArray(withFilter: true)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Shown")
    }

    // MARK: - GetItemsSize Tests

    func testGetItemsSize() {
        viewModel.itemsArray = [makeItem(), makeItem(), makeItem()]
        XCTAssertEqual(viewModel.inputs.getItemsSize(), 3)
    }

    func testGetItemsSizeEmpty() {
        XCTAssertEqual(viewModel.inputs.getItemsSize(), 0)
    }

    // MARK: - Output Properties Tests

    func testDoneItemsNum() {
        viewModel.itemsArray = [
            makeItem(done: true),
            makeItem(done: true),
            makeItem(done: false)
        ]

        XCTAssertEqual(viewModel.outputs.doneItemsNum, 2)
    }

    func testTotalItemsNum() {
        viewModel.itemsArray = [makeItem(), makeItem()]
        XCTAssertEqual(viewModel.outputs.totalItemsNum, 2)
    }

    // MARK: - Config Tests

    func testGetConfigDelegatesToModel() {
        mockModel.configValue = QuickToDoConfig(showDoneItems: false)
        let result = viewModel.inputs.getConfig()
        XCTAssertFalse(result)
    }

    func testGetConfigReturnsDefaultWhenNil() {
        mockModel.configValue = nil
        let result = viewModel.inputs.getConfig()
        XCTAssertFalse(result)
    }

    func testSaveConfigDelegatesToModel() {
        let (success, error) = viewModel.inputs.save(config: true)
        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertEqual(mockModel.saveConfigCallCount, 1)
    }

    // MARK: - CloudKit Delegation Tests

    func testGetRootRecord() {
        XCTAssertNil(viewModel.inputs.getRootRecord())
    }

    func testGetZone() {
        XCTAssertNil(viewModel.inputs.getZone())
    }

    func testGetCurrentShareStatus() {
        XCTAssertNil(viewModel.inputs.getCurrentShareStatus())
    }

    func testIsListCurrentlyShared() {
        XCTAssertFalse(viewModel.inputs.isListCurrentlyShared())
    }

    // MARK: - GetItems Subscription Tests

    func testGetItemsAddsNewItemsToArray() {
        let expectation = XCTestExpectation(description: "Items loaded")

        let item = makeItem(name: "From Model")
        mockModel.itemsToEmit = [item]

        _ = viewModel.inputs.getItems {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(viewModel.itemsArray.count, 1)
        XCTAssertEqual(viewModel.itemsArray.first?.name, "From Model")
    }

    func testGetItemsFiltersEmptyNames() {
        let expectation = XCTestExpectation(description: "Valid item loaded")

        let validItem = makeItem(name: "Valid")
        let emptyItem = makeItem(name: "")
        mockModel.itemsToEmit = [validItem, emptyItem]

        _ = viewModel.inputs.getItems {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(viewModel.itemsArray.count, 1)
        XCTAssertEqual(viewModel.itemsArray.first?.name, "Valid")
    }

    func testGetItemsDeduplicatesById() {
        let expectation = XCTestExpectation(description: "Items loaded")

        let id = UUID()
        let item1 = makeItem(id: id, name: "First", lastUsedAt: Date())
        mockModel.itemsToEmit = [item1, item1]

        _ = viewModel.inputs.getItems {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        // Should only have one entry for this id
        XCTAssertEqual(viewModel.itemsArray.filter { $0.id == id }.count, 1)
    }

    func testGetItemsUpdatesExistingWhenNewer() {
        let expectation = XCTestExpectation(description: "Items loaded")

        let id = UUID()
        let olderDate = Date().addingTimeInterval(-3600)
        let newerDate = Date()

        let olderItem = makeItem(id: id, name: "Old", lastUsedAt: olderDate)
        viewModel.itemsArray = [olderItem]

        let newerItem = makeItem(id: id, name: "New", lastUsedAt: newerDate)
        mockModel.itemsToEmit = [newerItem]

        _ = viewModel.inputs.getItems {
            expectation.fulfill()
        }

        // Allow time for the RxSwift subscription to process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(viewModel.itemsArray.first?.name, "New")
    }

    func testGetItemsDoesNotUpdateWhenOlder() {
        let id = UUID()
        let newerDate = Date()
        let olderDate = Date().addingTimeInterval(-3600)

        let newerItem = makeItem(id: id, name: "Newer", lastUsedAt: newerDate)
        viewModel.itemsArray = [newerItem]

        let olderItem = makeItem(id: id, name: "Older", lastUsedAt: olderDate)
        mockModel.itemsToEmit = [olderItem]

        _ = viewModel.inputs.getItems {}

        // Wait for RxSwift pipeline
        let expectation = XCTestExpectation(description: "Processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(viewModel.itemsArray.first?.name, "Newer")
    }

    // MARK: - UploadToCloud Tests

    func testUploadToCloudFiltersAlreadyUploaded() {
        viewModel.itemsArray = [
            makeItem(name: "Not Uploaded"),
            Item(id: UUID(), name: "Already Uploaded", count: 1, uploadedToICloud: true, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())
        ]

        let (success, error) = viewModel.inputs.uploadToCloud()

        XCTAssertTrue(success)
        XCTAssertNil(error)
        // Only the non-uploaded item should be passed
        XCTAssertEqual(mockModel.lastUploadedItems?.count, 1)
        XCTAssertEqual(mockModel.lastUploadedItems?.first?.name, "Not Uploaded")
    }

    // MARK: - AddToSharedZone Tests

    func testAddToSharedZoneCallsModel() {
        let expectation = XCTestExpectation(description: "Shared zone add completed")
        let item = makeItem(name: "Shared Item")

        viewModel.inputs.addToSharedZone(item) { savedItem, error in
            XCTAssertNil(error)
            XCTAssertEqual(savedItem.name, "Shared Item")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(mockModel.addToSharedZoneCallCount, 1)
    }

    func testAddToSharedZoneAppendsToItemsArray() {
        let expectation = XCTestExpectation(description: "Shared zone add completed")
        let item = makeItem(name: "Shared")

        viewModel.inputs.addToSharedZone(item) { _, _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(viewModel.itemsArray.contains(where: { $0.name == "Shared" }))
    }
}

// MARK: - Mock QuickToDoModel

class MockQuickToDoModel: QuickToDoProtocol, QuickToDoInputs, QuickToDoOutputs {

    typealias Observable = RxSwift.Observable

    // Tracking properties
    var addCallCount = 0
    var lastAddToCloud = false
    var updateCallCount = 0
    var lastUpdatedOldItem: Item?
    var lastUpdatedNewItem: Item?
    var saveConfigCallCount = 0
    var configValue: QuickToDoConfig?
    var itemsToEmit: [Item] = []
    var addToSharedZoneCallCount = 0
    var lastUploadedItems: [Item]?

    private let itemsSubject = PublishSubject<Item>()
    let cloudStatusSubject = PublishSubject<CloudStatus>()

    var config: QuickToDoConfig { return configValue ?? QuickToDoConfig() }

    var items: Observable<Item> {
        return itemsSubject.asObservable()
    }

    var cloudStatus: Observable<CloudStatus> {
        return cloudStatusSubject.asObservable()
    }

    var inputs: QuickToDoInputs { return self }
    var outputs: QuickToDoOutputs { return self }

    func add(_ item: Item, addToCloud: Bool) -> (Bool, Error?) {
        addCallCount += 1
        lastAddToCloud = addToCloud
        itemsSubject.onNext(item)
        return (true, nil)
    }

    func addToSharedZone(_ item: Item, completion: @escaping (Item, Error?) -> Void) {
        addToSharedZoneCallCount += 1
        completion(item, nil)
    }

    func update(_ item: Item, withItem newItem: Item) -> (Bool, Error?) {
        updateCallCount += 1
        lastUpdatedOldItem = item
        lastUpdatedNewItem = newItem
        return (true, nil)
    }

    func getHints(for itemName: String) -> Observable<String> {
        return Observable.empty()
    }

    func getItems() -> (Bool, Error?) {
        for item in itemsToEmit {
            itemsSubject.onNext(item)
        }
        return (true, nil)
    }

    func getSharedItems(for root: CKRecord, with completion: ((Item) -> Void)?) -> (Bool, Error?) {
        return (true, nil)
    }

    func fetchAllSharedItems(completion: @escaping (Item) -> Void) -> (Bool, Error?) {
        return (true, nil)
    }

    func prepareSharing(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        handler(nil, nil, nil)
    }

    func getRootRecord() -> CKRecord? { return nil }
    func getZone() -> CKRecordZone? { return nil }
    func getCurrentShareStatus() -> CKShare? { return nil }
    func isListCurrentlyShared() -> Bool { return false }
    func refreshShareStatus() async throws -> CKShare? { return nil }

    func uploadToCloud(items: [Item]) -> (Bool, Error?) {
        lastUploadedItems = items
        return (true, nil)
    }

    func save(config: QuickToDoConfig) -> (Bool, Error?) {
        saveConfigCallCount += 1
        configValue = config
        return (true, nil)
    }

    func getConfig() -> QuickToDoConfig? {
        return configValue
    }
}
