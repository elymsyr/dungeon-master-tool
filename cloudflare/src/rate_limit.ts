// ============================================================================
// Rate limit — Workers KV üzerinde saatlik bucket counter
// ============================================================================
// Key formatı: rl:{type}:{userId}:{hourBucket}
// TTL: 1 saat (otomatik temizlenir).
//
// Free tier uyarısı (ONLINE_REPORT §10.2): KV free plan 1k write/gün. Saatlik
// bucket nedeniyle ortalama bir kullanıcı saatte 1 increment yapar, çoğu
// read olur; yine de >1k aktif kullanıcıda Workers Paid plana geçilmelidir.
// ============================================================================

export type RateLimitType = 'dl' | 'ul';

export interface RateLimitResult {
  allowed: boolean;
  count: number;
  limit: number;
  resetInSeconds: number;
}

export async function checkRateLimit(
  kv: KVNamespace,
  userId: string,
  type: RateLimitType,
  limit: number,
): Promise<RateLimitResult> {
  const now = Date.now();
  const bucket = Math.floor(now / 3_600_000);
  const key = `rl:${type}:${userId}:${bucket}`;
  const nextBucketAt = (bucket + 1) * 3_600_000;
  const resetInSeconds = Math.max(1, Math.ceil((nextBucketAt - now) / 1000));

  const current = await kv.get(key);
  const count = current ? parseInt(current, 10) : 0;

  if (count >= limit) {
    return { allowed: false, count, limit, resetInSeconds };
  }

  await kv.put(key, String(count + 1), { expirationTtl: 3600 });
  return { allowed: true, count: count + 1, limit, resetInSeconds };
}
