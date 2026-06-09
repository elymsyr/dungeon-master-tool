---
type: file-note
domain: backend
path: cloudflare/src/jwt.ts
layer: backend
language: typescript
status: stable
updated: 2026-06-09
tags: [file]
---

# `jwt.ts`

> [!abstract] Primary Purpose
> Zero-dependency asymmetric Supabase JWT verification for the Cloudflare Worker. Uses the global `crypto.subtle` to validate RS256 (RSA) and ES256 (EC P-256) signatures against the project's JWKS, with a 5-minute in-memory JWKS cache. Returns the decoded `JwtPayload` (notably `sub` = user id) or throws a typed `JwtError`.

## Inputs / Outputs
**Inputs**
- `verifyJwt(token, supabaseUrl)` — the raw JWT (sans `Bearer `) and the Supabase project URL.
- Fetches JWKS from `${supabaseUrl}/auth/v1/.well-known/jwks.json`.

**Outputs**
- Returns `JwtPayload` (`{ sub, exp, iss?, role?, ... }`).
- Throws `JwtError(reason)` with reasons surfaced by the Worker as the `error` field (e.g. `invalid_format`, `unsupported_alg`, `expired`, `bad_issuer`, `no_matching_key`, `bad_signature`).

## Dependencies & Links
- Depends on: nothing (uses Web Crypto `crypto.subtle` only)
- Used by: [[worker]]
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[Multiplayer-and-Online]]

## Key Logic / Variables
- **JWKS cache**: `Map<supabaseUrl, {keys, fetchedAt}>`, TTL `JWKS_TTL_MS = 5 min`. Empty key set → `jwks_empty`.
- **Verification steps** (`verifyJwt`): split into 3 parts; base64url-decode header+payload; resolve alg via `algToParams` (only `RS256`/`ES256` supported, else `unsupported_alg`); require non-empty string `sub`; require numeric `exp` not in the past (`expired`); if `iss` present it must equal `${supabaseUrl}/auth/v1` (`bad_issuer`); pick JWK by `kid` (fallback by `kty`), import via `crypto.subtle.importKey('jwk', ...)`, verify signature.
- **ES256 signature normalization**: `derToJoseIfNeeded` converts a DER-encoded ECDSA signature into the raw JOSE `r||s` (32+32) form that `crypto.subtle.verify` expects; `stripOrPad` handles the leading `0x00` padding byte and short/long coordinates.
- **Alg params**: RS256 → `RSASSA-PKCS1-v1_5` + SHA-256, `kty=RSA`; ES256 → `ECDSA` P-256 + SHA-256, `kty=EC`.

## Notes
- Project must use asymmetric signing keys. Legacy HS256 (symmetric) projects must migrate in Supabase Dashboard > Settings > JWT Keys.
- No external JWT library — keeps the Worker bundle small.
