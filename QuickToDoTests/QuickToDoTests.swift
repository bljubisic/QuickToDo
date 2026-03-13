//
//  QuickToDoTests.swift
//  QuickToDoTests
//
//  Created by Bratislav Ljubisic on 11.02.20.
//  Copyright © 2020 Bratislav Ljubisic. All rights reserved.
//
//  Test coverage is organized across the following files:
//  - QuickToDoModelTests.swift      → QuickToDoModel (conflict resolution, add, update, config, CloudKit delegation)
//  - QuickToDoViewModelTests.swift  → QuickToDoViewModel (add, update, clearList, getItems subscription, dedup)
//  - SwiftDataModelTests.swift      → SwiftDataModel (CRUD, ItemSD.toItem() edge cases)
//  - CloudKitModelTests.swift       → CloudKitModel (insert, update, fetch, sharing)
//  - DataStructuresTests.swift      → Item, Lens, ItemUD, QuickToDoConfig, Notification.Name constants
//  - IntentsTests.swift             → QuickToDoIntent, ItemCompleted
//  - ItemMOTests.swift              → Legacy ItemMO managed object
//

import XCTest
@testable import QuickToDo
