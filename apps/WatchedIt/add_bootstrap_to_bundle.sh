#!/bin/bash

# Script to ensure bootstrap_database.store is included in Xcode bundle
# Since the project uses file system synchronization, this file should be auto-included
# But we can verify and create a .xcode_build_resources file if needed

echo "Checking if bootstrap_database.store is in WatchedIt directory..."
if [ ! -f "WatchedIt/bootstrap_database.store" ]; then
    echo "❌ Error: bootstrap_database.store not found!"
    exit 1
fi

echo "✅ bootstrap_database.store found"

echo ""
echo "Since your project uses PBXFileSystemSynchronizedRootGroup,"
echo "all files in WatchedIt/ should be automatically included."
echo ""
echo "However, to ensure it's bundled, you can:"
echo ""
echo "1. In Xcode, select bootstrap_database.store in the file navigator"
echo "2. Open File Inspector (right panel, or View > Inspectors > File)"
echo "3. Under 'Target Membership', ensure 'WatchedIt' is checked"
echo ""
echo "Or verify it's being bundled by checking the build:"
echo "  Product > Build (Cmd+B)"
echo ""
echo "Then check the app bundle contents:"
echo "  Show Package Contents on the .app"
echo "  Look for bootstrap_database.store"
