#!/bin/bash
#
# Copy Rotina fonts from Nuform Redux app to min apps
# Usage: ./copy-rotina-fonts.sh <path-to-nuform-redux-app>
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔤 Rotina Font Copy Script for Min Apps"
echo "========================================"
echo ""

# Check if Nuform Redux path is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide the path to Nuform Redux app${NC}"
    echo "Usage: $0 <path-to-nuform-redux-app>"
    echo ""
    echo "Example:"
    echo "  $0 /Users/yourname/Documents/GitHub/nuform-redux"
    exit 1
fi

NUFORM_PATH="$1"

# Verify Nuform Redux path exists
if [ ! -d "$NUFORM_PATH" ]; then
    echo -e "${RED}Error: Directory not found: $NUFORM_PATH${NC}"
    exit 1
fi

# Search for Rotina fonts in Nuform Redux app
echo -e "${YELLOW}Searching for Rotina fonts in Nuform Redux app...${NC}"
FONT_SOURCES=$(find "$NUFORM_PATH" -type f \( -name "Rotina*.woff2" -o -name "Rotina*.woff" \) | head -1 | xargs dirname 2>/dev/null || echo "")

if [ -z "$FONT_SOURCES" ]; then
    echo -e "${RED}Error: Could not find Rotina fonts in $NUFORM_PATH${NC}"
    echo "Please check that the Nuform Redux app contains Rotina font files."
    exit 1
fi

echo -e "${GREEN}Found Rotina fonts in: $FONT_SOURCES${NC}"
echo ""

# Count font files
WOFF2_COUNT=$(find "$FONT_SOURCES" -name "Rotina*.woff2" | wc -l | tr -d ' ')
WOFF_COUNT=$(find "$FONT_SOURCES" -name "Rotina*.woff" | wc -l | tr -d ' ')

echo "Font files found:"
echo "  - WOFF2 files: $WOFF2_COUNT"
echo "  - WOFF files: $WOFF_COUNT"
echo ""

# Verify we have the expected number of files (16 weights × 2 formats = 32 files)
TOTAL_FILES=$((WOFF2_COUNT + WOFF_COUNT))
if [ $TOTAL_FILES -lt 32 ]; then
    echo -e "${YELLOW}Warning: Expected 32 font files (16 WOFF2 + 16 WOFF), found $TOTAL_FILES${NC}"
    echo "Continuing anyway..."
    echo ""
fi

# Get the repository root (assumes script is in scripts/ folder)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Repository root: $REPO_ROOT"
echo ""

# Define target directories
DESIGN_SYSTEM_FONTS="$REPO_ROOT/packages/design-system/src/assets/fonts/rotina"
WATCHEDIT_FONTS="$REPO_ROOT/apps/WatchedIt/WatchedIt/Fonts/Rotina"
PODLINK_FONTS="$REPO_ROOT/apps/PodLink/PodLink/Fonts/Rotina"
YOURTUBE_FONTS="$REPO_ROOT/apps/YourTube/YourTube/Fonts/Rotina"
CYCLISMO_FONTS="$REPO_ROOT/apps/Cyclismo/Cyclismo/Fonts/Rotina"

# Function to copy fonts to a directory
copy_fonts() {
    local target_dir="$1"
    local app_name="$2"
    
    echo -e "${YELLOW}Copying fonts to $app_name...${NC}"
    
    # Create directory if it doesn't exist
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        echo "  Created directory: $target_dir"
    fi
    
    # Copy WOFF2 files
    local copied_woff2=0
    for font in "$FONT_SOURCES"/Rotina*.woff2; do
        if [ -f "$font" ]; then
            cp "$font" "$target_dir/"
            ((copied_woff2++))
        fi
    done
    
    # Copy WOFF files
    local copied_woff=0
    for font in "$FONT_SOURCES"/Rotina*.woff; do
        # Skip .woff2 files that end with .woff (shouldn't happen, but just in case)
        if [[ "$font" != *.woff2 ]] && [ -f "$font" ]; then
            cp "$font" "$target_dir/"
            ((copied_woff++))
        fi
    done
    
    local total_copied=$((copied_woff2 + copied_woff))
    echo -e "${GREEN}  ✓ Copied $total_copied font files ($copied_woff2 WOFF2, $copied_woff WOFF)${NC}"
    echo ""
}

# Copy to design system
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
copy_fonts "$DESIGN_SYSTEM_FONTS" "Design System"

# Copy to each app
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
copy_fonts "$WATCHEDIT_FONTS" "WatchedIt"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
copy_fonts "$PODLINK_FONTS" "PodLink"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
copy_fonts "$YOURTUBE_FONTS" "YourTube"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
copy_fonts "$CYCLISMO_FONTS" "Cyclismo"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✓ Font copy complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Add font files to Xcode projects:"
echo "     - Open each app in Xcode"
echo "     - Drag the Fonts/Rotina folder into the project"
echo "     - Make sure 'Copy items if needed' is checked"
echo "     - Add to the app target"
echo ""
echo "  2. Update Info.plist to include fonts:"
echo "     - Add 'Fonts provided by application' key"
echo "     - List all Rotina font files"
echo ""
echo "  3. For web apps, fonts are ready to use!"
echo ""
echo "See the integration guide for detailed instructions:"
echo "  $REPO_ROOT/packages/design-system/docs/font-override-integration.md"
echo ""
