#!/usr/bin/env bash
# Mirror the official-package / template / built-in banners to Cloudflare R2 via
# the worker's admin-gated catalog PUT route.
#
#   GET  {worker}/catalog/banners/<file>  → public (served by the worker)
#   PUT  {worker}/catalog/banners/<file>  → Bearer ADMIN_TOKEN (this script)
#
# Usage:
#   DMT_WORKER_URL=https://<your-worker>.workers.dev \
#   ADMIN_TOKEN=<wrangler secret ADMIN_TOKEN> \
#   ./cloudflare/upload_banners.sh
#
# The in-app cards use the BUNDLED copies (assets/first_party/banners/); this
# R2 mirror is for the web app / external use.
set -euo pipefail

: "${DMT_WORKER_URL:?set DMT_WORKER_URL (e.g. https://worker.example.workers.dev)}"
: "${ADMIN_TOKEN:?set ADMIN_TOKEN (the wrangler ADMIN_TOKEN secret)}"

DIR="$(cd "$(dirname "$0")/../flutter_app/assets/first_party/banners" && pwd)"
count=0
for f in "$DIR"/*.png; do
  name="$(basename "$f")"
  printf 'PUT catalog/banners/%s ... ' "$name"
  curl -fsS -X PUT \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: image/png" \
    --data-binary "@${f}" \
    "${DMT_WORKER_URL%/}/catalog/banners/${name}" >/dev/null
  echo "ok"
  count=$((count + 1))
done
echo "uploaded ${count} banners to ${DMT_WORKER_URL%/}/catalog/banners/"
