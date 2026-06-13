#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/local-config.env"
APP_NAME="CodeQuotaDialXcode"
INSTALL_BASE="/Applications"
RUNTIME_DIR="$PROJECT_ROOT/Runtime"
DERIVED_DATA="$PROJECT_ROOT/.build/DerivedData"
GENERATED_DIR="$PROJECT_ROOT/.build/generated"
APP_PATH="$INSTALL_BASE/$APP_NAME.app"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
CODEX_PLIST="$LAUNCH_AGENTS_DIR/local.codex-quota-dial.refresh.plist"
GLM_PLIST="$LAUNCH_AGENTS_DIR/local.glm-quota-dial.refresh.plist"

CODEX_APP_GROUP=""
GLM_APP_GROUP=""

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

echo "==> Unloading launch agents"
launchctl bootout "gui/$(id -u)" "$CODEX_PLIST" >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)" "$GLM_PLIST" >/dev/null 2>&1 || true

echo "==> Stopping running processes"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
killall WidgetKitExtensionHost >/dev/null 2>&1 || true
killall chronod >/dev/null 2>&1 || true
killall iconservicesagent >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true

echo "==> Removing installed app and local runtime"
pluginkit -r "$APP_PATH/Contents/PlugIns/CodeQuotaDialWidgetExtension.appex" >/dev/null 2>&1 || true
rm -rf "$APP_PATH"
rm -rf "$RUNTIME_DIR"
rm -rf "$DERIVED_DATA"
rm -rf "$GENERATED_DIR"
rm -f "$CODEX_PLIST"
rm -f "$GLM_PLIST"

if [[ -n "${CODEX_APP_GROUP:-}" ]]; then
  echo "==> Removing Codex group container"
  rm -rf "$HOME/Library/Group Containers/$CODEX_APP_GROUP"
fi

if [[ -n "${GLM_APP_GROUP:-}" ]]; then
  echo "==> Removing GLM group container"
  rm -rf "$HOME/Library/Group Containers/$GLM_APP_GROUP"
fi

echo "==> Removing legacy group containers"
rm -rf "$HOME/Library/Group Containers/group.local.codex-token-monitor"
rm -rf "$HOME/Library/Group Containers/group.local.glm-quota-monitor"

echo "==> Clearing widget caches"
rm -rf "$HOME/Library/Caches/com.apple.chrono"

echo
echo "Clean complete."
