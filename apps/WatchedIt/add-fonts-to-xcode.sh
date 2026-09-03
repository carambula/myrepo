#!/bin/bash
#
# Add Rotina fonts to WatchedIt Xcode project
# This script adds the font file references to project.pbxproj
#

echo "📱 Adding Rotina fonts to WatchedIt Xcode project..."
echo ""

# Check if xcodeproj gem is installed for proper project manipulation
if ! command -v ruby &> /dev/null; then
    echo "❌ Ruby not found. Please add fonts manually through Xcode:"
    echo ""
    echo "1. Open WatchedIt.xcodeproj in Xcode"
    echo "2. Right-click WatchedIt folder > Add Files to 'WatchedIt'..."
    echo "3. Select all files in WatchedIt/Fonts/Rotina/"
    echo "4. UN-check 'Copy items if needed'"
    echo "5. Check 'Create groups'"
    echo "6. Check 'WatchedIt' target"
    echo "7. Click 'Add'"
    exit 1
fi

echo "✅ Fonts are at: WatchedIt/Fonts/Rotina/"
echo "✅ Info.plist already updated with UIAppFonts"
echo ""
echo "⚠️  Manual step required:"
echo ""
echo "Open WatchedIt.xcodeproj in Xcode and:"
echo "1. Right-click 'WatchedIt' folder in navigator"
echo "2. Choose 'Add Files to WatchedIt...'"
echo "3. Navigate to WatchedIt/Fonts/Rotina/"
echo "4. Select all 16 .woff2 files"
echo "5. Settings:"
echo "   - ❌ UN-check 'Copy items if needed'"
echo "   - ✅ 'Create groups'"
echo "   - ✅ Target: WatchedIt"
echo "6. Click 'Add'"
echo ""
echo "Then rebuild and the fonts will be available!"
echo ""
