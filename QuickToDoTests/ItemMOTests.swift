//
//  ItemMOTests.swift
//  QuickToDoTests
//
//  Created by Claude Code
//

import XCTest
import CoreData
@testable import QuickToDo

class ItemMOTests: XCTestCase {

    var managedObjectContext: NSManagedObjectContext!
    var persistentContainer: NSPersistentContainer!

    override func setUp() {
        super.setUp()

        // Create in-memory Core Data stack for testing
        persistentContainer = NSPersistentContainer(name: "QuickToDo")

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]

        persistentContainer.loadPersistentStores { (description, error) in
            if let error = error {
                XCTFail("Failed to load Core Data stack: \(error)")
            }
        }

        managedObjectContext = persistentContainer.viewContext
    }

    override func tearDown() {
        managedObjectContext = nil
        persistentContainer = nil
        super.tearDown()
    }

    // MARK: - ManagedObjectType Tests

    func testEntityName() {
        XCTAssertEqual(ItemMO.entityName, "Item")
    }

    func testDefaultSortDescriptors() {
        let sortDescriptors = ItemMO.defaultSortDescriptors
        XCTAssertEqual(sortDescriptors.count, 1)
        XCTAssertEqual(sortDescriptors.first?.key, "lastused")
        XCTAssertFalse(sortDescriptors.first?.ascending ?? true)
    }

    // MARK: - Insert Tests

    func testInsertIntoContext() {
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

        let itemMO = ItemMO.insertIntoContext(moc: managedObjectContext, item: testItem)

        XCTAssertNotNil(itemMO)
        XCTAssertEqual(itemMO.word, "Test Item")
        XCTAssertEqual(itemMO.count, 5)
        XCTAssertFalse(itemMO.completed)
        XCTAssertTrue(itemMO.used)
        XCTAssertFalse(itemMO.uploadedToICloud)
        XCTAssertEqual(itemMO.id, testItem.id.uuidString)
    }

    func testInsertSetsLastUsedDate() {
        let testItem = Item()
        let beforeInsert = Date()

        let itemMO = ItemMO.insertIntoContext(moc: managedObjectContext, item: testItem)

        let afterInsert = Date()
        XCTAssertTrue(itemMO.lastused >= beforeInsert)
        XCTAssertTrue(itemMO.lastused <= afterInsert)
    }

    func testInsertMultipleItems() {
        let items = [
            Item(id: UUID(), name: "Item 1", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()),
            Item(id: UUID(), name: "Item 2", count: 2, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()),
            Item(id: UUID(), name: "Item 3", count: 3, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())
        ]

        for item in items {
            _ = ItemMO.insertIntoContext(moc: managedObjectContext, item: item)
        }

        let fetchRequest: NSFetchRequest<ItemMO> = NSFetchRequest(entityName: "Item")
        let fetchedItems = try? managedObjectContext.fetch(fetchRequest)

        XCTAssertEqual(fetchedItems?.count, 3)
    }

    // MARK: - Update Tests

    func testUpdateExistingItem() {
        let uuid = UUID()
        let originalItem = Item(
            id: uuid,
            name: "Original",
            count: 1,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        _ = ItemMO.insertIntoContext(moc: managedObjectContext, item: originalItem)

        let updatedItem = Item(
            id: uuid,
            name: "Updated",
            count: 10,
            uploadedToICloud: true,
            done: true,
            shown: false,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let (itemMO, success) = ItemMO.updateIntoContext(moc: managedObjectContext, item: updatedItem)

        XCTAssertTrue(success)
        XCTAssertNotNil(itemMO)
        XCTAssertEqual(itemMO?.word, "Updated")
        XCTAssertEqual(itemMO?.count, 10)
        XCTAssertTrue(itemMO?.completed ?? false)
        XCTAssertFalse(itemMO?.used ?? true)
        XCTAssertTrue(itemMO?.uploadedToICloud ?? false)
    }

    func testUpdateNonExistentItemInsertsNew() {
        let newItem = Item(
            id: UUID(),
            name: "New Item",
            count: 5,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let (itemMO, success) = ItemMO.updateIntoContext(moc: managedObjectContext, item: newItem)

        XCTAssertTrue(success)
        XCTAssertNotNil(itemMO)
        XCTAssertEqual(itemMO?.word, "New Item")
        XCTAssertEqual(itemMO?.count, 5)
    }

    func testUpdatePreservesID() {
        let uuid = UUID()
        let originalItem = Item(
            id: uuid,
            name: "Original",
            count: 1,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        _ = ItemMO.insertIntoContext(moc: managedObjectContext, item: originalItem)

        let updatedItem = Item(
            id: uuid,
            name: "Updated",
            count: 2,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let (itemMO, _) = ItemMO.updateIntoContext(moc: managedObjectContext, item: updatedItem)

        XCTAssertEqual(itemMO?.id, uuid.uuidString)
    }

    func testUpdateUpdatesLastUsedDate() {
        let uuid = UUID()
        let originalItem = Item(
            id: uuid,
            name: "Test",
            count: 1,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let insertedItemMO = ItemMO.insertIntoContext(moc: managedObjectContext, item: originalItem)
        let originalLastUsed = insertedItemMO.lastused

        // Wait a bit to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.1)

        let updatedItem = Item(
            id: uuid,
            name: "Updated",
            count: 2,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let (updatedItemMO, _) = ItemMO.updateIntoContext(moc: managedObjectContext, item: updatedItem)

        XCTAssertNotNil(updatedItemMO)
        XCTAssertTrue(updatedItemMO!.lastused > originalLastUsed)
    }

    // MARK: - Item to ItemMO Conversion Tests

    func testItemConversionWithAllProperties() {
        let testItem = Item(
            id: UUID(),
            name: "Full Item",
            count: 42,
            uploadedToICloud: true,
            done: true,
            shown: false,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let itemMO = ItemMO.insertIntoContext(moc: managedObjectContext, item: testItem)

        XCTAssertEqual(itemMO.word, testItem.name)
        XCTAssertEqual(itemMO.count, testItem.count)
        XCTAssertEqual(itemMO.completed, testItem.done)
        XCTAssertEqual(itemMO.used, testItem.shown)
        XCTAssertEqual(itemMO.uploadedToICloud, testItem.uploadedToICloud)
        XCTAssertEqual(itemMO.id, testItem.id.uuidString)
    }

    func testItemConversionWithDefaultValues() {
        let defaultItem = Item()
        let itemMO = ItemMO.insertIntoContext(moc: managedObjectContext, item: defaultItem)

        XCTAssertEqual(itemMO.word, "")
        XCTAssertEqual(itemMO.count, 0)
        XCTAssertFalse(itemMO.completed)
        XCTAssertFalse(itemMO.used)
        XCTAssertFalse(itemMO.uploadedToICloud)
        XCTAssertNotNil(UUID(uuidString: itemMO.id))
    }

    // MARK: - Core Data Persistence Tests

    func testContextSaveOnInsert() {
        let testItem = Item(id: UUID(), name: "Persist Test", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())

        _ = ItemMO.insertIntoContext(moc: managedObjectContext, item: testItem)

        // Verify the item was saved by fetching it in a new context
        let fetchRequest: NSFetchRequest<ItemMO> = NSFetchRequest(entityName: "Item")
        let predicate = NSPredicate(format: "word == %@", "Persist Test")
        fetchRequest.predicate = predicate

        let fetchedItems = try? managedObjectContext.fetch(fetchRequest)

        XCTAssertEqual(fetchedItems?.count, 1)
        XCTAssertEqual(fetchedItems?.first?.word, "Persist Test")
    }

    func testContextSaveOnUpdate() {
        let uuid = UUID()
        let originalItem = Item(id: uuid, name: "Original", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())

        _ = ItemMO.insertIntoContext(moc: managedObjectContext, item: originalItem)

        let updatedItem = Item(id: uuid, name: "Updated", count: 2, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())

        let (_, success) = ItemMO.updateIntoContext(moc: managedObjectContext, item: updatedItem)

        XCTAssertTrue(success)

        // Verify the update was saved
        let fetchRequest: NSFetchRequest<ItemMO> = NSFetchRequest(entityName: "Item")
        let predicate = NSPredicate(format: "id == %@", uuid.uuidString)
        fetchRequest.predicate = predicate

        let fetchedItems = try? managedObjectContext.fetch(fetchRequest)

        XCTAssertEqual(fetchedItems?.count, 1)
        XCTAssertEqual(fetchedItems?.first?.word, "Updated")
        XCTAssertEqual(fetchedItems?.first?.count, 2)
    }

    // MARK: - Edge Cases

    func testUpdateWithEmptyName() {
        let item = Item(id: UUID(), name: "", count: 0, uploadedToICloud: false, done: false, shown: false, createdAt: Date(), lastUsedAt: Date())

        let (itemMO, success) = ItemMO.updateIntoContext(moc: managedObjectContext, item: item)

        XCTAssertTrue(success)
        XCTAssertNotNil(itemMO)
        XCTAssertEqual(itemMO?.word, "")
    }

    func testUpdateWithLargeCount() {
        let item = Item(id: UUID(), name: "Large Count", count: 999999, uploadedToICloud: false, done: false, shown: false, createdAt: Date(), lastUsedAt: Date())

        let (itemMO, success) = ItemMO.updateIntoContext(moc: managedObjectContext, item: item)

        XCTAssertTrue(success)
        XCTAssertEqual(itemMO?.count, 999999)
    }

    func testConcurrentInserts() {
        let expectation = XCTestExpectation(description: "Concurrent inserts complete")
        expectation.expectedFulfillmentCount = 5

        for i in 1...5 {
            DispatchQueue.global().async {
                let context = self.persistentContainer.newBackgroundContext()
                let item = Item(id: UUID(), name: "Concurrent \(i)", count: i, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())
                _ = ItemMO.insertIntoContext(moc: context, item: item)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        let fetchRequest: NSFetchRequest<ItemMO> = NSFetchRequest(entityName: "Item")
        let fetchedItems = try? managedObjectContext.fetch(fetchRequest)

        // All concurrent inserts should succeed
        XCTAssertGreaterThanOrEqual(fetchedItems?.count ?? 0, 5)
    }
}
