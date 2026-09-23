#!/bin/bash
# Uploads every source map in dist/assets to the ParallelSandbox log server so that
# logs_errors can resolve minified stacks for this release.
#
#   PSBX_API_KEY=psbx_... PSBX_LOG_PROJECT=<project id> ./scripts/upload-sourcemaps.sh
#
# Run it right after `npm run build` (or after `docker compose build`, see README) so the
# release id in dist/release.txt matches the one baked into the page.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${PSBX_API_KEY:?PSBX_API_KEY is required}"
: "${PSBX_LOG_PROJECT:?PSBX_LOG_PROJECT is required}"
ENDPOINT="${PSBX_LOG_ENDPOINT:-https://log.parallelsandbox.com}"
RELEASE=$(cat dist/release.txt)
# One file part per map, named after the path it is served at (assets/app-xxx.js.map); one request for the whole dist.
args=()
for map in dist/assets/*.map; do
  path="assets/$(basename "$map")"
  echo "upload $map as $path (release $RELEASE)"
  args+=(-F "$path=@$map;type=application/json")
done
curl -fsS -X POST "$ENDPOINT/v1/projects/$PSBX_LOG_PROJECT/sourcemaps" \
  -H "Authorization: Bearer $PSBX_API_KEY" \
  -F "release=$RELEASE" \
  "${args[@]}"
echo
