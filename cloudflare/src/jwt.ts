// ============================================================================
// Supabase JWT asimetrik doğrulama (RS256 / ES256 via JWKS)
// ============================================================================
// Harici kütüphane kullanmıyoruz — Cloudflare Workers global crypto.subtle
// hem RS256 hem ES256 için yeterli. Bundle overhead'i yok.
//
// Supabase projesi asimetrik signing key kullanmalı. Yeni projeler ES256
// (P-256), eski projeler RS256 (RSA) olabilir. HS256 (symmetric) eski
// projelerde Dashboard > Settings > JWT Keys > Migrate ile asimetriğe çevrilir.
// ============================================================================

export interface JwtPayload {
  sub: string;
  exp: number;
  iat?: number;
  iss?: string;
  aud?: string | string[];
  role?: string;
  [key: string]: unknown;
}

interface Jwk {
  kid: string;
  kty: string;
  alg?: string;
  // RSA
  n?: string;
  e?: string;
  // EC
  crv?: string;
  x?: string;
  y?: string;
  use?: string;
}

interface JwksResponse {
  keys: Jwk[];
}

interface JwksCacheEntry {
  keys: Jwk[];
  fetchedAt: number;
}

const JWKS_TTL_MS = 5 * 60 * 1000;
const jwksCache = new Map<string, JwksCacheEntry>();

export class JwtError extends Error {
  constructor(public readonly reason: string) {
    super(reason);
    this.name = 'JwtError';
  }
}

async function fetchJwks(supabaseUrl: string): Promise<Jwk[]> {
  const cached = jwksCache.get(supabaseUrl);
  if (cached && Date.now() - cached.fetchedAt < JWKS_TTL_MS) {
    return cached.keys;
  }
  const res = await fetch(`${supabaseUrl}/auth/v1/.well-known/jwks.json`);
  if (!res.ok) {
    throw new JwtError(`jwks_fetch_failed_${res.status}`);
  }
  const data = (await res.json()) as JwksResponse;
  if (!data.keys?.length) {
    throw new JwtError('jwks_empty');
  }
  jwksCache.set(supabaseUrl, { keys: data.keys, fetchedAt: Date.now() });
  return data.keys;
}

function base64urlToBytes(input: string): Uint8Array {
  let s = input.replace(/-/g, '+').replace(/_/g, '/');
  while (s.length % 4) s += '=';
  const binary = atob(s);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function base64urlToString(input: string): string {
  return new TextDecoder().decode(base64urlToBytes(input));
}

export async function verifyJwt(
  token: string,
  supabaseUrl: string,
): Promise<JwtPayload> {
  const parts = token.split('.');
  if (parts.length !== 3) throw new JwtError('invalid_format');

  const [headerB64, payloadB64, sigB64] = parts;

  let header: { alg: string; kid?: string };
  let payload: JwtPayload;
  try {
    header = JSON.parse(base64urlToString(headerB64));
    payload = JSON.parse(base64urlToString(payloadB64)) as JwtPayload;
  } catch {
    throw new JwtError('invalid_json');
  }

  const algParams = algToParams(header.alg);
  if (!algParams) throw new JwtError('unsupported_alg');

  if (typeof payload.sub !== 'string' || !payload.sub) {
    throw new JwtError('no_subject');
  }
  if (typeof payload.exp !== 'number' || payload.exp * 1000 < Date.now()) {
    throw new JwtError('expired');
  }

  const expectedIss = `${supabaseUrl.replace(/\/$/, '')}/auth/v1`;
  if (payload.iss && payload.iss !== expectedIss) {
    throw new JwtError('bad_issuer');
  }

  const jwks = await fetchJwks(supabaseUrl);
  const jwk = header.kid
    ? jwks.find((k) => k.kid === header.kid)
    : jwks.find((k) => k.kty === algParams.kty) ?? jwks[0];
  if (!jwk) throw new JwtError('no_matching_key');
  if (jwk.kty !== algParams.kty) throw new JwtError('key_type_mismatch');

  const cryptoKey = await crypto.subtle.importKey(
    'jwk',
    jwk as JsonWebKey,
    algParams.importAlgorithm,
    false,
    ['verify'],
  );

  const rawSig = base64urlToBytes(sigB64);
  const signature =
    header.alg === 'ES256' ? derToJoseIfNeeded(rawSig, 32) : rawSig;
  const signingInput = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const valid = await crypto.subtle.verify(
    algParams.verifyAlgorithm,
    cryptoKey,
    signature,
    signingInput,
  );
  if (!valid) throw new JwtError('bad_signature');

  return payload;
}

interface AlgParams {
  kty: string;
  importAlgorithm: RsaHashedImportParams | EcKeyImportParams;
  verifyAlgorithm: AlgorithmIdentifier | EcdsaParams;
}

function algToParams(alg: string): AlgParams | null {
  switch (alg) {
    case 'RS256':
      return {
        kty: 'RSA',
        importAlgorithm: { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        verifyAlgorithm: 'RSASSA-PKCS1-v1_5',
      };
    case 'ES256':
      return {
        kty: 'EC',
        importAlgorithm: { name: 'ECDSA', namedCurve: 'P-256' },
        verifyAlgorithm: { name: 'ECDSA', hash: 'SHA-256' },
      };
    default:
      return null;
  }
}

/// Supabase/PostgREST ES256 bazen DER-encoded imza döndürebilir; crypto.subtle
/// ECDSA verify JOSE (r||s concat) format bekler. Gerçek JWT imzaları zaten
/// JOSE formatındadır, ama defansif olarak DER ise çeviriyoruz.
function derToJoseIfNeeded(sig: Uint8Array, coordBytes: number): Uint8Array {
  if (sig.length === coordBytes * 2) return sig;
  if (sig[0] !== 0x30) return sig;
  let offset = 2;
  if (sig[1] & 0x80) offset += sig[1] & 0x7f;
  if (sig[offset] !== 0x02) return sig;
  const rLen = sig[offset + 1];
  const rStart = offset + 2;
  const rEnd = rStart + rLen;
  if (sig[rEnd] !== 0x02) return sig;
  const sLen = sig[rEnd + 1];
  const sStart = rEnd + 2;
  const sEnd = sStart + sLen;
  const r = sig.slice(rStart, rEnd);
  const s = sig.slice(sStart, sEnd);
  const out = new Uint8Array(coordBytes * 2);
  out.set(stripOrPad(r, coordBytes), 0);
  out.set(stripOrPad(s, coordBytes), coordBytes);
  return out;
}

function stripOrPad(buf: Uint8Array, size: number): Uint8Array {
  if (buf.length === size) return buf;
  if (buf.length === size + 1 && buf[0] === 0x00) return buf.slice(1);
  if (buf.length < size) {
    const out = new Uint8Array(size);
    out.set(buf, size - buf.length);
    return out;
  }
  return buf.slice(buf.length - size);
}
