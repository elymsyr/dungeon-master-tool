# 41 — Security & Privacy

> **For Claude.** Threat model, RLS audit, anti-cheat policy, PII handling.

## Threat Model

| Threat | Severity | Mitigation |
|---|---|---|
| Unauthorized session join | High | RLS: only participant or DM can read session content |
| Player edits another player's character | High | RLS: only owner or DM can edit |
| Player sees DM-only fields | Medium | Server-side filtering before broadcast |
| Code brute force | Medium | Rate limit code lookups; 32^6 entropy |
| Spam packages on marketplace | Low | Marketplace flagging system |
| Malicious package import | Medium | JSON only (no code execution); validate schema |
| Account takeover | High | Supabase Auth handles; no custom passwords |
| Lost game data | Medium | Local DB backed up; user warned about fresh-start migration |
| Anti-cheat (fake dice rolls) | Low (trust-based MVP) | All clients self-roll; trust DM/players to play fair |

## RLS Audit Procedure

After deploying [20-supabase-schema](./20-supabase-schema.md), test each policy with a non-participant test account:

```sql
-- Login as user_unrelated.
SELECT * FROM game_sessions;   -- expect 0 rows
SELECT * FROM session_participants;   -- expect 0 rows
SELECT * FROM shared_battle_maps;   -- expect 0 rows
INSERT INTO player_drawings (...) VALUES (...);   -- expect RLS violation
```

Repeat as: anon, anonymous-Supabase user, registered non-participant, registered player participant, registered DM. Document expected behavior in a matrix.

Automated test: integration test that spins up Supabase local + creates test users + runs queries.

## Game Code Entropy

- 32-char alphabet, 6 chars = 32^6 ≈ 1.07 × 10^9 combinations.
- Birthday-paradox collision odds at 1000 active sessions: ~0.05% — acceptable; collision check on generation handles it.
- For 100,000 active sessions: ~5%. Still acceptable with collision-retry.
- Codes generated with `Random.secure()` (cryptographic).

### Code Lookup Rate Limit

Supabase doesn't provide built-in rate limiting per-row. Workaround: edge function `verify_game_code(code)` that checks an IP-based bucket:

```sql
CREATE TABLE code_lookup_attempts (
  ip TEXT,
  attempted_at TIMESTAMPTZ DEFAULT now()
);
-- Edge function counts last 60s; if > 30 attempts, return 429.
```

Out of MVP. Note as follow-up.

## PII Handling

User data stored:
- Email (Supabase Auth)
- Display name (user-chosen; can be pseudonym)
- Character data (no PII unless user adds it to notes)
- Game session IDs

User data NOT stored:
- Real name (unless user volunteers)
- Phone number
- Location
- Payment info

GDPR / data deletion: user requests deletion → Supabase Auth user delete cascades to `session_participants` (FK ON DELETE). DM-owned game_sessions become orphaned; null `dm_user_id` and mark `status='closed'`.

**Implement self-service delete:**

```dart
class AccountService {
  Future<void> deleteMyAccount() async {
    final user = supabase.auth.currentUser!;
    // Cascade DELETE on session_participants happens via FK.
    // Mark DM sessions closed.
    await supabase.from('game_sessions').update({'status': 'closed', 'dm_user_id': null}).eq('dm_user_id', user.id);
    // Delete from auth.
    await supabase.auth.admin.deleteUser(user.id);   // requires service role via edge function
    // Locally: clear all caches.
    await _localDataCleaner.purgeAll();
  }
}
```

## Anti-Cheat Policy (MVP: Trust-Based)

D&D is a social game. The DM is the rules arbiter. We do NOT implement:
- Server-side dice rolling (would require dice service + cryptographic commit-reveal).
- Hidden dice from clients.
- Anti-tampering on client state.

We DO implement:
- DM is source of truth for combat state. Players cannot directly write enemy HP, conditions, etc.
- Player declarations (movements, casts) are advisory. DM acknowledges and applies.
- All player actions logged in `player_actions` table for session audit.

If a player acts in bad faith, the DM has full control to override or eject them.

## Package Import Safety

`.dnd5e-pkg.json` is data only — no executable content.

Validation pipeline ([14](./14-package-system-redesign.md)):
1. Parse JSON; reject malformed.
2. Validate schema (required fields, enum values).
3. Validate hash if present.
4. Check size limit (10 MB default).
5. Sanitize text fields (strip HTML/script tags).

Image references in packages are URLs; do not eagerly fetch. Lazy-load with cache.

## Authentication Modes

| Mode | Used By | Capabilities |
|---|---|---|
| Anonymous | Players who don't want account | Join sessions; data lost on app uninstall |
| Email + password | Players + DMs | Full features; data persists |
| OAuth (Google/Apple) | Optional | Same as email |

DMs SHOULD use registered account (data persistence required). Client warns anonymous users hosting a session: "Your session data will be lost if you uninstall."

## Session Data Lifetime

- Active session: indefinite.
- Closed session: 7 days, then deleted.
- Session media (images, PDFs): deleted with session.
- Player drawings: deleted with session.
- Player actions log: deleted with session.

Implement nightly Supabase scheduled function:

```sql
CREATE OR REPLACE FUNCTION cleanup_old_sessions() RETURNS void AS $$
DELETE FROM game_sessions WHERE status = 'closed' AND closed_at < now() - interval '7 days';
$$ LANGUAGE sql;
SELECT cron.schedule('nightly-session-cleanup', '0 3 * * *', 'SELECT cleanup_old_sessions()');
```

## Local Storage

Drift SQLite stored unencrypted. Acceptable: device is user's own; local drawings/notes/world data is user-generated.

If user sensitivity warrants encryption: enable SQLCipher via `drift_sqflite` configuration (requires per-launch passphrase). Out of MVP.

## TLS / Network

All Supabase traffic over HTTPS. Realtime over WSS. No exception. Verified by Supabase SDK defaults.

## Logging

- Local logs: errors only. No PII. Use `logger` package, structured.
- Sentry / Crashlytics: optional. Strip PII before sending.
- Server logs: Supabase platform handles.

## Acceptance

- RLS audit passes (10+ scenarios).
- Account delete fully removes user and cascades data.
- Game codes collision-resistant under 100k concurrent sessions.
- Package import rejects malformed/oversized files.
- No plaintext passwords stored anywhere.
- All Supabase calls over HTTPS/WSS.

## Open Questions

1. Server-side dice rolling for anti-cheat? → No (MVP). Document for future.
2. Encrypt local Drift DB? → No (MVP). Per-app encryption add-on later.
3. 2FA for DM accounts? → Supabase Auth supports MFA; recommend in UI but not enforced.
