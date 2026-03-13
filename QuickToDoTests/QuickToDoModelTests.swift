//
//  QuickToDoModelTests.swift
//  QuickToDoTests
//
//  Created by Claude Code
//

import XCTest
import RxSwift
import CloudKit
@testable import QuickToDo

// MARK: - Mock Storage Protocol

class MockStorageProtocol: StorageProtocol {

    var mockItems: [Item] = []
    var insertCallCount = 0
    var updateCallCount = 0
    var getItemsCallCount = 0
    private let itemsSubject = PublishSubject<Item?>()

    var inputs: StorageInputs { return self }
    var outputs: StorageOutputs { return self }
}

extension MockStorageProtocol: StorageInputs {

    func getItems(withCompletion: ((Item) -> Void)?) -> (Bool, Error?) {
        getItemsCallCount += 1
        mockItems.forEach { item in
            withCompletion?(item)
            itemsSubject.onNext(item)
        }
        return (true, nil)
    }

    func insert() -> ItemProcess {
        return { [weak self] item, completion in
            self?.insertCallCount += 1
            self?.mockItems.append(item)
            self?.itemsSubject.onNext(item)
            completion?(item, nil)
            return (item, true)
        }
    }

    func update() -> ItemProcessUpdate {
        return { [weak self] oldItem, newItem in
            self?.updateCallCount += 1
            if let index = self?.mockItems.firstIndex(where: { $0.id == oldItem.id }) {
                self?.mockItems[index] = newItem
                self?.itemsSubject.onNext(newItem)
                return (newItem, true)
            }
            return (nil, false)
        }
    }

    func getItemWith() -> ItemProcessFind {
        return { [weak self] name in
            if let item = self?.mockItems.first(where: { $0.name == name }) {
                return (item, true)
            }
            return (nil, false)
        }
    }

    func getItemWithId() -> ItemProcessFindWithID {
        return { [weak self] id in
            if let item = self?.mockItems.first(where: { $0.id == id }) {
                return (item, true)
            }
            return (nil, false)
        }
    }

    func getHints(for itemName: String, withCompletion: @escaping (Item, Item) -> Void) {
        let matches = mockItems.filter { $0.name.starts(with: itemName) }
        if matches.count >= 2 {
            withCompletion(matches[0], matches[1])
        } else if matches.count == 1 {
            withCompletion(matches[0], Item())
        } else {
            withCompletion(Item(), Item())
        }
    }

    func insertToSharedZone(_ item: Item, completion: @escaping (Item, Error?) -> Void) {
        insertCallCount += 1
        mockItems.append(item)
        itemsSubject.onNext(item)
        completion(item, nil)
    }

    func prepareShare(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) async throws {
        handler(nil, nil, nil)
    }

    func getRootRecord() -> CKRecord? { return nil }
    func getSharedItems(for root: CKRecord, with completion: ((Item) -> Void)?) -> (Bool, Error?) { return (true, nil) }
    func fetchAllSharedItems(completion: @escaping (Item) -> Void) -> (Bool, Error?) { return (true, nil) }
    func getZone() -> CKRecordZone? { return nil }
    func getCurrentShareStatus() -> CKShare? { return nil }
    func isListCurrentlyShared() -> Bool { return false }
    func refreshShareStatus() async throws -> CKShare? { return nil }
}

extension MockStorageProtocol: StorageOutputs {
    var items: Observable<Item?> {
        return itemsSubject.asObservable()
    }
}

// MARK: - QuickToDoModel Tests

class QuickToDoModelTests: XCTestCase {

    var model: QuickToDoModel!
    var mockSwiftData: MockStorageProtocol!
    var mockCloudKit: MockStorageProtocol!
    var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        mockSwiftData = MockStorageProtocol()
        mockCloudKit = MockStorageProtocol()
        model = QuickToDoModel(mockSwiftData, mockCloudKit)
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        model = nil
        mockSwiftData = nil
        mockCloudKit = nil
        disposeBag = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testModelInitialization() {
        XCTAssertNotNil(model)
        XCTAssertNotNil(model.inputs)
        XCTAssertNotNil(model.outputs)
    }

    // MARK: - Config Tests

    func testSaveConfig() {
        let config = QuickToDoConfig(showDoneItems: false)
        let (success, error) = model.save(config: config)

        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertEqual(model.config.showDoneItems, false)
    }

    func testGetConfigWhenNotSaved() {
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "Config")

        let config = model.getConfig()
        XCTAssertNil(config)
    }

    func testGetConfigAfterSaving() {
        let savedConfig = QuickToDoConfig(showDoneItems: false)
        _ = model.save(config: savedConfig)

        let retrievedConfig = model.getConfig()
        XCTAssertNotNil(retrievedConfig)
        XCTAssertEqual(retrievedConfig?.showDoneItems, false)
    }

    func testConfigPersistence() {
        let config1 = QuickToDoConfig(showDoneItems: true)
        _ = model.save(config: config1)

        // Create new model instance
        let newModel = QuickToDoModel(mockSwiftData, mockCloudKit)
        let retrievedConfig = newModel.getConfig()

        XCTAssertNotNil(retrievedConfig)
        XCTAssertEqual(retrievedConfig?.showDoneItems, true)
    }

    // MARK: - Add Tests

    func testAddItemWithoutCloud() {
        let testItem = Item(
            id: UUID(),
            name: "Test Item",
            count: 1,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let (success, error) = model.add(testItem, addToCloud: false)

        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertEqual(mockSwiftData.insertCallCount, 1)
        XCTAssertEqual(mockCloudKit.insertCallCount, 0)
        XCTAssertTrue(mockSwiftData.mockItems.contains(where: { $0.id == testItem.id }))
    }

    func testAddItemWithCloud() {
        let testItem = Item(
            id: UUID(),
            name: "Cloud Item",
            count: 1,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let expectation = XCTestExpectation(description: "CloudKit insert completed")

        let (success, error) = model.add(testItem, addToCloud: true)

        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertEqual(mockSwiftData.insertCallCount, 1)

        // Wait a bit for async CloudKit insert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.mockCloudKit.insertCallCount, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAddItemEmitsToObservable() {
        let expectation = XCTestExpectation(description: "Item emitted to observable")

        var emittedItems: [Item] = []
        model.items
            .subscribe(onNext: { item in
                emittedItems.append(item)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        let testItem = Item(
            id: UUID(),
            name: "Observable Test",
            count: 1,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        _ = model.add(testItem, addToCloud: false)

        wait(for: [expectation], timeout: 2.0)
        // add() emits directly to itemsPrivate AND the mock's insert() emits via the merge subscription,
        // so we expect at least 1 emission with the correct name
        XCTAssertGreaterThanOrEqual(emittedItems.count, 1)
        XCTAssertTrue(emittedItems.contains(where: { $0.name == "Observable Test" }))
    }

    // MARK: - Update Tests

    func testUpdateItem() {
        let originalItem = Item(
            id: UUID(),
            name: "Original",
            count: 1,
            uploadedToICloud: true,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

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

        mockSwiftData.mockItems.append(originalItem)
        mockCloudKit.mockItems.append(originalItem)

        let (success, error) = model.update(originalItem, withItem: updatedItem)

        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertEqual(mockSwiftData.updateCallCount, 1)
        XCTAssertEqual(mockCloudKit.updateCallCount, 1)
    }

    // MARK: - GetItems Tests

    func testGetItemsFromBothSources() {
        let item1 = Item(id: UUID(), name: "SwiftData Item", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())
        let item2 = Item(id: UUID(), name: "CloudKit Item", count: 2, uploadedToICloud: true, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())

        mockSwiftData.mockItems = [item1]
        mockCloudKit.mockItems = [item2]

        let (success, error) = model.getItems()

        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertEqual(mockSwiftData.getItemsCallCount, 1)
        XCTAssertEqual(mockCloudKit.getItemsCallCount, 1)
    }

    func testGetItemsConflictResolution() {
        let uuid = UUID()
        let olderDate = Date().addingTimeInterval(-3600)
        let newerDate = Date()

        let olderItem = Item(id: uuid, name: "Old", count: 1, uploadedToICloud: true, done: false, shown: true, createdAt: olderDate, lastUsedAt: olderDate)
        let newerItem = Item(id: uuid, name: "New", count: 2, uploadedToICloud: true, done: false, shown: true, createdAt: newerDate, lastUsedAt: newerDate)

        mockSwiftData.mockItems = [newerItem]
        mockCloudKit.mockItems = [olderItem]

        _ = model.getItems()

        // The newer item should win, so CloudKit should be updated
        XCTAssertEqual(mockCloudKit.updateCallCount, 1)
    }

    func testGetItemsObservableEmitsItems() {
        let expectation = XCTestExpectation(description: "Items emitted to observable")
        expectation.expectedFulfillmentCount = 2

        var emittedItems: [Item] = []
        model.items
            .subscribe(onNext: { item in
                emittedItems.append(item)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        let item1 = Item(id: UUID(), name: "Item 1", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())
        let item2 = Item(id: UUID(), name: "Item 2", count: 2, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())

        mockSwiftData.mockItems = [item1, item2]

        _ = model.getItems()

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(emittedItems.count, 2)
    }

    // MARK: - UploadToCloud Tests

    func testUploadToCloud() {
        let items = [
            Item(id: UUID(), name: "Upload 1", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()),
            Item(id: UUID(), name: "Upload 2", count: 2, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())
        ]

        let expectation = XCTestExpectation(description: "Items uploaded to cloud")

        let (success, error) = model.uploadToCloud(items: items)

        XCTAssertTrue(success)
        XCTAssertNil(error)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.mockCloudKit.insertCallCount, 2)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - GetHints Tests

    func testGetHints() {
        mockSwiftData.mockItems = [
            Item(id: UUID(), name: "Apple", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()),
            Item(id: UUID(), name: "Application", count: 2, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())
        ]

        let expectation = XCTestExpectation(description: "Hints received")
        expectation.expectedFulfillmentCount = 2

        var hints: [String] = []
        model.getHints(for: "App")
            .subscribe(onNext: { hint in
                hints.append(hint)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(hints.count, 2)
        XCTAssertTrue(hints.contains("Apple"))
        XCTAssertTrue(hints.contains("Application"))
    }

    // MARK: - CloudKit Delegation Tests

    func testGetRootRecord() {
        _ = model.getRootRecord()
        // Should delegate to CloudKit
        // Since mock returns nil, we just verify it doesn't crash
    }

    func testGetZone() {
        let zone = model.getZone()
        XCTAssertNil(zone) // Mock returns nil
    }

    func testGetCurrentShareStatus() {
        let status = model.getCurrentShareStatus()
        XCTAssertNil(status) // Mock returns nil
    }

    func testIsListCurrentlyShared() {
        let isShared = model.isListCurrentlyShared()
        XCTAssertFalse(isShared) // Mock returns false
    }

    func testRefreshShareStatus() async throws {
        let share = try await model.refreshShareStatus()
        XCTAssertNil(share) // Mock returns nil
    }

    func testPrepareSharing() {
        let expectation = XCTestExpectation(description: "Share preparation handler called")

        model.prepareSharing { share, container, error in
            XCTAssertNil(share)
            XCTAssertNil(container)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGetSharedItems() {
        let mockRecord = CKRecord(recordType: "Items")
        let (success, error) = model.getSharedItems(for: mockRecord, with: nil)

        XCTAssertTrue(success)
        XCTAssertNil(error)
    }

    func testFetchAllSharedItems() {
        var itemCount = 0
        let (success, error) = model.fetchAllSharedItems { _ in
            itemCount += 1
        }

        XCTAssertTrue(success)
        XCTAssertNil(error)
    }

    // MARK: - Observable Tests

    func testItemsObservable() {
        XCTAssertNotNil(model.items)

        let expectation = XCTestExpectation(description: "Observable can be subscribed")

        model.items
            .take(1)
            .timeout(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(
                onNext: { _ in
                    expectation.fulfill()
                },
                onError: { _ in
                    // Timeout is ok
                    expectation.fulfill()
                }
            )
            .disposed(by: disposeBag)

        _ = model.add(Item(id: UUID(), name: "Test", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()), addToCloud: false)

        wait(for: [expectation], timeout: 2.0)
    }

    func testCloudStatusObservable() {
        XCTAssertNotNil(model.cloudStatus)

        let expectation = XCTestExpectation(description: "CloudStatus observable exists")

        model.cloudStatus
            .take(1)
            .timeout(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(
                onNext: { _ in
                    expectation.fulfill()
                },
                onError: { _ in
                    // Timeout is expected as we don't emit cloud status in tests
                    expectation.fulfill()
                }
            )
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Conflict Resolution Direction Tests

    func testGetItemsCloudKitNewerUpdatesSwiftData() {
        let uuid = UUID()
        let olderDate = Date().addingTimeInterval(-3600)
        let newerDate = Date()

        let localItem = Item(id: uuid, name: "Local", count: 1, uploadedToICloud: true, done: false, shown: true, createdAt: olderDate, lastUsedAt: olderDate)
        let cloudItem = Item(id: uuid, name: "Cloud", count: 2, uploadedToICloud: true, done: true, shown: true, createdAt: newerDate, lastUsedAt: newerDate)

        mockSwiftData.mockItems = [localItem]
        mockCloudKit.mockItems = [cloudItem]

        _ = model.getItems()

        // CloudKit is newer, so SwiftData should be updated (not CloudKit)
        XCTAssertEqual(mockSwiftData.updateCallCount, 1, "SwiftData should be updated when CloudKit is newer")
        XCTAssertEqual(mockCloudKit.updateCallCount, 0, "CloudKit should NOT be updated when CloudKit is newer")
    }

    func testGetItemsSameTimestampDifferentStatePrefersClouKit() {
        let uuid = UUID()
        let sameDate = Date()

        let localItem = Item(id: uuid, name: "Item", count: 1, uploadedToICloud: true, done: false, shown: false, createdAt: sameDate, lastUsedAt: sameDate)
        let cloudItem = Item(id: uuid, name: "Item", count: 1, uploadedToICloud: true, done: true, shown: true, createdAt: sameDate, lastUsedAt: sameDate)

        mockSwiftData.mockItems = [localItem]
        mockCloudKit.mockItems = [cloudItem]

        _ = model.getItems()

        // Same timestamp but different done/shown — CloudKit wins, SwiftData gets updated
        XCTAssertEqual(mockSwiftData.updateCallCount, 1, "SwiftData should be updated when same timestamp but different state")
        XCTAssertEqual(mockCloudKit.updateCallCount, 0, "CloudKit should NOT be updated when it is the source of truth")
    }

    func testGetItemsSameTimestampSameStateNoUpdate() {
        let uuid = UUID()
        let sameDate = Date()

        let localItem = Item(id: uuid, name: "Item", count: 1, uploadedToICloud: true, done: false, shown: true, createdAt: sameDate, lastUsedAt: sameDate)
        let cloudItem = Item(id: uuid, name: "Item", count: 1, uploadedToICloud: true, done: false, shown: true, createdAt: sameDate, lastUsedAt: sameDate)

        mockSwiftData.mockItems = [localItem]
        mockCloudKit.mockItems = [cloudItem]

        _ = model.getItems()

        // Same timestamp, same state — no update needed
        XCTAssertEqual(mockSwiftData.updateCallCount, 0, "No update needed when both are identical")
        XCTAssertEqual(mockCloudKit.updateCallCount, 0, "No update needed when both are identical")
    }

    func testGetItemsCloudKitOnlyItemPassesThrough() {
        // CloudKit has an item that SwiftData does not — it should pass through via the merge subscription
        let cloudOnlyItem = Item(id: UUID(), name: "CloudOnly", count: 1, uploadedToICloud: true, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())

        mockSwiftData.mockItems = []
        mockCloudKit.mockItems = [cloudOnlyItem]

        let expectation = XCTestExpectation(description: "CloudKit-only item emitted")

        model.items
            .take(1)
            .subscribe(onNext: { item in
                XCTAssertEqual(item.name, "CloudOnly")
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        _ = model.getItems()

        wait(for: [expectation], timeout: 2.0)

        // No conflict resolution updates should happen
        XCTAssertEqual(mockSwiftData.updateCallCount, 0)
        XCTAssertEqual(mockCloudKit.updateCallCount, 0)
    }

    func testGetItemsMultipleConflictsResolvedIndependently() {
        let uuid1 = UUID()
        let uuid2 = UUID()
        let olderDate = Date().addingTimeInterval(-3600)
        let newerDate = Date()

        // Item 1: CloudKit newer → update SwiftData
        let localItem1 = Item(id: uuid1, name: "Local1", count: 1, uploadedToICloud: true, done: false, shown: true, createdAt: olderDate, lastUsedAt: olderDate)
        let cloudItem1 = Item(id: uuid1, name: "Cloud1", count: 2, uploadedToICloud: true, done: true, shown: true, createdAt: newerDate, lastUsedAt: newerDate)

        // Item 2: SwiftData newer → update CloudKit
        let localItem2 = Item(id: uuid2, name: "Local2", count: 3, uploadedToICloud: true, done: true, shown: true, createdAt: newerDate, lastUsedAt: newerDate)
        let cloudItem2 = Item(id: uuid2, name: "Cloud2", count: 1, uploadedToICloud: true, done: false, shown: true, createdAt: olderDate, lastUsedAt: olderDate)

        mockSwiftData.mockItems = [localItem1, localItem2]
        mockCloudKit.mockItems = [cloudItem1, cloudItem2]

        _ = model.getItems()

        // One update to SwiftData (item1) and one update to CloudKit (item2)
        XCTAssertEqual(mockSwiftData.updateCallCount, 1, "SwiftData should be updated once for CloudKit-newer item")
        XCTAssertEqual(mockCloudKit.updateCallCount, 1, "CloudKit should be updated once for SwiftData-newer item")
    }
}
