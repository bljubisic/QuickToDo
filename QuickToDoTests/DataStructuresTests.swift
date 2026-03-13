//
//  DataStructuresTests.swift
//  QuickToDoTests
//
//  Created by Claude Code
//

import XCTest
@testable import QuickToDo

class DataStructuresTests: XCTestCase {

    // MARK: - Item Tests

    func testItemDefaultInitialization() {
        let item = Item()

        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.name, "")
        XCTAssertEqual(item.count, 0)
        XCTAssertFalse(item.uploadedToICloud)
        XCTAssertFalse(item.done)
        XCTAssertFalse(item.shown)
        XCTAssertNotNil(item.createdAt)
        XCTAssertNotNil(item.lastUsedAt)
    }

    func testItemCustomInitialization() {
        let uuid = UUID()
        let createdDate = Date()
        let lastUsedDate = Date().addingTimeInterval(3600)

        let item = Item(
            id: uuid,
            name: "Test Item",
            count: 5,
            uploadedToICloud: true,
            done: false,
            shown: true,
            createdAt: createdDate,
            lastUsedAt: lastUsedDate
        )

        XCTAssertEqual(item.id, uuid)
        XCTAssertEqual(item.name, "Test Item")
        XCTAssertEqual(item.count, 5)
        XCTAssertTrue(item.uploadedToICloud)
        XCTAssertFalse(item.done)
        XCTAssertTrue(item.shown)
        XCTAssertEqual(item.createdAt, createdDate)
        XCTAssertEqual(item.lastUsedAt, lastUsedDate)
    }

    func testItemIdentifiableConformance() {
        let item = Item()
        XCTAssertNotNil(item.id)
    }

    // MARK: - Item Lens Tests

    func testItemNameLens() {
        let originalItem = Item(
            id: UUID(),
            name: "Original",
            count: 1,
            uploadedToICloud: false,
            done: false,
            shown: false,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let updatedItem = Item.itemNameLens.set("Updated", originalItem)

        XCTAssertEqual(updatedItem.name, "Updated")
        XCTAssertEqual(updatedItem.id, originalItem.id)
        XCTAssertEqual(updatedItem.count, originalItem.count)
    }

    func testItemCountLens() {
        let originalItem = Item()
        let updatedItem = Item.itemCountLens.set(10, originalItem)

        XCTAssertEqual(updatedItem.count, 10)
        XCTAssertEqual(Item.itemCountLens.get(updatedItem), 10)
    }

    func testItemDoneLens() {
        let originalItem = Item()
        XCTAssertFalse(Item.itemDoneLens.get(originalItem))

        let updatedItem = Item.itemDoneLens.set(true, originalItem)
        XCTAssertTrue(Item.itemDoneLens.get(updatedItem))
    }

    func testItemShownLens() {
        let originalItem = Item()
        let updatedItem = Item.itemShownLens.set(true, originalItem)

        XCTAssertTrue(updatedItem.shown)
        XCTAssertFalse(originalItem.shown)
    }

    func testItemUploadedToICloudLens() {
        let originalItem = Item()
        let updatedItem = Item.itemUploadedToICloudLens.set(true, originalItem)

        XCTAssertTrue(updatedItem.uploadedToICloud)
        XCTAssertFalse(originalItem.uploadedToICloud)
    }

    func testItemLensesPreserveOtherProperties() {
        let uuid = UUID()
        let createdDate = Date()
        let lastUsedDate = Date().addingTimeInterval(3600)

        let originalItem = Item(
            id: uuid,
            name: "Test",
            count: 5,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: createdDate,
            lastUsedAt: lastUsedDate
        )

        let updatedItem = Item.itemNameLens.set("NewName", originalItem)

        XCTAssertEqual(updatedItem.id, uuid)
        XCTAssertEqual(updatedItem.count, 5)
        XCTAssertFalse(updatedItem.uploadedToICloud)
        XCTAssertFalse(updatedItem.done)
        XCTAssertTrue(updatedItem.shown)
        XCTAssertEqual(updatedItem.createdAt, createdDate)
        XCTAssertEqual(updatedItem.lastUsedAt, lastUsedDate)
    }

    // MARK: - ItemUD (NSSecureCoding) Tests

    func testItemUDDefaultInitialization() {
        let itemUD = ItemUD()

        XCTAssertEqual(itemUD.id, "")
        XCTAssertEqual(itemUD.word, "")
        XCTAssertFalse(itemUD.done)
    }

    func testItemUDCustomInitialization() {
        let itemUD = ItemUD(id: "123", word: "Test", done: true)

        XCTAssertEqual(itemUD.id, "123")
        XCTAssertEqual(itemUD.word, "Test")
        XCTAssertTrue(itemUD.done)
    }

    func testItemUDSupportsSecureCoding() {
        XCTAssertTrue(ItemUD.supportsSecureCoding)
    }

    func testItemUDEncoding() throws {
        let itemUD = ItemUD(id: "test-id", word: "Test Word", done: true)
        let data = try NSKeyedArchiver.archivedData(withRootObject: itemUD, requiringSecureCoding: true)

        XCTAssertFalse(data.isEmpty)
    }

    func testItemUDDecoding() throws {
        let originalItem = ItemUD(id: "test-id", word: "Test Word", done: true)
        let data = try NSKeyedArchiver.archivedData(withRootObject: originalItem, requiringSecureCoding: true)

        guard let decodedItem = try NSKeyedUnarchiver.unarchivedObject(ofClass: ItemUD.self, from: data) else {
            XCTFail("Failed to decode ItemUD")
            return
        }

        XCTAssertEqual(decodedItem.id, originalItem.id)
        XCTAssertEqual(decodedItem.word, originalItem.word)
        XCTAssertEqual(decodedItem.done, originalItem.done)
    }

    func testItemUDEncodingDecodingRoundTrip() throws {
        let items = [
            ItemUD(id: "1", word: "First", done: false),
            ItemUD(id: "2", word: "Second", done: true),
            ItemUD(id: "", word: "", done: false)
        ]

        for originalItem in items {
            let data = try NSKeyedArchiver.archivedData(withRootObject: originalItem, requiringSecureCoding: true)
            guard let decodedItem = try NSKeyedUnarchiver.unarchivedObject(ofClass: ItemUD.self, from: data) else {
                XCTFail("Failed to decode ItemUD")
                continue
            }

            XCTAssertEqual(decodedItem.id, originalItem.id)
            XCTAssertEqual(decodedItem.word, originalItem.word)
            XCTAssertEqual(decodedItem.done, originalItem.done)
        }
    }

    // MARK: - QuickToDoConfig Tests

    func testQuickToDoConfigDefaultInitialization() {
        let config = QuickToDoConfig()
        XCTAssertTrue(config.showDoneItems)
    }

    func testQuickToDoConfigCustomInitialization() {
        let config = QuickToDoConfig(showDoneItems: false)
        XCTAssertFalse(config.showDoneItems)
    }

    func testQuickToDoConfigCodable() throws {
        let config = QuickToDoConfig(showDoneItems: false)

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(QuickToDoConfig.self, from: data)

        XCTAssertEqual(decodedConfig.showDoneItems, config.showDoneItems)
    }

    func testQuickToDoConfigShowDoneItemsLens() {
        let originalConfig = QuickToDoConfig()
        XCTAssertTrue(QuickToDoConfig.showDoneItemsLens.get(originalConfig))

        let updatedConfig = QuickToDoConfig.showDoneItemsLens.set(false, originalConfig)
        XCTAssertFalse(QuickToDoConfig.showDoneItemsLens.get(updatedConfig))
    }

    // MARK: - CloudStatus Enum Tests

    func testCloudStatusValues() {
        let statuses: [CloudStatus] = [.allUpdated, .updating, .connected, .disconnected]
        XCTAssertEqual(statuses.count, 4)
    }

    // MARK: - RecordZones Enum Tests

    func testRecordZonesDescription() {
        XCTAssertEqual(RecordZones.quickToDoZone.description, "QuickToDoZone")
        XCTAssertEqual(RecordZones.sharedZone.description, "SharedZone")
    }

    // MARK: - ItemFields Enum Tests

    func testItemFieldsDescription() {
        XCTAssertEqual(ItemFields.name.description, "Name")
        XCTAssertEqual(ItemFields.count.description, "Count")
        XCTAssertEqual(ItemFields.done.description, "Done")
        XCTAssertEqual(ItemFields.used.description, "Used")
        XCTAssertEqual(ItemFields.id.description, "Id")
    }

    // MARK: - Config Tests

    func testConfigContainerIdentifier() {
        XCTAssertEqual(Config.containerIdentifier, "iCloud.Persukibo.QuickToDo")
    }

    // MARK: - Lens Generic Tests

    func testLensComposition() {
        let originalItem = Item()

        let step1 = Item.itemNameLens.set("Test", originalItem)
        let step2 = Item.itemCountLens.set(5, step1)
        let step3 = Item.itemDoneLens.set(true, step2)

        XCTAssertEqual(step3.name, "Test")
        XCTAssertEqual(step3.count, 5)
        XCTAssertTrue(step3.done)
        XCTAssertEqual(step3.id, originalItem.id)
    }

    // MARK: - Notification.Name Constants Tests

    func testCloudKitPrivateDataChangedNotificationName() {
        XCTAssertEqual(Notification.Name.cloudKitPrivateDataChanged.rawValue, "CloudKitPrivateDataChanged")
    }

    func testCloudKitSharedDataChangedNotificationName() {
        XCTAssertEqual(Notification.Name.cloudKitSharedDataChanged.rawValue, "CloudKitSharedDataChanged")
    }

    func testCloudKitRecordZoneChangedNotificationName() {
        XCTAssertEqual(Notification.Name.cloudKitRecordZoneChanged.rawValue, "CloudKitRecordZoneChanged")
    }

    func testRefreshSharedItemsNotificationName() {
        XCTAssertEqual(Notification.Name.refreshSharedItems.rawValue, "RefreshSharedItems")
    }

    func testNotificationNamesAreDistinct() {
        let names: [Notification.Name] = [
            .cloudKitPrivateDataChanged,
            .cloudKitSharedDataChanged,
            .cloudKitRecordZoneChanged,
            .refreshSharedItems
        ]
        // All notification names should be unique
        let uniqueNames = Set(names)
        XCTAssertEqual(uniqueNames.count, names.count, "All notification names must be unique")
    }

    // MARK: - QuickToDoError Tests

    func testQuickToDoErrorIsError() {
        let error: Error = QuickToDoError()
        XCTAssertNotNil(error)
        XCTAssertTrue(error is QuickToDoError)
    }
}
