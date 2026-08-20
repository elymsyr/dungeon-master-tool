# Email confirmation — setup & fix

Why: signing up with email sent a plain confirmation mail whose link landed on
`http://localhost:3000/?code=...` and never confirmed the account. Root cause:
the default `{{ .ConfirmationURL }}` uses the PKCE `?code=` flow, but the PKCE
`code_verifier` lives only in the app instance that called `signUp` — a browser
(or anything on `localhost:3000`) can't exchange it.

Fix: confirm via a **hosted web page** using `token_hash` + `verifyOtp`. A
`token_hash` is a server-verifiable one-time token — **no `code_verifier`
needed** — so a static page can fully confirm the account. Works on every
platform (mobile + all desktop) because confirmation happens on the web, not via
a deep link. No installers, no per-OS URL-scheme registration, no app code
change.

UX: user clicks the email link → web page confirms → user opens the app and
signs in with email + password (now confirmed).

## 1. Deploy the confirm page

The confirm page is hosted on the existing user-pages site
(`github.com/elymsyr/elymsyr.github.io`, plain static HTML, already served at
`https://elymsyr.github.io/`). The page lives at `confirm/index.html` in that
repo → served at **`https://elymsyr.github.io/confirm/`**.

Before pushing, edit `confirm/index.html` and replace the two placeholders with
the **same public values the app is built with**:

```js
const SUPABASE_URL = '__SUPABASE_URL__';
const SUPABASE_ANON_KEY = '__SUPABASE_ANON_KEY__';
```

The anon key is safe to commit — it's public by design; Row Level Security
protects the data. Commit + push from the `elymsyr.github.io` repo (its own git
remote — it is **not** part of this repo).

> Later, to move to a paid custom domain (e.g. `dungeonmastertool.com`): add a
> `CNAME` file to the pages repo and change the Supabase **Site URL** to the new
> domain. The page itself doesn't change.

## 2. Supabase dashboard — URL configuration

**Authentication → URL Configuration:**

- **Site URL**: set to `https://elymsyr.github.io`
  (this becomes `{{ .SiteURL }}` in the email template, so the confirm link
  resolves to `https://elymsyr.github.io/confirm/...`).
- **Redirect URLs**: both entries are for OAuth — leave them. No new entry needed
  for email confirmation.
  - `com.elymsyr.dungeonmastertool://auth-callback` — mobile (Android/iOS) deep
    link.
  - `http://localhost:*/auth/callback` — desktop (Windows/Linux/macOS). The desktop
    flow binds a local HTTP server on a **random** port, so the `*` wildcard is
    required; without it Supabase falls back to the Site URL and sign-in lands on
    `https://elymsyr.github.io/?code=...` instead of returning to the app.

## 3. Supabase dashboard — Confirm-signup email template

**Authentication → Email Templates → Confirm signup.** Paste the HTML below.

The critical change vs. the default: the link is **not** `{{ .ConfirmationURL }}`
— it points at the confirm page with `token_hash` + `type`:

```
{{ .SiteURL }}/confirm/?token_hash={{ .TokenHash }}&type=email
```

```html
<!DOCTYPE html>
<html lang="en">
  <body style="margin:0;padding:0;background:#0f0e17;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0f0e17;padding:32px 0;">
      <tr>
        <td align="center">
          <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="max-width:480px;background:#1a1825;border:1px solid #2a2740;border-radius:14px;overflow:hidden;">
            <tr>
              <td style="padding:36px 40px 8px;text-align:center;">
                <div style="font-size:34px;line-height:1;">&#9876;&#65039;</div>
                <h1 style="margin:14px 0 0;color:#f5d49b;font-size:22px;letter-spacing:.5px;">Dungeon Master Tool</h1>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 40px 0;text-align:center;">
                <h2 style="margin:18px 0 6px;color:#ffffff;font-size:19px;font-weight:600;">Confirm your email</h2>
                <p style="margin:0;color:#b6b2c9;font-size:15px;line-height:1.6;">
                  Welcome, adventurer. Confirm your address, then open the app and sign in to start managing your campaigns.
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:28px 40px 8px;text-align:center;">
                <a href="{{ .SiteURL }}/confirm/?token_hash={{ .TokenHash }}&type=email"
                   style="display:inline-block;background:#7b5cff;color:#ffffff;text-decoration:none;font-size:16px;font-weight:600;padding:14px 38px;border-radius:10px;">
                  Confirm email
                </a>
              </td>
            </tr>
            <tr>
              <td style="padding:18px 40px 0;text-align:center;">
                <p style="margin:0;color:#7d7a91;font-size:12px;line-height:1.6;">
                  Button not working? Paste this link into your browser:
                </p>
                <p style="margin:6px 0 0;word-break:break-all;">
                  <a href="{{ .SiteURL }}/confirm/?token_hash={{ .TokenHash }}&type=email" style="color:#9d86ff;font-size:12px;">{{ .SiteURL }}/confirm/?token_hash={{ .TokenHash }}&type=email</a>
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:28px 40px 36px;text-align:center;border-top:1px solid #2a2740;">
                <p style="margin:18px 0 0;color:#5c5972;font-size:12px;line-height:1.6;">
                  Didn't create an account? You can safely ignore this email.
                </p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
```

## Notes

- `type=email` is the Supabase-recommended OTP type for signup confirmation; the
  page reads `type` from the query and passes it straight to `verifyOtp`.
- The same page also works for any future email link that carries a
  `token_hash` (e.g. password recovery) by changing `type`.
- App code is unchanged for confirmation. The deep-link scheme
  `com.elymsyr.dungeonmastertool://auth-callback` remains in use **only** for
  OAuth on mobile.
