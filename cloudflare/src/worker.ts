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
import { checkAssetAccess, checkAssetQuota } from './rls';

export interface Env {
  R2_BUCKET: R2Bucket;
  RATE_KV: KVNamespace;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  MAX_UPLOAD_BYTES: string;
  USER_QUOTA_BYTES: string;
  DOWNLOAD_LIMIT_PER_HOUR: string;
  UPLOAD_LIMIT_PER_HOUR: string;
}

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers':
    'Authorization, Content-Type, X-Content-SHA256',
  'Access-Control-Max-Age': '86400',
};

const ALLOWED_MIME_PREFIXES = ['image/', 'audio/'];
const ALLOWED_MIME_EXACT = new Set<string>([
  'application/gzip',
  'application/octet-stream',
]);

const ASSET_PATH_REGEX = /^\/assets\/(.+)$/;
const SHA256_HEX_REGEX = /^[0-9a-f]{64}$/i;

// Cloud backup (template/world/package) için son 2MB rezerve.
// Asset (community_assets) upload'ları için effective limit = USER_QUOTA - bu sabit.
const ASSET_QUOTA_RESERVE_BYTES = 2 * 1024 * 1024;

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
    allowed = await checkAssetAccess(
      env.SUPABASE_URL,
      env.SUPABASE_SERVICE_ROLE_KEY,
      userId,
      r2Key,
    );
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
  if (!r2Key.startsWith(`${userId}/`)) {
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

  const maxBytes = parseInt(env.MAX_UPLOAD_BYTES, 10);
  const contentLength = parseInt(
    request.headers.get('Content-Length') ?? '0',
    10,
  );
  if (!contentLength || contentLength > maxBytes) {
    return jsonResponse(413, { error: 'too_large', max_bytes: maxBytes });
  }

  const quotaLimit = parseInt(env.USER_QUOTA_BYTES, 10);
  // Asset upload'lar son ASSET_QUOTA_RESERVE_BYTES'i kullanamaz; o alan
  // template/world/package backup'lara ayrılır.
  const assetEffectiveLimit = Math.max(0, quotaLimit - ASSET_QUOTA_RESERVE_BYTES);
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
  if (!r2Key.startsWith(`${userId}/`)) {
    return jsonResponse(403, { error: 'prefix_mismatch' });
  }
  await env.R2_BUCKET.delete(r2Key);
  return jsonResponse(200, { ok: true, key: r2Key });
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
