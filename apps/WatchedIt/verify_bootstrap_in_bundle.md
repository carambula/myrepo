# Verifying Bootstrap Database in Bundle

## Your Project Uses File System Synchronization

Your Xcode project uses `PBXFileSystemSynchronizedRootGroup`, which means **all files in the `WatchedIt/` directory are automatically included** in the build.

## Why Xcode Won't Let You Add It Manually

If Xcode says it can't add the file, it's likely because:
- The file already exists in the directory
- File system sync is already tracking it
- You don't need to manually add it

## Verify It's Being Bundled

1. **Build the app in Xcode:**
   ```
   Product > Build (Cmd+B)
   ```

2. **Check the bundle contents:**
   - Find your app in DerivedData: `~/Library/Developer/Xcode/DerivedData/WatchedIt-*/Build/Products/Debug-iphonesimulator/WatchedIt.app`
   - Or: Right-click the app in Xcode > Show in Finder
   - Right-click the `.app` file > Show Package Contents
   - Look for `bootstrap_database.store`

3. **If it's NOT there**, try:
   - Clean Build Folder: `Product > Clean Build Folder` (Cmd+Shift+K)
   - Delete DerivedData
   - Rebuild

## Alternative: Force Include via Build Phase

If the file still isn't being included, we can add it explicitly to the Resources build phase. But with file system sync, this shouldn't be necessary.

## Quick Check Script

Run this to check if the file exists and its size:
```bash
ls -lh WatchedIt/bootstrap_database.store
```

Current file info:
- Size: 6.3MB
- Modified: Nov 29 11:16
- Location: `WatchedIt/bootstrap_database.store` ✅

The file should automatically be included in the bundle when you build.

