# Password reset — setup & implementation plan

Companion to [archive/email_confirmation_setup.md](archive/email_confirmation_setup.md).
Same mechanism, same hosted page, one new `type`.

Why a hosted page and not a deep link: recovery links are opened in whatever
browser the mail client hands them to. The PKCE `?code=` flow can't be
completed there — the `code_verifier` lives only inside the app instance that
started the flow. A `token_hash` is server-verifiable on its own, so a static
page can verify the token *and* set the new password. Works on all five
platforms with zero deep-link work.

UX: user taps **Forgot password?** → mail arrives → link opens
`https://elymsyr.github.io/reset/` → new password entered there → user returns
to the app and signs in.

Three surfaces change. Only the first lives in this repo.

---

## 1. App code (this repo)

### 1a. `AuthNotifier.resetPassword`

[lib/application/providers/auth_provider.dart](../lib/application/providers/auth_provider.dart),
next to `signIn`:

```dart
/// Şifre sıfırlama maili gönderir. Başarıda null döner.
/// Sıfırlama, e-posta doğrulamayla aynı hosted sayfada tamamlanır
/// (token_hash + verifyOtp) — deep link kullanılmaz.
Future<String?> resetPassword(String email) async {
  try {
    await Supabase.instance.client.auth.resetPasswordForEmail(email);
    return null;
  } on AuthException catch (e) {
    return e.message;
  } catch (e) {
    return e.toString();
  }
}
```

No `redirectTo`: the link target comes from the email template (step 3b), which
is built off `{{ .SiteURL }}`. Passing `redirectTo` here would require another
entry in the dashboard's Redirect URLs allowlist for no gain.

### 1b. Landing screen

[lib/presentation/screens/landing/landing_screen.dart](../lib/presentation/screens/landing/landing_screen.dart) —
inside `_buildEmailForm`, above the sign-in/sign-up toggle button:

```dart
if (!_isSignUp)
  Center(
    child: TextButton(
      onPressed: _loading ? null : _forgotPassword,
      child: Text(
        l10n.landingForgotPassword,
        style: TextStyle(fontSize: 11, color: palette.featureCardAccent),
      ),
    ),
  ),
```

Handler, next to `_submit`:

```dart
Future<void> _forgotPassword() async {
  final l10n = L10n.of(context)!;
  final email = _emailController.text.trim();
  if (!email.contains('@') || !email.contains('.')) {
    setState(() => _error = l10n.landingErrInvalidEmail);
    return;
  }

  setState(() { _loading = true; _error = null; _info = null; });
  await ref.read(authProvider.notifier).resetPassword(email);

  // Hata olsa da olmasa da aynı mesaj: aksi halde "bu e-posta kayıtlı mı"
  // sorusu dışarıdan sorulabilir hale gelir (account enumeration).
  if (mounted) {
    setState(() { _loading = false; _info = l10n.landingInfoResetSent; });
  }
}
```

The error return value is deliberately discarded — see step 4d.

### 1c. l10n

Two keys, added to all four `.arb` files in
[lib/presentation/l10n/](../lib/presentation/l10n/), then `flutter gen-l10n`:

| key | en | tr |
|---|---|---|
| `landingForgotPassword` | Forgot password? | Şifremi unuttum |
| `landingInfoResetSent` | If an account exists for this address, a reset link has been sent. | Bu adrese ait bir hesap varsa, sıfırlama bağlantısı gönderildi. |

`de` / `fr` translations follow the same wording. Place them next to the
existing `landing*` keys (`app_en.arb` around line 208).

---

## 2. Hosted reset page (`elymsyr.github.io` repo)

Lives at `reset/index.html` → served at `https://elymsyr.github.io/reset/`.
Not part of this repo; it has its own git remote.

Replace the two placeholders with the same public values the app is built with
(the anon key is public by design; RLS protects the data).

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <!-- token_hash query string'de: Referer ile üçüncü tarafa sızmasın. -->
  <meta name="referrer" content="no-referrer">
  <title>Reset password — Dungeon Master Tool</title>
</head>
<body>
  <main id="app">
    <h1>Set a new password</h1>
    <form id="form" hidden>
      <input id="pw"  type="password" autocomplete="new-password" placeholder="New password" required>
      <input id="pw2" type="password" autocomplete="new-password" placeholder="Repeat password" required>
      <button type="submit">Update password</button>
    </form>
    <p id="msg">Verifying link…</p>
  </main>

  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
  <script>
  const SUPABASE_URL = '__SUPABASE_URL__';
  const SUPABASE_ANON_KEY = '__SUPABASE_ANON_KEY__';

  // persistSession:false — bu sayfanın origin'i (elymsyr.github.io) tüm
  // user-pages projeleriyle paylaşılıyor. Session localStorage'a yazılırsa
  // aynı domaindeki herhangi bir sayfadaki XSS refresh token'ı çalabilir.
  // Session'a yalnızca updateUser çağrısı boyunca ihtiyaç var.
  const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });

  const q = new URLSearchParams(location.search);
  const tokenHash = q.get('token_hash');
  const type = q.get('type') || 'recovery';
  // Token tarayıcı geçmişinde kalmasın.
  history.replaceState(null, '', location.pathname);

  const msg = document.getElementById('msg');
  const form = document.getElementById('form');

  (async () => {
    if (!tokenHash) { msg.textContent = 'Invalid link.'; return; }
    const { error } = await sb.auth.verifyOtp({ token_hash: tokenHash, type });
    if (error) {
      msg.textContent = 'This link is invalid or has expired. Request a new one from the app.';
      return;
    }
    msg.textContent = '';
    form.hidden = false;
  })();

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const pw = document.getElementById('pw').value;
    if (pw !== document.getElementById('pw2').value) {
      msg.textContent = 'Passwords do not match.'; return;
    }
    // Uzunluk/karmaşıklık kuralının otoritesi sunucudaki password policy;
    // buradaki kontrol yalnızca UX (bkz. 3c).
    const { error } = await sb.auth.updateUser({ password: pw });
    if (error) { msg.textContent = error.message; return; }
    await sb.auth.signOut();
    form.hidden = true;
    msg.textContent = 'Password updated. Return to the app and sign in.';
  });
  </script>
</body>
</html>
```

Styling: copy the card/grain/candle-glow CSS from `confirm/index.html` so the
two pages match.

> Yayınlanan sayfa bu snippet'ten iki noktada ayrılıyor (bilinçli, daha sıkı):
> supabase-js CDN'i yerine GoTrue'nun `/verify`, `/user`, `/logout?scope=global`
> endpoint'leri doğrudan `fetch` ile çağrılıyor (üçüncü taraf script host'una
> güven yok, token yalnız bellekte), ve `type` yalnızca `recovery` kabul ediliyor.


> The confirm page can be folded into this one later — it already reads `type`
> from the query string, and `verifyOtp` handles both `email` and `recovery`.
> Two pages is fine; just apply step 4a/4b to **both**.

---

## 3. Supabase dashboard

### 3a. Custom SMTP — blocking prerequisite

The built-in email service sends **2 emails/hour** and only to addresses of the
project's team members. Without custom SMTP, reset mail never reaches a real
user — and neither does signup confirmation today.

Free provider that needs no domain (only a verified sender address):
**Brevo**, 300 mails/day.

Authentication → Emails → Enable Custom SMTP:

```
Host:        smtp-relay.brevo.com
Port:        587
Username:    <Brevo login email>
Password:    <Brevo SMTP key — not the account password>
Sender:      <the address verified in Brevo>
Sender name: Dungeon Master Tool
```

Then Authentication → **Rate Limits**: enabling custom SMTP pins the limit at
30 mails/hour. Raise it to ~50–100/hour (Brevo's ceiling is 300/day). Don't
raise it further; that limit is the spam brake.

### 3b. Reset-password email template

Authentication → Email Templates → **Reset Password**. The link must **not** be
`{{ .ConfirmationURL }}` (that's the PKCE `?code=` flow):

```
{{ .SiteURL }}/reset/?token_hash={{ .TokenHash }}&type=recovery
```

Hazır gövde (Source/HTML moduna yapıştır). Tasarım hosted sayfalarla ve
masaüstü OAuth başarı sayfasıyla aynı dili konuşuyor: `#16110b` zemin, altın
üst kenarlı kart, altın buton, elmas ayraç, seyrek harf aralıklı marka satırı.
Mail istemcileri webfont ve `transform` desteklemediği için Marcellus yerine
Georgia, döndürülmüş elmas yerine `&#9670;` karakteri kullanılıyor; her stil
inline, tek layout aracı `<table>`. İkon `https://elymsyr.github.io/media/icon.png`
üzerinden geliyor — görseller engellendiğinde de kart doğru görünür.

```html
<!DOCTYPE html>
<html lang="en">
  <body style="margin:0;padding:0;background:#16110b;font-family:Georgia,'Times New Roman',serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#16110b;padding:40px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="460" cellpadding="0" cellspacing="0" border="0" style="max-width:460px;width:100%;background:#1e1710;border:1px solid #34281b;border-top:2px solid #d9a96b;">
            <tr>
              <td align="center" style="padding:40px 40px 0;">
                <img src="https://elymsyr.github.io/media/icon.png" width="84" height="84" alt="" style="display:block;width:84px;height:84px;border:0;" />
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:18px 40px 0;">
                <div style="color:#8b7332;font-size:13px;letter-spacing:2px;">&#9670;</div>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:14px 40px 0;">
                <h1 style="margin:0;color:#ecdfc9;font-size:24px;font-weight:normal;letter-spacing:.5px;">Reset Your Password</h1>
                <p style="margin:10px 0 0;color:#b3a184;font-size:15px;line-height:1.7;">
                  Set a new password, then return to the app and sign in. This link works once and expires shortly.
                </p>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:30px 40px 0;">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                  <tr>
                    <td align="center" bgcolor="#d9a96b" style="background:#d9a96b;">
                      <a href="{{ .SiteURL }}/reset/?token_hash={{ .TokenHash }}&type=recovery"
                         style="display:inline-block;padding:14px 40px;color:#16110b;font-size:15px;font-weight:bold;letter-spacing:1px;text-decoration:none;">
                        Set New Password
                      </a>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:24px 40px 0;">
                <p style="margin:0;color:#8b7332;font-size:12px;line-height:1.6;">
                  Button not working? Paste this link into your browser:
                </p>
                <p style="margin:8px 0 0;word-break:break-all;">
                  <a href="{{ .SiteURL }}/reset/?token_hash={{ .TokenHash }}&type=recovery" style="color:#d9a96b;font-size:12px;">{{ .SiteURL }}/reset/?token_hash={{ .TokenHash }}&type=recovery</a>
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:30px 40px 0;">
                <div style="height:1px;background:#34281b;line-height:1px;font-size:0;">&nbsp;</div>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:20px 40px 0;">
                <p style="margin:0;color:#8b7332;font-size:12px;line-height:1.7;">
                  Didn't request a password reset? You can safely ignore this email &mdash; nothing changes.
                </p>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:26px 40px 34px;">
                <span style="color:#55432c;font-size:11px;letter-spacing:2px;text-transform:uppercase;">Dungeon Master Tool</span>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
```

Aynı gövde **Confirm signup** şablonu için de kullanılabilir: link satırındaki
`/reset/` → `/confirm/`, `type=recovery` → `type=email`, başlık "Confirm Your
Email", buton "Confirm Email".

No new Redirect URL entry is needed — Site URL is already
`https://elymsyr.github.io`.

### 3c. Password policy — server side, not client side

Authentication → Policies:

- **Minimum password length** — match or beat the app's 6-char check
  (`landing_screen.dart`, `_submit`).
- **Leaked password protection (HIBP)** — on.

Both sign-up and the reset page are separate code paths; a client-side rule
would have to be duplicated (and would then drift). One server-side policy
covers both.

### 3d. Token lifetime

Authentication → **Email OTP Expiration**: default is 1 hour. 15–30 min is
enough for a recovery link and shrinks the window if the mailbox is exposed.

---

## 4. Security requirements

Items 4a and 4b also apply to the **existing** `confirm/index.html`.

**4a. Never persist the session in the browser.** `verifyOtp` returns a real
access + refresh token. `elymsyr.github.io` is a shared origin across every
GitHub user-pages project, so localStorage there is readable by any XSS on that
domain. `persistSession:false` + `signOut()` after the update — both in the
snippet above.

**4b. No referrer, no history.** `token_hash` travels in the query string; the
page loads a CDN script, so without `<meta name="referrer" content="no-referrer">`
the token goes out in a `Referer` header. `history.replaceState` clears it from
the address bar and back-stack.

**4c. Password rules live on the server.** See 3c.

**4d. No account enumeration.** `resetPasswordForEmail` doesn't distinguish a
registered address from an unknown one, and `_forgotPassword` shows the same
message either way. Don't surface its error — doing so turns the button into a
"is this email registered?" oracle.

**4e. CSP + form fallback.** Her iki hosted sayfada `<meta http-equiv=
"Content-Security-Policy">`: `default-src 'none'`, yalnız Google Fonts ve bu
projenin Supabase origin'i açık, `form-action 'none'`. Ayrıca `#prompt`'ta
inline `display:none` ve `show()` inline display'i de yönetiyor — `.hidden`
yalnız `auth.css`'te tanımlı, CSS ile script birlikte düşerse form handler'sız
görünür olup native GET submit ile parolayı URL'e yazıyordu.

Accepted, tracked, not fixed here:

- ~~**Session revocation on password change**~~ — **kapatıldı**: sayfa parolayı
  güncelledikten sonra `POST /auth/v1/logout?scope=global` çağırıyor, saldırganın
  elindeki refresh token'lar da düşüyor. Bu çağrı kendi `try`'ında: `PUT /user`
  başarılı olduktan sonra artık parola **değişmiştir**, logout'un ağ hatası akışı
  geri saramaz. Hata halinde sayfa yine "başarılı" diyor ve altına "diğer
  cihazlar kapatılamadı" uyarısı ekliyor — aksi halde kullanıcı "olmadı" sanıp
  vazgeçiyor ve parolasının değiştiğinden habersiz kalıyordu.
- **OAuth-only users** — sending a reset to a Google-registered address lets a
  password be set on that account. Not a takeover (whoever reads the inbox owns
  the account already), but it creates a second sign-in path that bypasses
  Google's 2FA.
- **Ban check** — the reset page doesn't call `am_i_banned`. Bans are only
  enforced client-side anyway (`banned_users` isn't consulted by RLS —
  [008_admin_user_management.sql:24](../../supabase/migrations/008_admin_user_management.sql#L24)),
  so this changes nothing. Separate piece of work.

---

## 5. Test checklist

1. Registered address → mail arrives, link opens the page, new password set,
   sign-in with the new password works in the app.
2. Old password no longer works.
3. Same link clicked twice → second attempt reports invalid/expired
   (`token_hash` is single-use).
4. Link opened after the OTP expiry window → invalid, app offers a new one.
5. Unknown address → same UI message, no mail, no error revealing anything.
6. Below-minimum password → rejected by the server policy, not just the page.
7. After a successful reset, browser devtools → Application → Local Storage on
   `elymsyr.github.io` holds **no** `sb-*-auth-token` entry.
8. Offline / Supabase not configured → the button is inert, no crash
   (`SupabaseConfig.isConfigured` guard path).

---

## Notes

- No app-side deep link, no new Redirect URL, no edge function. Supabase Auth
  sends the mail itself; nothing in this repo does.
- Vault: when the code lands, update
  `vault/10-Files/multiplayer/auth_provider.md` (Key Logic + `updated:`) and
  append a line to `vault/90-Meta/Vault-Changelog.md`.
