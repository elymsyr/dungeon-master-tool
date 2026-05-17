#!/usr/bin/env bash
# Empty the campaign-backups bucket via Storage API. Service role key needed
# (project settings → API → service_role secret). The SQL trigger blocks
# direct DELETE on storage.objects so the REST API is the only path.
#
# Usage:
#   export SUPABASE_URL='https://YOUR-PROJECT.supabase.co'
#   export SUPABASE_SERVICE_ROLE_KEY='eyJ...'
#   ./wipe_storage.sh                       # all users
#   ./wipe_storage.sh <USER_UUID>           # single user prefix
#
# Notes
#   - Supabase storage list returns BOTH files and folders. Folders have
#     `id: null`; files have a non-null `id`. We branch on that, recursing
#     into folders and DELETEing files.
#   - Both `apikey` and `Authorization` headers are required. Missing `apikey`
#     causes the API to return an error JSON that `jq .[].name` can't index
#     ("Cannot index string with string \"name\"").
set -euo pipefail

: "${SUPABASE_URL:?SUPABASE_URL not set}"
: "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY not set}"

BUCKET='campaign-backups'
PREFIX="${1:-}"
PAGE_SIZE=1000

api() {
  local method="$1" url="$2" data="${3:-}"
  local args=(
    -sS -X "$method" "$url"
    -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}"
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}"
  )
  if [ -n "$data" ]; then
    args+=(-H 'Content-Type: application/json' -d "$data")
  fi
  curl "${args[@]}"
}

list_page() {
  local prefix="$1" offset="$2"
  api POST "${SUPABASE_URL}/storage/v1/object/list/${BUCKET}" \
    "{\"prefix\":\"${prefix}\",\"limit\":${PAGE_SIZE},\"offset\":${offset}}"
}

delete_file() {
  local path="$1"
  echo "DELETE ${path}"
  local resp
  resp=$(api DELETE "${SUPABASE_URL}/storage/v1/object/${BUCKET}/${path}")
  if echo "$resp" | jq -e '.error // .message' >/dev/null 2>&1; then
    echo "  ! ${resp}" >&2
  fi
}

walk() {
  local prefix="$1"
  local offset=0
  while :; do
    local raw items
    raw=$(list_page "$prefix" "$offset")
    if ! echo "$raw" | jq -e 'type == "array"' >/dev/null 2>&1; then
      echo "list error at prefix='${prefix}' offset=${offset}: ${raw}" >&2
      return 1
    fi
    items=$(echo "$raw" | jq -c '.[]')
    [ -z "$items" ] && break
    local count=0
    while IFS= read -r row; do
      count=$((count + 1))
      local name id
      name=$(echo "$row" | jq -r '.name')
      id=$(echo "$row" | jq -r '.id')
      local path="${prefix:+${prefix}/}${name}"
      if [ "$id" = "null" ]; then
        walk "$path"
      else
        delete_file "$path"
      fi
    done <<<"$items"
    [ "$count" -lt "$PAGE_SIZE" ] && break
    offset=$((offset + PAGE_SIZE))
  done
}

walk "$PREFIX"
echo "done"
