// ============================================================================
// Rate limit — Workers KV üzerinde saatlik bucket counter
// ============================================================================
// Key formatı: rl:{type}:{userId}:{hourBucket}
// TTL: 1 saat (otomatik temizlenir).
//
// Free tier uyarısı (ONLINE_REPORT §10.2): KV free plan 1k write/gün ve BU
// SAYAÇ HER İSTEKTE YAZAR — saatte bir değil. Yani günlük ~1000 istekten
// sonra put() patlar; o durumda limiter fail-open geçer (aşağıdaki catch).
// Kalıcı çözüm: Workers Paid, ya da CATALOG_RL gibi platform rate limiter
// binding'ine geçmek (unmetered, KV write harcamaz).
// ============================================================================

export type RateLimitType = 'dl' | 'ul' | 'cat';

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

  try {
    await kv.put(key, String(count + 1), { expirationTtl: 3600 });
  } catch (err) {
    // KV günlük write kotası dolduysa put() fırlatır. Sayaç tutulamayınca
    // isteği reddetmek yerine geçir: burası bir abuse freni, güvenlik sınırı
    // değil — kapalı kalırsa tüm upload/download 500 döner.
    console.warn('rate_limit_kv_write_failed', type, err);
  }
  return { allowed: true, count: count + 1, limit, resetInSeconds };
}
