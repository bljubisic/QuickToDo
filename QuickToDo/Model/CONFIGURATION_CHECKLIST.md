# CloudKit Sharing Configuration Checklist

## Pre-Flight Checklist

Before testing CloudKit sharing, ensure all of the following are properly configured:

### ✅ 1. Xcode Project Settings

- [ ] Open your project in Xcode
- [ ] Select your target
- [ ] Go to "Signing & Capabilities" tab
- [ ] Ensure "Automatically manage signing" is enabled OR you have valid provisioning profiles
- [ ] Verify your Team is selected

### ✅ 2. CloudKit Capability

- [ ] Click "+ Capability" button
- [ ] Add "iCloud" if not already present
- [ ] Check "CloudKit" checkbox
- [ ] Verify container: `iCloud.Persukibo.QuickToDo` is listed
- [ ] If not present, click "+" and add it
- [ ] Click "CloudKit Dashboard" button to verify container exists

### ✅ 3. CloudKit Schema

In CloudKit Dashboard, verify you have:

**Record Types:**
- [ ] `Items` record type exists
- [ ] `Items` has these fields:
  - `Name` (String)
  - `Count` (Int64)
  - `Done` (Int64)
  - `Used` (Int64)
  - `Id` (String)
  - `Root` (Reference)

**Zones:**
- [ ] Custom zone `QuickToDoZone` exists (created automatically by app)

**Indexes:**
- [ ] QUERYABLE index on `Name`
- [ ] QUERYABLE index on `Used`
- [ ] QUERYABLE index on `Root`

### ✅ 4. App Entitlements

Open `QuickToDo.entitlements` and verify:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.Persukibo.QuickToDo</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
```

### ✅ 5. Info.plist Configuration

Add or verify these keys in Info.plist:

```xml
<key>CKSharingSupported</key>
<true/>

<key>NSUserActivityTypes</key>
<array>
    <string>NSUserActivityTypeBrowsingWeb</string>
</array>
```

### ✅ 6. URL Scheme (for share links)

- [ ] Go to Info tab in Xcode
- [ ] Expand "URL Types"
- [ ] Add new URL Type:
  - **Identifier:** `com.bratislavljubisic.QuickToDo`
  - **URL Schemes:** `quicktodo`
  - **Role:** Editor

### ✅ 7. Testing Devices

**Device Requirements:**
- [ ] Both devices running iOS 15.0+
- [ ] Both devices signed into iCloud with valid Apple ID
- [ ] iCloud Drive enabled on both devices
- [ ] Network connectivity (WiFi or cellular)
- [ ] Different Apple IDs (can't share with yourself effectively)

**Settings to Check:**
1. Settings → [Your Name] → iCloud
2. Verify iCloud Drive is ON
3. Verify app is allowed to use iCloud (scroll down to app list)

### ✅ 8. Development vs Production

- [ ] For testing, deploy to "Development" environment in CloudKit Dashboard
- [ ] Before App Store release, deploy schema to "Production"
- [ ] Update app code if needed to use production container

### ✅ 9. Code Verification

Ensure these files are in your project:
- [ ] `CloudKitModel.swift` (with fixes)
- [ ] `CloudKitShareManager.swift` (with fixes)
- [ ] `CloudSharingView.swift` (newly created)
- [ ] `ItemsView.swift` (with fixes)
- [ ] All protocol updates applied

### ✅ 10. Build & Run

- [ ] Clean build folder (Cmd+Shift+K)
- [ ] Build project (Cmd+B) - verify no errors
- [ ] Run on Device A (sender)
- [ ] Run on Device B (receiver)
- [ ] Check Console for any CloudKit errors

## Common Issues & Solutions

### "User must be signed in to iCloud"
**Solution:** Go to Settings → Sign in to your iPhone → enter Apple ID

### "Container not found"
**Solution:** 
1. Check container identifier matches everywhere
2. Verify in CloudKit Dashboard that container exists
3. Wait 5-10 minutes after creating container (propagation delay)

### "Permission denied"
**Solution:**
1. Delete app from both devices
2. Clean build folder
3. Reinstall with fresh provisioning profile

### "Zone not found"
**Solution:** 
1. Run app at least once to create custom zone
2. Check CloudKit Dashboard → Data → select zone dropdown

### "Share not appearing"
**Solution:**
1. Verify recipient opened the share link
2. Check if share was actually sent (Messages app)
3. Try sending via AirDrop or Email instead
4. Check Console logs on both devices

### "Items not loading in Shared Items tab"
**Solution:**
1. Pull to refresh in Shared Items tab
2. Check Console for "Loaded X shared items"
3. Verify items exist in CloudKit Dashboard
4. Ensure `Used` field is set to 1 (shown=true)

## Testing Procedure

### Step 1: Setup (Device A - Sender)
1. Launch app
2. Add 3-4 test items (e.g., "Buy milk", "Walk dog")
3. Verify items show checkmark or cloud icon
4. Tap Share button in toolbar
5. Choose "Add Person" or similar
6. Send via Messages to Device B's Apple ID

### Step 2: Acceptance (Device B - Receiver)
1. Receive and tap share link in Messages
2. App should open automatically
3. Look for alert: "Share accepted successfully!"
4. Tap "OK"

### Step 3: Verification (Device B - Receiver)
1. Navigate to "Shared Items" tab at bottom
2. Pull down to refresh
3. Items from Device A should appear
4. Verify item names match

### Step 4: Two-way Sync (Optional)
1. On Device B, mark an item as done
2. On Device A, pull to refresh
3. Change should sync (if permissions allow)

## Monitoring & Debugging

### Console Logs to Watch For

**Good Signs:**
```
Successfully accepted share: <CKShare>
Loaded 4 shared items
Record created!! ItemName
```

**Warning Signs:**
```
Failed to accept share: <error>
getSharedItems fetch error: <error>
Zone not found
Permission denied
```

### CloudKit Dashboard Monitoring

1. Open CloudKit Dashboard
2. Go to "Logs" tab
3. Filter by date/time of test
4. Look for API calls:
   - `acceptShareOperation`
   - `queryOperation` on shared database
   - Any errors in red

## Production Readiness

Before releasing to App Store:

- [ ] Test with at least 3 different Apple IDs
- [ ] Test offline handling (airplane mode)
- [ ] Test with large item counts (100+ items)
- [ ] Deploy CloudKit schema to Production
- [ ] Update container to use production environment if needed
- [ ] Add rate limiting for share operations
- [ ] Implement proper error UI (not just console logs)
- [ ] Add privacy policy mentioning CloudKit data storage
- [ ] Test App Review process (they will test iCloud features)

## Support Resources

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [CloudKit Sharing Guide](https://developer.apple.com/documentation/cloudkit/shared_records)
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [Apple Developer Forums](https://developer.apple.com/forums/tags/cloudkit)

## Need Help?

If issues persist:
1. Check all items in this checklist
2. Review Console logs carefully
3. Test on different devices
4. File feedback at https://feedbackassistant.apple.com
5. Check StackOverflow with tag `cloudkit`

---

**Last Updated:** Based on iOS 15+ and current CloudKit APIs
**App Version:** QuickToDo with CloudKit Sharing Support
