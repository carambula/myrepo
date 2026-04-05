#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

echo "📦 Enriching bootstrap_data.json with TMDB metadata..."
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
MACOS_SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
MACOS_SWIFT_BIN="$(xcrun --sdk macosx --find swift)"
MACOS_PLUGIN_SERVER="$(xcrun --sdk macosx --find swift-plugin-server)"
MACOS_PLUGIN_DIR="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"
MACOS_SWIFT_ENV=(
  env -i
  HOME="$HOME"
  USER="$USER"
  LANG="${LANG:-en_US.UTF-8}"
  LC_ALL="${LC_ALL:-en_US.UTF-8}"
  DEVELOPER_DIR="$DEVELOPER_DIR"
  SDKROOT="$MACOS_SDKROOT"
  SWIFT_EXEC="$MACOS_SWIFT_BIN"
  SWIFT_PLUGIN_SERVER_PATH="$MACOS_PLUGIN_SERVER"
  TOOLCHAINS="com.apple.dt.toolchain.XcodeDefault"
  PATH="$DEVELOPER_DIR/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin"
)
"${MACOS_SWIFT_ENV[@]}" "$MACOS_SWIFT_BIN" -Xfrontend -plugin-path -Xfrontend "$MACOS_PLUGIN_DIR" enrich_bootstrap_data.swift

echo "🗄️ Generating bootstrap_database.store..."
"${MACOS_SWIFT_ENV[@]}" "$MACOS_SWIFT_BIN" -Xfrontend -plugin-path -Xfrontend "$MACOS_PLUGIN_DIR" generate_bootstrap_database.swift

BOOTSTRAP_STORE_PATH="$ROOT_DIR/WatchedIt/bootstrap_database.store"
echo "🧹 Finalizing bootstrap store (checkpoint + remove sidecars)..."
if command -v sqlite3 >/dev/null 2>&1; then
  sqlite3 "$BOOTSTRAP_STORE_PATH" "PRAGMA wal_checkpoint(FULL);"
fi
echo "🧹 Skipping sidecar cleanup (sandbox may block unlink)"

echo "✅ Bootstrap database ready in WatchedIt/bootstrap_database.store"
