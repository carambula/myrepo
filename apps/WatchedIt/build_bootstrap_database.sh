#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

CLOUD_JSON="$ROOT_DIR/WatchedIt/bootstrap_data.cloud.json"
EXPORT_SCRIPT="$ROOT_DIR/../../services/min-cloud/scripts/export-bootstrap.mjs"
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

pull_cloud_bootstrap() {
  if [ "${SKIP_CLOUD_BOOTSTRAP:-0}" = "1" ]; then
    echo "☁️ Skipping Min Cloud bootstrap pull (SKIP_CLOUD_BOOTSTRAP=1)"
    return 0
  fi
  if ! command -v node >/dev/null 2>&1; then
    echo "⚠️ node not found; using the committed bootstrap_data.json"
    return 0
  fi
  if [ ! -f "$EXPORT_SCRIPT" ]; then
    echo "⚠️ export-bootstrap.mjs not found; using the committed bootstrap_data.json"
    return 0
  fi
  echo "☁️ Pulling live catalog from Min Cloud..."
  if MIN_CLOUD_URL="${MIN_CLOUD_URL:-https://min-cloud-production.up.railway.app}" \
    BOOTSTRAP_CLOUD_PATH="$CLOUD_JSON" \
    node "$EXPORT_SCRIPT" "$CLOUD_JSON"; then
    return 0
  fi
  echo "⚠️ Min Cloud pull failed; using the committed bootstrap_data.json"
  return 0
}

pull_cloud_bootstrap

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

if [ "${SKIP_BOOTSTRAP_ENRICH:-0}" = "1" ] || { [ -f "$CLOUD_JSON" ] && [ "${FORCE_BOOTSTRAP_ENRICH:-0}" != "1" ]; }; then
  echo "📦 Skipping TMDB enrich; using Min Cloud metadata from bootstrap_data.cloud.json"
else
  echo "📦 Enriching bootstrap_data.json with TMDB metadata..."
  "${MACOS_SWIFT_ENV[@]}" "$MACOS_SWIFT_BIN" -Xfrontend -plugin-path -Xfrontend "$MACOS_PLUGIN_DIR" enrich_bootstrap_data.swift
fi

echo "🗄️ Generating bootstrap_database.store..."
"${MACOS_SWIFT_ENV[@]}" "$MACOS_SWIFT_BIN" -Xfrontend -plugin-path -Xfrontend "$MACOS_PLUGIN_DIR" generate_bootstrap_database.swift

BOOTSTRAP_STORE_PATH="$ROOT_DIR/WatchedIt/bootstrap_database.store"
echo "🧹 Finalizing bootstrap store (checkpoint + remove sidecars)..."
if command -v sqlite3 >/dev/null 2>&1; then
  sqlite3 "$BOOTSTRAP_STORE_PATH" "PRAGMA wal_checkpoint(FULL);"
fi
echo "🧹 Skipping sidecar cleanup (sandbox may block unlink)"

echo "✅ Bootstrap database ready in WatchedIt/bootstrap_database.store"
