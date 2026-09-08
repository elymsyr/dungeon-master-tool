---
type: file-note
domain: backend
path: cloudflare/src/rate_limit.ts
layer: backend
language: typescript
status: stable
updated: 2026-09-08
tags: [file]
---

# `rate_limit.ts`

> [!abstract] Primary Purpose
> A simple hourly fixed-window rate limiter backed by Workers KV. Each call increments a per-user (or per-IP), per-type counter keyed to the current hour bucket; the counter auto-expires after one hour via KV TTL.

## Inputs / Outputs
**Inputs**
- `checkRateLimit(kv, userId, type, limit)` — KV namespace (`RATE_KV`), identity string (`userId` or `ip:<addr>`), `type` (`'dl' | 'ul' | 'cat'`), and the hourly `limit`.

**Outputs**
- `RateLimitResult { allowed, count, limit, resetInSeconds }`.

## Dependencies & Links
- Depends on: Workers KV (`RATE_KV` binding)
- Used by: [[worker]]
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[wrangler_config]]

## Key Logic / Variables
- Key format: `rl:{type}:{userId}:{hourBucket}` where `hourBucket = floor(Date.now() / 3_600_000)`.
- Reads current count; if `count >= limit` → `allowed:false`. Otherwise `kv.put(count+1, {expirationTtl: 3600})`.
- `resetInSeconds` = seconds until the next hour bucket starts (min 1).
- Types: `dl` (download), `ul` (upload), `cat` (public catalog GET, keyed by `ip:<CF-Connecting-IP>`).

## Notes
- Not atomic (read-then-write); under heavy concurrency the limit can be slightly overshot — acceptable for this abuse-prevention use case.
- KV free plan allows ~1k writes/day. **Her `allowed` çağrı bir write yapar** — saatlik bucket write sayısını düşürmez, sadece key sayısını düşürür. Kota dolunca `kv.put()` fırlatır.
- **Fail-open (2026-09-07):** `put()` hatası yutulur ve istek geçirilir (`console.warn('rate_limit_kv_write_failed', ...)`). Sebep: kota dolduğunda fırlatılan hata `worker.ts`'in dış catch'ine düşüp **her upload/download'ı 500 `internal_error`** yapıyordu — yayın sırasında medya pinlenemiyordu. Limiter bir abuse freni, güvenlik sınırı değil; kapalı kalması kabul edilemez.
- Kalıcı çözüm `dl`/`ul` için de platform rate limiter binding'ine geçmek (catalog'un yaptığı gibi) ya da Workers Paid.
- Limits configured in [[wrangler_config]]: `DOWNLOAD_LIMIT_PER_HOUR`, `UPLOAD_LIMIT_PER_HOUR`.
- **Public catalog GET bu modülü kullanmaz** — `[[ratelimits]] CATALOG_RL` binding'ine taşındı (2026-09-07). Sebep: her çağrı bir KV write ve free tier günde 1000 write veriyor; kart görselleri geldikten sonra tek paket kurulumu bunu tek başına aşıyordu.

## KV free tier'ı bu sayaç dolduruyor (2026-09-08)
`checkRateLimit` **her authed `/assets/` isteğinde** `kv.put` yapıyor — saatte bir değil, istek başına. Free tier 1000 write/gün, yani hesap genelinde ~1000 medya isteğinden sonra kota biter. Sonucu **kesinti değil**: `put()` hatası yutuluyor (fail-open), istek geçer, kaybolan şey limiter'ın kendisi. Multiplayer koordinasyonu zaten Supabase Realtime üzerinden, worker'a hiç uğramıyor.

Kalıcı çözüm dosyanın kendi yorumunda yazılı: `dl`/`ul`'yi `CATALOG_RL` gibi `[[ratelimits]]` platform binding'ine taşımak (unmetered, KV harcamaz), sonra bu modülü ve `RATE_KV` namespace'ini tamamen silmek. Bedeli iki tane: platform limiter'ında `period` **yalnızca 10 veya 60 saniye** olabiliyor (saatlik limitler dakikalığa döner) ve sayaçlar **per-colo**, global değil. İkisi de bir abuse freni için kabul edilebilir — `CATALOG_RL` bu takası zaten kabul etmiş durumda. **Henüz yapılmadı.**

