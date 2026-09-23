// presign.ts'in tek kontrolü: AWS'nin yayımlanmış SigV4 query-string örneği
// ("Authenticating Requests: Using Query Parameters", examplebucket/test.txt).
// İmza bir karakter bile saparsa R2 her URL'i 403 ile reddeder.
//
//   npm run check
import assert from 'node:assert/strict';
import { presign } from './src/presign.ts';

const url = await presign({
  method: 'GET',
  host: 'examplebucket.s3.amazonaws.com',
  path: '/test.txt',
  region: 'us-east-1',
  accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
  secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
  expiresSec: 86400,
  headers: {},
  now: new Date('2013-05-24T00:00:00Z'),
});

assert.equal(
  url,
  'https://examplebucket.s3.amazonaws.com/test.txt' +
    '?X-Amz-Algorithm=AWS4-HMAC-SHA256' +
    '&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request' +
    '&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host' +
    '&X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404',
);
console.log('presign OK');
