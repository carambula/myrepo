#!/bin/bash

echo "🦇 Verifying Batman Theme Implementation..."
echo ""

# Check if we're on the right branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "cursor/watchedit-batman-theme-c269" ]; then
    echo "⚠️  WARNING: You're on branch '$CURRENT_BRANCH'"
    echo "   Expected: cursor/watchedit-batman-theme-c269"
    echo ""
fi

# Check ThemeManager.swift for Batman theme struct
if grep -q "public struct BatmanTheme: Theme" WatchedIt/ThemeManager.swift; then
    echo "✅ BatmanTheme struct found in ThemeManager.swift"
else
    echo "❌ BatmanTheme struct NOT FOUND in ThemeManager.swift"
    echo "   Please pull the latest changes!"
    exit 1
fi

# Check if Batman theme is in the themes array
if grep -q "BatmanTheme()" WatchedIt/ThemeManager.swift; then
    echo "✅ BatmanTheme() is in the themes array"
else
    echo "❌ BatmanTheme() NOT in themes array"
    echo "   Please pull the latest changes!"
    exit 1
fi

# Check ThemesView for Batman description
if grep -q "I'm Batman" WatchedIt/ThemesView.swift; then
    echo "✅ Batman theme description found in ThemesView.swift"
else
    echo "❌ Batman theme description NOT FOUND in ThemesView.swift"
    echo "   Please pull the latest changes!"
    exit 1
fi

# Check DesignSystem for Batman font handling
if grep -q "I'm Batman" WatchedIt/DesignSystem.swift; then
    echo "✅ Batman theme typography found in DesignSystem.swift"
else
    echo "❌ Batman theme typography NOT FOUND in DesignSystem.swift"
    echo "   Please pull the latest changes!"
    exit 1
fi

echo ""
echo "🎉 All files contain the Batman theme code!"
echo ""
echo "Next steps:"
echo "1. Open Xcode"
echo "2. Clean Build Folder: Product → Clean Build Folder (Shift+Cmd+K)"
echo "3. Build: Product → Build (Cmd+B)"
echo "4. Run: Product → Run (Cmd+R)"
echo "5. Go to Account → Themes"
echo "6. Look for 'I'm Batman' theme at the bottom of the list"
echo ""
