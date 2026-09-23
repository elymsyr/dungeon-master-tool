// ============================================================================
// R2 presigned URL — AWS SigV4, query-string imzası (Faz 5d).
// ============================================================================
// Baytlar worker'dan geçmesin diye: worker izni bir RPC ile doğrular, R2'nin
// S3 uç noktası için kısa ömürlü bir URL imzalar, istemci R2 ile doğrudan
// konuşur. Bağımlılık yok — WebCrypto HMAC yeterli.
//
// İmzalanan başlıklar ([headers]) istekte AYNEN gönderilmek zorunda: PUT'ta
// `content-length` ve `content-type` imzaya bağlanır, R2 farklı boyuttaki
// gövdeyi imza uyuşmazlığıyla reddeder. Dosya limiti böyle worker'sız zorlanır.
// ============================================================================

export interface R2Credentials {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
}

/// `method` + `key` için [expiresSec] saniye geçerli bir R2 URL'i.
export function presignR2(
  creds: R2Credentials,
  method: 'GET' | 'PUT',
  key: string,
  expiresSec: number,
  headers: Record<string, string> = {},
  now: Date = new Date(),
): Promise<string> {
  return presign({
    method,
    host: `${creds.accountId}.r2.cloudflarestorage.com`,
    path: `/${creds.bucket}/${key.split('/').map(rfc3986).join('/')}`,
    region: 'auto',
    accessKeyId: creds.accessKeyId,
    secretAccessKey: creds.secretAccessKey,
    expiresSec,
    headers,
    now,
  });
}

/// SigV4 çekirdeği — R2'den bağımsız, AWS'nin yayımlanmış test vektörüyle
/// doğrulanabilsin diye ayrı (bkz. presign.check.mjs).
export async function presign(o: {
  method: string;
  host: string;
  path: string;
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
  expiresSec: number;
  headers: Record<string, string>;
  now: Date;
}): Promise<string> {
  const amzDate = o.now.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  const date = amzDate.slice(0, 8);
  const scope = `${date}/${o.region}/s3/aws4_request`;

  const hdrs: Record<string, string> = { host: o.host };
  for (const [k, v] of Object.entries(o.headers)) hdrs[k.toLowerCase()] = v.trim();
  const names = Object.keys(hdrs).sort();
  const signedHeaders = names.join(';');

  const query: Record<string, string> = {
    'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
    'X-Amz-Credential': `${o.accessKeyId}/${scope}`,
    'X-Amz-Date': amzDate,
    'X-Amz-Expires': String(o.expiresSec),
    'X-Amz-SignedHeaders': signedHeaders,
  };
  const canonicalQuery = Object.keys(query)
    .sort()
    .map((k) => `${rfc3986(k)}=${rfc3986(query[k])}`)
    .join('&');

  const canonicalRequest = [
    o.method,
    o.path,
    canonicalQuery,
    names.map((n) => `${n}:${hdrs[n]}\n`).join(''),
    signedHeaders,
    'UNSIGNED-PAYLOAD',
  ].join('\n');

  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    scope,
    hex(await crypto.subtle.digest('SHA-256', utf8(canonicalRequest))),
  ].join('\n');

  let key: ArrayBuffer = utf8(`AWS4${o.secretAccessKey}`).buffer as ArrayBuffer;
  for (const part of [date, o.region, 's3', 'aws4_request']) {
    key = await hmac(key, part);
  }
  const signature = hex(await hmac(key, stringToSign));

  return `https://${o.host}${o.path}?${canonicalQuery}&X-Amz-Signature=${signature}`;
}

async function hmac(key: ArrayBuffer, msg: string): Promise<ArrayBuffer> {
  const k = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return crypto.subtle.sign('HMAC', k, utf8(msg));
}

function utf8(s: string): Uint8Array {
  return new TextEncoder().encode(s);
}

function hex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/// SigV4'ün istediği katı URI kodlaması: encodeURIComponent `!'()*`'i açık
/// bırakıyor, S3 onları da kodlanmış bekliyor.
function rfc3986(s: string): string {
  return encodeURIComponent(s).replace(
    /[!'()*]/g,
    (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}
