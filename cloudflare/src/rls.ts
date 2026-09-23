// ============================================================================
// Supabase RLS check — Worker, service_role key ile get_asset_access RPC'sini
// çağırır. Fonksiyon SECURITY DEFINER olduğu için RLS bypass edilir; gerçek
// yetkilendirme SQL fonksiyonunun gövdesinde yapılır.
// ============================================================================

export async function checkAssetAccess(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
  r2Key: string,
): Promise<boolean> {
  const url = `${supabaseUrl.replace(/\/$/, '')}/rest/v1/rpc/get_asset_access`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
    },
    body: JSON.stringify({ p_user_id: userId, p_r2_key: r2Key }),
  });

  if (!res.ok) {
    throw new Error(`rls_rpc_failed_${res.status}`);
  }

  const body = (await res.json()) as boolean | { get_asset_access?: boolean };
  if (typeof body === 'boolean') return body;
  return body?.get_asset_access === true;
}

// ============================================================================
// R2 tahliye kuyruğunu boşalt — service_role only. r2_evict_pop FOR UPDATE
// SKIP LOCKED kullanır, iki worker çakışmaz; obje o arada yeniden canlandıysa
// satırı düşürür ama döndürmez (090 / 099).
// ============================================================================

export interface EvictRow {
  id: number;
  r2_key: string;
}

export async function popEvictQueue(
  supabaseUrl: string,
  serviceRoleKey: string,
  limit: number,
): Promise<EvictRow[]> {
  const body = await serviceRpc<EvictRow[] | null>(
    supabaseUrl,
    serviceRoleKey,
    'r2_evict_pop',
    { _limit: limit },
  );
  return Array.isArray(body) ? body : [];
}

// ============================================================================
// Dünya medyası (Faz 5d) — toplu imzanın izin sorgusu. N sha, tek RPC.
// ============================================================================

/// PUT: kullanıcının SAHİBİ olduğu dünyada rezerve edilmiş sha'lar. `bytes`
/// ve `mime` imzaya bağlanır.
export interface WorldMediaPutRow {
  sha256: string;
  ext: string;
  bytes: number;
  mime: string;
}

export async function worldMediaSignPut(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
  worldId: string,
  shas: string[],
): Promise<WorldMediaPutRow[]> {
  const body = await serviceRpc<WorldMediaPutRow[] | null>(
    supabaseUrl,
    serviceRoleKey,
    'world_media_sign_put',
    { p_user: userId, p_world: worldId, p_shas: shas },
  );
  return Array.isArray(body) ? body : [];
}

/// GET: kullanıcının üyesi olduğu herhangi bir dünyada yüklenmiş sha'lar.
export interface WorldMediaGetRow {
  sha256: string;
  world_id: string;
  ext: string;
}

export async function worldMediaSignGet(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
  shas: string[],
): Promise<WorldMediaGetRow[]> {
  const body = await serviceRpc<WorldMediaGetRow[] | null>(
    supabaseUrl,
    serviceRoleKey,
    'world_media_sign_get',
    { p_user: userId, p_shas: shas },
  );
  return Array.isArray(body) ? body : [];
}

async function serviceRpc<T>(
  supabaseUrl: string,
  serviceRoleKey: string,
  fn: string,
  params: unknown,
): Promise<T> {
  const url = `${supabaseUrl.replace(/\/$/, '')}/rest/v1/rpc/${fn}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
    },
    body: JSON.stringify(params),
  });
  if (!res.ok) {
    throw new Error(`${fn}_rpc_failed_${res.status}`);
  }
  return (await res.json()) as T;
}

// ============================================================================
// Pinned (marketplace) upload kapısı — `pub/{sha}.{ext}` key'inde kullanıcı
// prefix'i YOK, dolayısıyla worker prefix eşleşmesiyle yetki veremez. Kapı
// rezervasyondur: client önce `pub_asset_reserve` RPC'sini çağırır (dedup +
// 5 GB pool + 500 MB yayıncı capleri orada), sonra PUT eder. Bu fonksiyon o
// rezervasyonun gerçekten var olduğunu doğrular.
// ============================================================================

export async function checkPubUploadAllowed(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
  sha: string,
): Promise<boolean> {
  const url = `${supabaseUrl.replace(/\/$/, '')}/rest/v1/rpc/get_pub_upload_allowed`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
    },
    body: JSON.stringify({ p_user_id: userId, p_sha: sha }),
  });

  if (!res.ok) {
    throw new Error(`pub_upload_rpc_failed_${res.status}`);
  }

  const body = (await res.json()) as
    | boolean
    | { get_pub_upload_allowed?: boolean };
  if (typeof body === 'boolean') return body;
  return body?.get_pub_upload_allowed === true;
}
