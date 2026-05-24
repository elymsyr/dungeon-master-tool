// ============================================================================
// DMT Assets — Cloudflare Worker entry
// ============================================================================
// Endpoint'ler:
//   GET  /assets/{key}  → JWT + RLS + rate limit → R2 stream
//   PUT  /assets/{key}  → JWT + prefix check + MIME allowlist → R2 put
//   OPTIONS             → CORS preflight
//
// Metadata (community_assets tablosu) insert'i Flutter istemcisi yapar;
// Worker DB'ye yazmaz.
// ============================================================================

import { JwtError, verifyJwt } from './jwt';
import { checkRateLimit } from './rate_limit';
import {
  checkAssetAccess,
  checkAssetQuota,
  checkTransientAccess,
  popTransientEvictQueue,
} from './rls';

export interface Env {
  R2_BUCKET: R2Bucket;
  RATE_KV: KVNamespace;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  MAX_UPLOAD_BYTES: string;
  USER_QUOTA_BYTES: string;
  DOWNLOAD_LIMIT_PER_HOUR: string;
  UPLOAD_LIMIT_PER_HOUR: string;
  // wrangler secret put ADMIN_TOKEN — /admin/* + /transient/evict-sweep gate.
  ADMIN_TOKEN?: string;
}

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers':
    'Authorization, Content-Type, X-Content-SHA256, X-Asset-Kind',
  'Access-Control-Max-Age': '86400',
};

// Per-kind upload limitleri — Flutter MediaKind enum'u ile senkron tutulmalı.
// Bilinmeyen/eksik kind MAX_UPLOAD_BYTES ceiling'ine düşer (eski client uyumu).
// Ücretsiz kind'ler (character_portrait/world_cover/package_cover) normalde
// Worker'a hiç gelmez — Supabase Storage'a gider — ama savunma için listede.
const KIND_MAX_BYTES: Record<string, number> = {
  character_portrait: 4 * 1024 * 1024,
  world_cover: 4 * 1024 * 1024,
  package_cover: 4 * 1024 * 1024,
  world_entity_image: 4 * 1024 * 1024,
  package_entity_image: 4 * 1024 * 1024,
  character_extra_image: 4 * 1024 * 1024,
  battle_map: 10 * 1024 * 1024,
  mind_map_image: 4 * 1024 * 1024,
};

const ALLOWED_MIME_PREFIXES = ['image/', 'audio/'];
const ALLOWED_MIME_EXACT = new Set<string>([
  'application/gzip',
  'application/octet-stream',
]);

const ASSET_PATH_REGEX = /^\/assets\/(.+)$/;
const SHA256_HEX_REGEX = /^[0-9a-f]{64}$/i;

// Cloud backup (template/world/package) için son 4MB rezerve.
// Asset (community_assets) upload'ları için effective limit = USER_QUOTA - bu sabit.
const ASSET_QUOTA_RESERVE_BYTES = 4 * 1024 * 1024;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await handleRequest(request, env);
    } catch (err) {
      console.error('unhandled_error', err);
      return jsonResponse(500, { error: 'internal_error' });
    }
  },
};

async function handleRequest(request: Request, env: Env): Promise<Response> {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  const url = new URL(request.url);

  // Admin / maintenance routes — Bearer ADMIN_TOKEN ile gated.
  if (url.pathname === '/transient/evict-sweep') {
    return handleTransientEvictSweep(request, env);
  }
  if (url.pathname === '/admin/purge-all') {
    return handleAdminPurgeAll(request, env);
  }
  if (url.pathname === '/admin/purge-user') {
    return handleAdminPurgeUser(request, env);
  }

  const match = url.pathname.match(ASSET_PATH_REGEX);
  if (!match) {
    return jsonResponse(404, { error: 'route_not_found' });
  }

  const r2Key = decodeURIComponent(match[1]);
  if (r2Key.includes('..') || r2Key.startsWith('/') || r2Key.includes('//')) {
    return jsonResponse(400, { error: 'invalid_key' });
  }

  const authHeader = request.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return jsonResponse(401, { error: 'missing_token' });
  }

  let userId: string;
  try {
    const payload = await verifyJwt(authHeader.slice(7), env.SUPABASE_URL);
    userId = payload.sub;
  } catch (err) {
    const reason = err instanceof JwtError ? err.reason : 'invalid_token';
    return jsonResponse(401, { error: reason });
  }

  switch (request.method) {
    case 'GET':
      return handleDownload(env, userId, r2Key);
    case 'PUT':
      return handleUpload(request, env, userId, r2Key);
    case 'DELETE':
      return handleDelete(env, userId, r2Key);
    default:
      return jsonResponse(405, { error: 'method_not_allowed' });
  }
}

async function handleDownload(
  env: Env,
  userId: string,
  r2Key: string,
): Promise<Response> {
  const rl = await checkRateLimit(
    env.RATE_KV,
    userId,
    'dl',
    parseInt(env.DOWNLOAD_LIMIT_PER_HOUR, 10),
  );
  if (!rl.allowed) {
    return rateLimitedResponse(rl.limit, rl.resetInSeconds);
  }

  let allowed: boolean;
  try {
    if (r2Key.startsWith('transient/')) {
      // transient/{uploaderId}/{sha}.{ext} — community_assets satırı yok;
      // erişim ortak dünya üyeliğiyle belirlenir.
      const uploaderId = r2Key.split('/')[1] ?? '';
      allowed = await checkTransientAccess(
        env.SUPABASE_URL,
        env.SUPABASE_SERVICE_ROLE_KEY,
        userId,
        uploaderId,
      );
    } else {
      allowed = await checkAssetAccess(
        env.SUPABASE_URL,
        env.SUPABASE_SERVICE_ROLE_KEY,
        userId,
        r2Key,
      );
    }
  } catch (err) {
    console.error('rls_check_failed', err);
    return jsonResponse(502, { error: 'access_check_failed' });
  }
  if (!allowed) {
    return jsonResponse(403, { error: 'no_access' });
  }

  const object = await env.R2_BUCKET.get(r2Key);
  if (!object) {
    return jsonResponse(404, { error: 'asset_not_found' });
  }

  const headers = new Headers(CORS_HEADERS);
  object.writeHttpMetadata(headers);
  headers.set('etag', object.httpEtag);
  headers.set('Cache-Control', 'private, max-age=604800');
  const sha = object.customMetadata?.sha256;
  if (sha) headers.set('X-Content-SHA256', sha);

  return new Response(object.body, { status: 200, headers });
}

async function handleUpload(
  request: Request,
  env: Env,
  userId: string,
  r2Key: string,
): Promise<Response> {
  // Transient objeler `transient/{userId}/...` altında; kalıcı objeler
  // `{userId}/...` altında. Her iki halde de prefix JWT sub ile eşleşmeli.
  const isTransient = r2Key.startsWith('transient/');
  const requiredPrefix = isTransient ? `transient/${userId}/` : `${userId}/`;
  if (!r2Key.startsWith(requiredPrefix)) {
    return jsonResponse(403, { error: 'prefix_mismatch' });
  }

  const rl = await checkRateLimit(
    env.RATE_KV,
    userId,
    'ul',
    parseInt(env.UPLOAD_LIMIT_PER_HOUR, 10),
  );
  if (!rl.allowed) {
    return rateLimitedResponse(rl.limit, rl.resetInSeconds);
  }

  // Effective limit = min(global ceiling, per-kind limit). X-Asset-Kind
  // header'ı client tarafından gönderilir; tampered/eski client bilinmeyen
  // kind gönderirse ceiling uygulanır (asla ceiling'in üstüne çıkamaz).
  const ceilingBytes = parseInt(env.MAX_UPLOAD_BYTES, 10);
  const assetKind = request.headers.get('X-Asset-Kind') ?? '';
  const maxBytes = Math.min(
    ceilingBytes,
    KIND_MAX_BYTES[assetKind] ?? ceilingBytes,
  );
  const contentLength = parseInt(
    request.headers.get('Content-Length') ?? '0',
    10,
  );
  if (!contentLength || contentLength > maxBytes) {
    return jsonResponse(413, {
      error: 'too_large',
      max_bytes: maxBytes,
      kind: assetKind,
    });
  }

  // Quota kontrolü YALNIZCA kalıcı (sayılan) upload'lar için. Transient
  // objeler quota'ya sayılmaz — R2 lifecycle rule ile auto-purge edilir.
  if (!isTransient) {
    const quotaLimit = parseInt(env.USER_QUOTA_BYTES, 10);
    // Asset upload'lar son ASSET_QUOTA_RESERVE_BYTES'i kullanamaz; o alan
    // template/world/package backup'lara ayrılır.
    const assetEffectiveLimit = Math.max(
      0,
      quotaLimit - ASSET_QUOTA_RESERVE_BYTES,
    );
    let quotaOk: boolean;
    try {
      quotaOk = await checkAssetQuota(
        env.SUPABASE_URL,
        env.SUPABASE_SERVICE_ROLE_KEY,
        userId,
        contentLength,
        assetEffectiveLimit,
      );
    } catch (err) {
      console.error('quota_check_failed', err);
      return jsonResponse(502, { error: 'quota_check_failed' });
    }
    if (!quotaOk) {
      return jsonResponse(413, {
        error: 'quota_exceeded',
        limit_bytes: assetEffectiveLimit,
        reserved_for_backups_bytes: ASSET_QUOTA_RESERVE_BYTES,
      });
    }
  }

  const contentType = (request.headers.get('Content-Type') ?? '').toLowerCase();
  if (!isMimeAllowed(contentType)) {
    return jsonResponse(415, {
      error: 'unsupported_media_type',
      content_type: contentType,
    });
  }

  const sha256 = request.headers.get('X-Content-SHA256');
  if (!sha256 || !SHA256_HEX_REGEX.test(sha256)) {
    return jsonResponse(400, { error: 'missing_or_invalid_sha256' });
  }

  if (!request.body) {
    return jsonResponse(400, { error: 'empty_body' });
  }

  await env.R2_BUCKET.put(r2Key, request.body, {
    httpMetadata: { contentType },
    customMetadata: {
      uploader: userId,
      sha256: sha256.toLowerCase(),
      ...(isTransient ? { transient: 'true' } : {}),
    },
  });

  return jsonResponse(200, {
    ok: true,
    key: r2Key,
    sha256: sha256.toLowerCase(),
    size: contentLength,
  });
}

async function handleDelete(
  env: Env,
  userId: string,
  r2Key: string,
): Promise<Response> {
  const requiredPrefix = r2Key.startsWith('transient/')
    ? `transient/${userId}/`
    : `${userId}/`;
  if (!r2Key.startsWith(requiredPrefix)) {
    return jsonResponse(403, { error: 'prefix_mismatch' });
  }
  await env.R2_BUCKET.delete(r2Key);
  return jsonResponse(200, { ok: true, key: r2Key });
}

// ── Admin gate ───────────────────────────────────────────────────────────────
// ADMIN_TOKEN secret yoksa endpoint kapalı. Token Bearer ile gelir.
function checkAdminAuth(request: Request, env: Env): boolean {
  const expected = env.ADMIN_TOKEN;
  if (!expected || expected.length < 16) return false;
  const header = request.headers.get('Authorization') ?? '';
  if (!header.startsWith('Bearer ')) return false;
  return header.slice(7) === expected;
}

// /transient/evict-sweep — transient_evict_queue'dan N satır al, R2'da sil.
// Supabase transient_reserve LRU eviction sırasında satırları kuyruğa atar;
// bu endpoint kuyruğu boşaltır (cron veya manuel tetik).
async function handleTransientEvictSweep(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.method !== 'POST') {
    return jsonResponse(405, { error: 'method_not_allowed' });
  }
  if (!checkAdminAuth(request, env)) {
    return jsonResponse(401, { error: 'admin_auth_required' });
  }
  const limitParam = new URL(request.url).searchParams.get('limit');
  const limit = Math.min(
    Math.max(parseInt(limitParam ?? '50', 10) || 50, 1),
    500,
  );
  let popped: Array<{ sha256: string; ext: string; uploader_id: string }>;
  try {
    popped = await popTransientEvictQueue(
      env.SUPABASE_URL,
      env.SUPABASE_SERVICE_ROLE_KEY,
      limit,
    );
  } catch (err) {
    console.error('evict_pop_failed', err);
    return jsonResponse(502, { error: 'evict_pop_failed' });
  }
  let deleted = 0;
  for (const row of popped) {
    const key = `transient/${row.uploader_id}/${row.sha256}${row.ext}`;
    try {
      await env.R2_BUCKET.delete(key);
      deleted++;
    } catch (err) {
      console.error('evict_r2_delete_failed', key, err);
    }
  }
  return jsonResponse(200, { ok: true, popped: popped.length, deleted });
}

// /admin/purge-all — TÜM R2 objelerini siler (beta fresh reset için).
// Cursor-paginated R2 list + batch delete. DB ile uyumu çağıran kişinin
// sorumluluğunda: migration 064 community_assets/free_media_assets'ı zaten
// boşaltmış olmalı, aksi halde DB'de yetim ref kalır.
async function handleAdminPurgeAll(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.method !== 'POST') {
    return jsonResponse(405, { error: 'method_not_allowed' });
  }
  if (!checkAdminAuth(request, env)) {
    return jsonResponse(401, { error: 'admin_auth_required' });
  }
  // dry=1 → sayım, silme yok (smoke test).
  const dry = new URL(request.url).searchParams.get('dry') === '1';

  let cursor: string | undefined;
  let total = 0;
  let deleted = 0;
  const batchSize = 200; // R2 delete tek tek; bigger list batch ile döner.
  // R2 list 1000 max; her sayfayı silip cursor ile devam et.
  // Süre limiti: Worker default ~30sn. Çok büyük bucket için endpoint
  // birden fazla kez çağrılır (cursor parametresi opsiyonel).
  const startCursor = new URL(request.url).searchParams.get('cursor') ?? undefined;
  cursor = startCursor;
  // Tek invocation içinde 5 sayfa (≈5000 obje) işle, sonra cursor döndür.
  for (let page = 0; page < 5; page++) {
    const listed = await env.R2_BUCKET.list({ cursor, limit: 1000 });
    total += listed.objects.length;
    if (!dry) {
      // Toplu silme yok; sırayla sil. batchSize kadar paralel.
      for (let i = 0; i < listed.objects.length; i += batchSize) {
        const slice = listed.objects.slice(i, i + batchSize);
        await Promise.all(
          slice.map((o) =>
            env.R2_BUCKET.delete(o.key)
              .then(() => {
                deleted++;
              })
              .catch((err) => console.error('purge_delete_failed', o.key, err)),
          ),
        );
      }
    }
    if (!listed.truncated) {
      cursor = undefined;
      break;
    }
    cursor = listed.cursor;
  }
  return jsonResponse(200, {
    ok: true,
    listed: total,
    deleted: dry ? 0 : deleted,
    dry,
    next_cursor: cursor ?? null,
  });
}

// /admin/purge-user — belirli bir kullanıcının TÜM R2 objelerini siler.
// Beta exit / admin revoke akışında çağrılır. `{userId}/...` (permanent) +
// `transient/{userId}/...` (transient) iki prefix ayrı ayrı sweep edilir.
// Pattern: handleAdminPurgeAll cursor + batch delete, prefix-scoped.
// Body: { "user_id": "<uuid>" }. Auth: Bearer ADMIN_TOKEN.
async function handleAdminPurgeUser(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.method !== 'POST') {
    return jsonResponse(405, { error: 'method_not_allowed' });
  }
  if (!checkAdminAuth(request, env)) {
    return jsonResponse(401, { error: 'admin_auth_required' });
  }
  let body: { user_id?: unknown };
  try {
    body = (await request.json()) as { user_id?: unknown };
  } catch (_) {
    return jsonResponse(400, { error: 'invalid_json' });
  }
  const userId = typeof body.user_id === 'string' ? body.user_id.trim() : '';
  // UUID rough validation — path traversal & accidental wildcard guard.
  if (!/^[0-9a-fA-F-]{20,64}$/.test(userId)) {
    return jsonResponse(400, { error: 'invalid_user_id' });
  }
  const dry = new URL(request.url).searchParams.get('dry') === '1';

  const prefixes = [`${userId}/`, `transient/${userId}/`];
  let totalListed = 0;
  let totalDeleted = 0;
  const batchSize = 200;

  for (const prefix of prefixes) {
    let cursor: string | undefined;
    // Aynı invocation içinde sayfalama — büyük kullanıcılar için worker
    // 30sn limiti. Tek user için tipik <100 obje, ama yine de cursor
    // pattern korunur — admin endpoint'i ihtiyaç olursa retry edebilir.
    do {
      const listed = await env.R2_BUCKET.list({
        prefix,
        cursor,
        limit: 1000,
      });
      totalListed += listed.objects.length;
      if (!dry && listed.objects.length > 0) {
        for (let i = 0; i < listed.objects.length; i += batchSize) {
          const slice = listed.objects.slice(i, i + batchSize);
          await Promise.all(
            slice.map((o) =>
              env.R2_BUCKET.delete(o.key)
                .then(() => {
                  totalDeleted++;
                })
                .catch((err) =>
                  console.error('purge_user_delete_failed', o.key, err),
                ),
            ),
          );
        }
      }
      cursor = listed.truncated ? listed.cursor : undefined;
    } while (cursor);
  }

  return jsonResponse(200, {
    ok: true,
    user_id: userId,
    listed: totalListed,
    deleted: dry ? 0 : totalDeleted,
    dry,
  });
}

function isMimeAllowed(mime: string): boolean {
  if (ALLOWED_MIME_EXACT.has(mime)) return true;
  return ALLOWED_MIME_PREFIXES.some((p) => mime.startsWith(p));
}

function rateLimitedResponse(limit: number, resetSeconds: number): Response {
  const headers = new Headers(CORS_HEADERS);
  headers.set('Content-Type', 'application/json');
  headers.set('Retry-After', String(resetSeconds));
  headers.set('X-RateLimit-Limit', String(limit));
  return new Response(
    JSON.stringify({
      error: 'rate_limited',
      limit,
      retry_after: resetSeconds,
    }),
    { status: 429, headers },
  );
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json',
    },
  });
}
