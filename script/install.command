#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/local-config.env"
APP_NAME="CodeQuotaDialXcode"
INSTALL_BASE="/Applications"

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

INSTALL_APP="$INSTALL_BASE/$APP_NAME.app"

if [[ -d "$INSTALL_APP" ]]; then
  echo "==> Existing install found: $INSTALL_APP"
  echo "==> Rebuilding and overwriting app, tools, and launch agents"
else
  echo "==> No existing install found at $INSTALL_APP"
  echo "==> Building and installing fresh app, tools, and launch agents"
fi

exec "$SCRIPT_DIR/rebuild-local.command"
