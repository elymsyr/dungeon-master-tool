#!/usr/bin/env bash
# `tool/art_gen/out/` içindeki kart görsellerini worker'ın admin-gated catalog
# PUT route'u üzerinden Cloudflare R2'ye yükler.
#
#   GET  {worker}/catalog/art/<uuid>.webp  → public (hesap/JWT yok, edge'de
#                                            immutable cache'li)
#   PUT  {worker}/catalog/art/<uuid>.webp  → Bearer ADMIN_TOKEN (bu script)
#
# Usage:
#   DMT_WORKER_URL=https://<your-worker>.workers.dev \
#   ADMIN_TOKEN=<wrangler secret ADMIN_TOKEN> \
#   ./cloudflare/upload_art.sh [--force] [--jobs N]
#
# Built-in SRD'nin 1247 görseli app bundle'ında da var (assets/art/srd/, q50);
# yine de hepsi buraya yüklenir — bundle sadece bir optimizasyon, ref hangi
# görselin nerede olduğunu taşımıyor (bkz. FirstPartyArtService).
#
# Resume edilebilir: R2'de zaten olan obje atlanır (--force ile yeniden yazılır).
set -euo pipefail

: "${DMT_WORKER_URL:?set DMT_WORKER_URL (e.g. https://worker.example.workers.dev)}"
: "${ADMIN_TOKEN:?set ADMIN_TOKEN (the wrangler ADMIN_TOKEN secret)}"

FORCE=0
PAR=8
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1 ;;
    --jobs) PAR="$2"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

DIR="$(cd "$(dirname "$0")/../tool/art_gen/out" && pwd)"
BASE="${DMT_WORKER_URL%/}"
export BASE ADMIN_TOKEN FORCE

upload_one() {
  local f="$1" name url code
  name="$(basename "$f")"
  url="${BASE}/catalog/art/${name}"
  if [ "$FORCE" = "0" ]; then
    # Public GET; 200 → zaten yüklü. Kota dostu: catalog GET rate limit'i
    # saatte 600/IP, o yüzden -w ile sadece kodu al, gövdeyi indirme.
    code="$(curl -s -o /dev/null -w '%{http_code}' -r 0-0 "$url" || true)"
    case "$code" in 200|206) echo "skip $name"; return 0 ;; esac
  fi
  if curl -fsS -X PUT \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: image/webp" \
      --data-binary "@${f}" "$url" >/dev/null; then
    echo "ok   $name"
  else
    echo "FAIL $name" >&2
    return 1
  fi
}
export -f upload_one

find "$DIR" -name '*.webp' -print0 \
  | xargs -0 -P "$PAR" -I{} bash -c 'upload_one "$@"' _ {} \
  | { ok=0; skip=0; while read -r st _; do
        case "$st" in ok) ok=$((ok+1)) ;; skip) skip=$((skip+1)) ;; esac
      done
      echo "uploaded ${ok}, skipped ${skip} → ${BASE}/catalog/art/"; }
