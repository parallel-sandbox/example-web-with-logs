#!/bin/sh
set -eu
: "${PSBX_LOG_PROJECT:?PSBX_LOG_PROJECT is required}"
: "${PSBX_LOG_WRITE_KEY:?PSBX_LOG_WRITE_KEY is required}"
: "${PSBX_LOG_ENDPOINT:?PSBX_LOG_ENDPOINT is required}"
ROOT=/usr/share/nginx/html
RELEASE=$(cat "$ROOT/release.txt")
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
cat > "$ROOT/config.js" <<JS
window.PSBX_LOG = {
  project: "$(esc "$PSBX_LOG_PROJECT")",
  writeKey: "$(esc "$PSBX_LOG_WRITE_KEY")",
  endpoint: "$(esc "$PSBX_LOG_ENDPOINT")",
  release: "$(esc "$RELEASE")"
};
JS
echo "config.js written for project $PSBX_LOG_PROJECT, release $RELEASE"
