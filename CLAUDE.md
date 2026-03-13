# QuickToDo

A SwiftUI iOS app for managing to-do items with iCloud synchronization and sharing via CloudKit.

## Tech Layers
- **Framework**: SwiftUI + UIKit (storyboard for root), WidgetKit, Intents
- **Language**: Swift 5.0
- **Database**: SwiftData (primary, local + group container) + CloudKit (iCloud sync/sharing)
- **Reactive**: RxSwift (model layer) + Combine/@Published (ViewModel → SwiftUI)
- **Testing**: XCTest
- **iOS Target**: 17.0 minimum

## Project Structure
```
QuickToDo/
├── Model/                    # Data layer
│   ├── QuickToDoModel.swift         # Orchestrator: merges SwiftData + CloudKit observables
│   ├── QuickToDoModelProtocol.swift # Protocols: StorageProtocol, QuickToDoProtocol (Input/Output split)
│   ├── DataStructures.swift         # Item struct, CloudStatus enum, Lens utilities
│   ├── CloudKit/
│   │   └── CloudKitModel.swift      # CloudKit CRUD, sharing, subscriptions, change tokens
│   ├── CoreData/
│   │   ├── SwiftDataModel.swift     # SwiftData persistence (primary local store)
│   │   ├── ItemSD.swift             # @Model class for SwiftData
│   │   ├── ItemMO.swift             # Legacy CoreData managed object (kept for reference)
│   │   ├── AppModelContainer.swift  # Shared ModelContainer in App Group
│   │   └── SwiftDataModelActor.swift
│   └── Intents/
│       ├── QuickToDoIntent.swift
│       └── ItemCompleted.swift
├── ViewModel/
│   ├── QuickToDoViewModel.swift         # Converts RxSwift observables → @Published for SwiftUI
│   └── QuickToDoViewModelProtocol.swift # Input/Output protocol split
├── View/
│   ├── MainView.swift           # Root: TabView with regular/shared items tabs
│   ├── ItemsView.swift          # Items list with add/edit functionality
│   ├── Toolbar.swift            # Action buttons (refresh, share, clear, toggle done)
│   ├── SharingStatusView.swift  # Sharing badge UI
│   ├── CloudSharingView.swift   # CloudKit native sharing sheet
│   └── CloudKitShareManager.swift  # EnvironmentObject for share acceptance
├── AppDelegate.swift            # Notifications, CloudKit share acceptance, remote notifications
├── SceneDelegate.swift          # Scene lifecycle
├── Config.plist                 # sharingEnabled flag, sharingList array
├── QuickToDo.xcdatamodeld/      # Legacy CoreData schema (SwiftData is active)
└── Images.xcassets/
QuickToDoWidget/                 # Home screen widget (reads from shared App Group)
QuickToDoIntents/                # Siri Shortcuts extension
QuickToDoIntentsUI/              # Siri Shortcuts UI extension
QuickToDoTests/                  # XCTest unit tests for all layers
```

## Development
```bash
open QuickToDo.xcodeproj    # Open in Xcode
# Build & run via Xcode (Cmd+R)
# Test via Xcode (Cmd+U) or Product > Test
```

## Code Standards
- MVVM architecture with protocol-based Input/Output split on every layer
- Each protocol has `Inputs` and `Outputs` sub-protocols (e.g., `StorageInputs`, `StorageOutputs`)
- Model classes implement protocols via extensions per-protocol, not in the main class body
- Closure-returning methods pattern: `insert()` returns `ItemProcess`, not an immediate action
- Return tuples `(Bool, Error?)` for operation results instead of Swift throws
- Functional Lens pattern (`Item.itemNameLens.set(...)`) for immutable struct updates
- Thread safety via `synchronizationQueue` with `.barrier` flags in CloudKitModel
- RxSwift `DisposeBag` in every subscriber; observable streams never leak

## Project-Specific Rules
- **Storage**: All persistence goes through `StorageProtocol`. Never write directly to SwiftData/CloudKit from the ViewModel or View.
- **App Group**: SwiftData SQLite lives in `group.QuickToDoSharingDefaults` container — this is shared with the Widget. Never move or rename this container.
- **CloudKit**: iCloud container is `iCloud.Persukibo.QuickToDo`. Zone names `QuickToDoZone` and `SharedZone` are hardcoded and must not change.
- **Reactive bridge**: RxSwift Observables are used in the Model layer; ViewModel converts them to `@Published` for SwiftUI. Do not use RxSwift directly in Views.
- **Conflict resolution**: In `QuickToDoModel`, CloudKit wins if its `lastUsedAt` is newer. Preserve this logic when modifying merge code.
- **Widget data**: The Widget reads from the same App Group container. SwiftData changes from the main app are immediately visible to the widget.
- **Intents**: Siri Shortcuts use `QuickToDoIntent` / `ItemCompleted` in the Intents extension. Keep intent parameter types compatible with the shared `Item` struct.

## Important Notes
- `Config.plist` controls the `sharingEnabled` flag — check it when debugging sharing features
- `QuickToDoViewModelProtoocol` has a typo ("Protoocol" with double 'o') — do not fix without updating all references
- `ItemMO` and `QuickToDo.xcdatamodeld` are legacy CoreData artifacts kept for historical reference; SwiftData (`ItemSD`) is the active persistence layer
- Background modes enabled: `fetch` and `remote-notification` — remote push drives CloudKit sync
- The app supports `CKSharingSupported` (Info.plist) for CloudKit share sheet presentation
- `CloudKitModel` is ~1,066 lines and handles all iCloud concerns; be careful when modifying threading or change-token logic
- Bundle ID: `Persukibo.QuickToDo`, Version: 3.2.2

## Common Mistakes to Avoid
- DON'T: Bypass `StorageProtocol` and call SwiftData or CloudKit APIs directly from ViewModel/View
- DON'T: Use `@unchecked Sendable` on new types without implementing proper thread safety via dispatch queue barriers
- DON'T: Modify `synchronizationQueue` reads/writes in `CloudKitModel` without barrier flags — race conditions will corrupt shared state
- DON'T: Mix `throws` into the existing result-tuple pattern — use `(Bool, Error?)` returns for consistency
- DON'T: Change the App Group identifier or SwiftData store URL without updating the Widget target too
- ALWAYS: Dispose RxSwift subscriptions in a `DisposeBag` to avoid memory leaks
- ALWAYS: Update both SwiftData and CloudKit when implementing new item fields (keep `ItemSD`, `Item` struct, and CloudKit record fields in sync)
- ALWAYS: Run on a real device (not simulator) to test CloudKit and sharing features — CloudKit requires a signed-in iCloud account
- ALWAYS: Respect the Input/Output protocol split when extending the model or viewmodel
