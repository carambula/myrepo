# Batman Theme Not Appearing - Rebuild Instructions

## The Problem
Your Xcode build cache is likely stale and didn't pick up the new Batman theme changes.

## Solution: Clean Build and Rebuild

### Option 1: Clean Build in Xcode (Recommended)
1. In Xcode, go to **Product → Clean Build Folder** (or press `Shift + Cmd + K`)
2. After cleaning completes, rebuild: **Product → Build** (or press `Cmd + B`)
3. Run the app: **Product → Run** (or press `Cmd + R`)
4. Navigate to Account → Themes
5. The "I'm Batman" theme should now appear in the list

### Option 2: Delete Derived Data
If Option 1 doesn't work, try deleting derived data:

1. Quit Xcode completely
2. Open Finder and press `Cmd + Shift + G`
3. Enter: `~/Library/Developer/Xcode/DerivedData`
4. Find the folder starting with "WatchedIt-" and delete it
5. Reopen Xcode
6. Clean and rebuild (Product → Clean Build Folder, then Product → Build)
7. Run the app

### Option 3: Command Line Clean
```bash
cd /path/to/WatchedIt
rm -rf ~/Library/Developer/Xcode/DerivedData/WatchedIt-*
xcodebuild clean -project WatchedIt.xcodeproj -scheme WatchedIt
```

## Verify the Code Changes
You can verify the theme is in your code by checking:

**ThemeManager.swift** - Line 73-81 should have:
```swift
public struct BatmanTheme: Theme {
    public let name = "I'm Batman"
    public let accent = SwiftUI.Color(red: 1.0, green: 0.85, blue: 0.0) // Batman yellow
    public let secondaryAccent: SwiftUI.Color? = nil
    public let headlineFont = Font.system(size: 22, weight: .bold, design: .default).width(.condensed)
    public let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    public let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.05, green: 0.08, blue: 0.15) // Dark navy blue
    public let headlineColor = SwiftUI.Color(red: 1.0, green: 0.85, blue: 0.0) // Batman yellow
}
```

**ThemeManager.swift** - Line 94-100 should have:
```swift
private let themes: [Theme] = [
    WatchedItTheme(),
    MatrixTheme(),
    McQueenTheme(),
    SepiaTheme(),
    BatmanTheme()  // ← Should be here!
]
```

## What You Should See After Rebuild

1. **In Themes List**: 
   - "I'm Batman" theme appears at the bottom of the list
   - Preview shows a yellow circle (accent color)
   - Preview shows condensed "Aa" text

2. **When Applied**:
   - All accent colors turn bright yellow
   - Headlines use condensed bold font
   - Background has subtle dark navy tint
   - Movie titles appear in yellow with condensed font

## Still Not Working?

If after cleaning and rebuilding you still don't see the theme:

1. Make sure you're on the correct git branch:
   ```bash
   git branch
   # Should show: * cursor/watchedit-batman-theme-c269
   ```

2. Pull the latest changes:
   ```bash
   git pull origin cursor/watchedit-batman-theme-c269
   ```

3. Check if the files have the changes:
   ```bash
   grep "I'm Batman" WatchedIt/ThemeManager.swift
   # Should output the line with "I'm Batman"
   ```

4. Try rebuilding the entire project:
   - Close Xcode
   - Delete DerivedData (see Option 2 above)
   - Delete the `.build` folder in your project
   - Reopen Xcode and build from scratch
