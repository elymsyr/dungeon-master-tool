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
// Combined storage quota check — upload öncesi "mevcut toplam + yeni dosya
// <= limit mi?" sorusu. Supabase check_asset_quota RPC'sini çağırır.
// ============================================================================

export async function checkAssetQuota(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
  newBytes: number,
  limitBytes: number,
): Promise<boolean> {
  const url = `${supabaseUrl.replace(/\/$/, '')}/rest/v1/rpc/check_asset_quota`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
    },
    body: JSON.stringify({
      p_user_id: userId,
      p_new_bytes: newBytes,
      p_limit: limitBytes,
    }),
  });

  if (!res.ok) {
    throw new Error(`quota_rpc_failed_${res.status}`);
  }

  const body = (await res.json()) as boolean | { check_asset_quota?: boolean };
  if (typeof body === 'boolean') return body;
  return body?.check_asset_quota === true;
}
