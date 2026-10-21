# Sharing rework — status and hand-off

Temporary note for continuing the list-sharing work on another machine. Delete it once the work is finished.

## Done (branch `30-share-list-with-another-icloud-contact`)

| Commit | Change |
|---|---|
| `f61ab42` | The whole `QuickToDoZone` is shared with one `CKShare(recordZoneID:)`. No root/parent records anymore. Old root-record shares are deleted before the zone share is created. |
| `ab856e1` | `Item.scope` (`.private`/`.shared`) and `Item.cloudRecord` (also in `ItemSD`). Updates go to the private or shared database by record ID. Shared items stay out of the private list and SwiftData. |
| `7310141` | Share invitations are accepted in `SceneDelegate` (SwiftUI lifecycle), including cold launch, via `CloudKitShareManager.shared`. Fixed-ID database subscriptions on both databases; pushes routed by database scope. |
| `3e27d52` | `syncChanges(isShared:)`: per-zone change tokens, removed shared zones reload the Shared tab. Pushes report completion only after the sync (`RemoteSyncCompletion`). |
| `8b21218` | `MainView` owns all sharing state (one sheet, one error alert). `fetchAllSharedItems` returns all items in one callback. Removed root-record APIs, `CloudSharingView 2.swift`, `Config.plist`. |

Everything compiles (app and tests). **Nothing has been run yet**: unit tests could not run (simulator software out of date), and sharing needs real devices.

## Zone migration (uncommitted)

The existing `QuickToDoZone` reports capabilities `7` (no `.zoneWideSharing`), so the server rejects the zone share with "share type inconsistent with zone capabilities". Zone capabilities cannot change, so the list moves to `QuickToDoListZone`:

- `CloudKitZoneMigrator` creates the zone, checks `.zoneWideSharing`, and copies items that the new zone does not have yet (same record names, item fields only). It runs on launch and before sharing. The legacy zone is never modified, except that Share still deletes its old Root record shares.
- Until a device has migrated (`UserDefaults` flag `zoneMigrationCompleted-QuickToDoListZone`), it keeps reading and writing the legacy zone.
- Copied records get new server timestamps, so `lastUsedAt` of every item becomes the migration time.
- Devices still running an older build keep writing `QuickToDoZone`; those edits do not reach migrated devices.
- The legacy zone held stale state (all 104 items `Used = 0` while the device showed them), so the copy alone shared an empty list. `publishLocalItems` then writes the SwiftData items into `QuickToDoListZone` once per device (flag `localItemsPublished-QuickToDoListZone`), overriding "newer wins" for that one step. It runs on `getItems()` and before sharing.

## Test checklist (two real devices, different iCloud accounts)

1. Device A: Share, invite B's account. Items that existed before sharing should be included.
2. Device B, app closed: tap the invite. The app opens, shows "Shared list added", items appear in the Shared Items tab.
3. Device B: mark done, rename, delete and add an item. All four changes appear on device A.
4. Shared items never appear in device B's own Items tab.
5. Edit on A while B is in the background. B gets one push and updates.
6. Device A: Manage Share → Stop Sharing. Banner disappears on A, the list disappears from B's Shared tab.

After upgrading an existing installation, the first share deletes the old share, so earlier participants need a new invite.

## Open items (decide after testing)

- Joining several shared lists: adding items is refused (error code -8) until the UI can pick a list.
- Shared items are not stored on the device: no offline use, not shown in the widget.
- Token sync emits private changes to the UI only; the Items tab still runs a full `getItems()` on each push to update SwiftData.
- Records deleted by another client in the private zone are only logged, not removed locally (the app itself never deletes records).
- Two syncs can overlap on back-to-back pushes (harmless, duplicate work).
- Stale files: `QuickToDo/Model/CLOUDKIT_SHARING_FIX.md`, `QuickToDo/Model/CONFIGURATION_CHECKLIST.md` (describe the old root-record approach), `Breakpoints_v2.xcbkptlist` (personal Xcode breakpoints).

## Building from the command line

The scheme enables Thread Sanitizer, which breaks device builds. This compiles the app and tests without a simulator:

```bash
xcodebuild -project QuickToDo.xcodeproj -scheme QuickToDo \
  -destination 'generic/platform=iOS' \
  -enableThreadSanitizer NO ENABLE_THREAD_SANITIZER=NO CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```
