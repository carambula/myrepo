# Fix: Bootstrap Database in Xcode Bundle

## The Issue
Xcode won't let you manually add `bootstrap_database.store` because your project uses **File System Synchronization** (`PBXFileSystemSynchronizedRootGroup`), which automatically includes all files in the `WatchedIt/` directory.

## The Good News
The file is **already in the right place** (`WatchedIt/bootstrap_database.store`) and **should be automatically included** in the bundle.

## Verify It's Working

### Option 1: Build and Check
1. **Build the app:** `Product > Build` (Cmd+B)
2. **Find your app bundle:**
   - Right-click the app target in Xcode
   - Select "Show in Finder"
   - Or navigate to: `~/Library/Developer/Xcode/DerivedData/WatchedIt-*/Build/Products/Debug-iphonesimulator/WatchedIt.app`
3. **Check contents:**
   - Right-click `WatchedIt.app` > "Show Package Contents"
   - Look for `bootstrap_database.store`

### Option 2: Run the App and Check Logs
When the app launches, check the console logs. You should see:
- `✅ Copied pre-populated bootstrap database` (if first launch)
- Or: `⏱️ [PERF] Bootstrap check skipped` (if database exists)

## If It's NOT in the Bundle

If after building, the file isn't in the bundle, we can force it to be included. Here's how:

### Solution: Add Explicit File Reference

Since Xcode won't let you add it via the UI, you can verify it's being included by:

1. **Check if file exists in project:**
   - The file is at: `WatchedIt/bootstrap_database.store`
   - File system sync should include it automatically

2. **If needed, we can add a build phase:**
   - But this shouldn't be necessary with file system sync

3. **Alternative: Create a symbolic link or script:**
   - But again, file system sync should handle it

## Most Likely Solution

The file **IS already included** automatically. To verify:

1. Build the app
2. Check the bundle contents
3. If it's missing, let me know and we'll add an explicit Copy Files build phase

## Current File Status

✅ File exists: `WatchedIt/bootstrap_database.store`
✅ Size: 6.3MB  
✅ Date: Nov 29 11:16 (latest version with all fixes)
✅ Project uses file system sync (auto-includes all files)

The file should be in the bundle when you build!

