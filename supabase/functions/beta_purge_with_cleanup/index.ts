// Supabase Edge Function: beta_purge_with_cleanup
// ----------------------------------------------------------------------------
// Tek noktada full kullanıcı verisi temizliği. İki yolu birleştirir:
//   • Self-exit  → caller leave_beta() RPC'sine eşdeğer + Storage + R2 sweep
//   • Admin revoke → admin_revoke_beta() RPC'sine eşdeğer + Storage + R2 sweep
//
// Daha önce admin revoke yalnızca DB satırlarını siliyordu; Supabase Storage
// (campaign-backups, free-media, shared-payloads) ve R2 objeleri (`{userId}/`,
// `transient/{userId}/`) öksüz kalıyordu. Self-exit'te R2 cleanup da yoktu
// (client'ın ADMIN_TOKEN'i yok). Bu fonksiyon her iki akışı tek imza
// altında toplar.
//
// Auth:
//   - Caller'ın JWT'si Authorization header'da bulunmalı.
//   - target_user_id != caller.id ise `is_admin()` true olmalı.
//
// Body: { "user_id": "<uuid>" }
//
// Env:
//   - SUPABASE_URL                       (auto)
//   - SUPABASE_ANON_KEY                  (auto)
//   - SUPABASE_SERVICE_ROLE_KEY          (auto)
//   - R2_WORKER_URL                      (manuel — wrangler URL'i)
//   - R2_ADMIN_TOKEN                     (manuel — wrangler secret ADMIN_TOKEN)
// ----------------------------------------------------------------------------

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import {
  createClient,
  SupabaseClient,
} from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const R2_WORKER_URL = Deno.env.get('R2_WORKER_URL') ?? '';
const R2_ADMIN_TOKEN = Deno.env.get('R2_ADMIN_TOKEN') ?? '';

const STORAGE_BUCKETS = ['campaign-backups', 'free-media', 'shared-payloads'];

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return jsonResponse(405, { error: 'method_not_allowed' });
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.toLowerCase().startsWith('bearer ')) {
    return jsonResponse(401, { error: 'missing_token' });
  }

  // Caller-scoped client (their JWT, RLS enforced).
  const caller: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_ANON_KEY,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: userErr } = await caller.auth.getUser();
  if (userErr || !userData?.user?.id) {
    return jsonResponse(401, { error: 'invalid_token' });
  }
  const callerId = userData.user.id;

  let body: { user_id?: unknown };
  try {
    body = (await req.json()) as { user_id?: unknown };
  } catch (_) {
    return jsonResponse(400, { error: 'invalid_json' });
  }
  const targetUserId =
    typeof body.user_id === 'string' ? body.user_id.trim() : '';
  if (!/^[0-9a-fA-F-]{20,64}$/.test(targetUserId)) {
    return jsonResponse(400, { error: 'invalid_user_id' });
  }

  const isSelf = targetUserId === callerId;
  if (!isSelf) {
    // Admin gate via is_admin() RPC (uses caller's JWT, RLS-safe).
    const { data: isAdminData, error: isAdminErr } = await caller.rpc(
      'is_admin',
    );
    if (isAdminErr || isAdminData !== true) {
      return jsonResponse(403, { error: 'forbidden' });
    }
  }

  // 1) DB cleanup via existing RPCs (audit log + cascade FKs).
  const rpcResults: Record<string, unknown> = {};
  try {
    if (isSelf) {
      const { data, error } = await caller.rpc('leave_beta');
      if (error) throw error;
      rpcResults.rpc = 'leave_beta';
      rpcResults.rpc_result = data;
    } else {
      const { data, error } = await caller.rpc('admin_revoke_beta', {
        p_user: targetUserId,
      });
      if (error) throw error;
      rpcResults.rpc = 'admin_revoke_beta';
      rpcResults.rpc_result = data;
    }
  } catch (e) {
    return jsonResponse(500, {
      error: 'rpc_failed',
      detail: String(e),
    });
  }

  // 2) Supabase Storage cleanup — service-role (target user'ın JWT'sine
  //    sahip olmadığımız için, ve self-exit'te de race-safe olsun diye).
  const adminClient: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
  );
  const storageStats: Record<string, number | string> = {};
  for (const bucket of STORAGE_BUCKETS) {
    try {
      const removed = await wipeUserPrefix(adminClient, bucket, targetUserId);
      storageStats[bucket] = removed;
    } catch (e) {
      storageStats[bucket] = `error: ${String(e)}`;
    }
  }

  // 3) R2 cleanup via Worker /admin/purge-user.
  let r2Result: Record<string, unknown> = { skipped: true };
  if (R2_WORKER_URL && R2_ADMIN_TOKEN) {
    try {
      const resp = await fetch(`${R2_WORKER_URL}/admin/purge-user`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${R2_ADMIN_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ user_id: targetUserId }),
      });
      const text = await resp.text();
      let parsed: unknown = text;
      try {
        parsed = JSON.parse(text);
      } catch (_) {
        // text fallback
      }
      r2Result = { status: resp.status, body: parsed };
    } catch (e) {
      r2Result = { error: String(e) };
    }
  }

  return jsonResponse(200, {
    ok: true,
    user_id: targetUserId,
    self: isSelf,
    ...rpcResults,
    storage: storageStats,
    r2: r2Result,
  });
});

/// Belirli bir bucket'ta `{userId}/` ile başlayan tüm objeleri siler.
/// Storage list 100 max default, sayfalama ile devam.
async function wipeUserPrefix(
  admin: SupabaseClient,
  bucket: string,
  userId: string,
): Promise<number> {
  let deleted = 0;
  // Top-level files at `{userId}/`
  deleted += await wipeFlat(admin, bucket, userId);
  // One-level subdirs: `{userId}/{subdir}/*` — shared-payloads layout uses
  // `{userId}/{worldId}/{sha}.gz` for example. List subdirs first.
  try {
    const { data: subdirs } = await admin.storage
      .from(bucket)
      .list(userId, { limit: 1000 });
    for (const entry of subdirs ?? []) {
      // Folder entries have id === null in Supabase Storage's list output.
      if (entry.id !== null) continue;
      deleted += await wipeFlat(admin, bucket, `${userId}/${entry.name}`);
    }
  } catch (_) {
    // best-effort
  }
  return deleted;
}

async function wipeFlat(
  admin: SupabaseClient,
  bucket: string,
  prefix: string,
): Promise<number> {
  let removed = 0;
  // Paginate via offset; 1000 per page (Supabase Storage limit).
  for (let offset = 0; offset < 100_000; offset += 1000) {
    const { data: entries, error } = await admin.storage
      .from(bucket)
      .list(prefix, { limit: 1000, offset });
    if (error || !entries || entries.length === 0) break;
    const fileEntries = entries.filter((e) => e.id !== null);
    if (fileEntries.length === 0) break;
    const paths = fileEntries.map((e) => `${prefix}/${e.name}`);
    const { error: delErr } = await admin.storage.from(bucket).remove(paths);
    if (delErr) {
      console.error(`storage delete failed (${bucket})`, delErr);
      break;
    }
    removed += paths.length;
    if (entries.length < 1000) break;
  }
  return removed;
}
