# Online System — Vision, Architecture & Design

> **Document Status:** Active
> **Last Updated:** 2026-03-22
> **Supersedes:** Core architectural content of `docs/DEVELOPMENT_REPORT.md`
> **Companion Document:** `docs/ONLINE_SPRINT.md` (sprint-level execution plan)
> **Scope:** Everything related to the online/hybrid system — vision, architecture, design decisions, security, deployment

---

## Table of Contents

1. [Vision Statement](#1-vision-statement)
2. [Target User Experience](#2-target-user-experience)
3. [Architecture Overview](#3-architecture-overview)
4. [Bounded Contexts](#4-bounded-contexts)
5. [Permission Model](#5-permission-model)
6. [Real-Time Sync Design](#6-real-time-sync-design)
7. [Asset Management](#7-asset-management)
8. [Reconnect and Resilience](#8-reconnect-and-resilience)
9. [Security](#9-security)
10. [Performance Targets](#10-performance-targets)
11. [Online-Only Features](#11-online-only-features)
12. [Deployment Architecture](#12-deployment-architecture)
13. [Phase Roadmap](#13-phase-roadmap)
14. [Success Criteria and KPIs](#14-success-criteria-and-kpis)

---

## 1. Vision Statement

> **"Preserve the full power of the DM's desktop tool. Let players join with minimal friction — a single 6-character code."**

The DM Tool has always been built around the DM's needs: a rich, offline-capable, feature-dense desktop application. The online system must not compromise that. Players join a live session through a lightweight connection that adds real-time awareness without requiring them to install anything or manage accounts.

### Design Principles

1. **DM sovereignty.** The DM controls everything: what players see, what content is shared, when the session starts and ends. Players are guests, not peers.
2. **Offline-first.** Every feature works offline. Online connectivity enhances the experience but is never required. A network dropout during play is gracefully handled.
3. **Minimal player friction.** A player joins with a 6-character code. No account required on the player side (account optional for persistence across sessions).
4. **Zero content leakage.** Content marked private by the DM is never transmitted to player clients — not even as encrypted data.
5. **Incremental sync.** Large assets are not broadcast; they are proxied on demand. Events carry deltas, not full state snapshots.
6. **DM client is the source of truth.** The server is a relay and persistence layer, not a game engine. Business logic stays in the DM client.

---

## 2. Target User Experience

### 2.1 DM Journey

1. DM opens the application (offline mode, as always).
2. DM loads or creates a campaign.
3. DM clicks **"Start Online Session"** — is prompted to log in (if not already) and assign a session name.
4. A **6-character join code** is displayed (e.g., `WOLF42`).
5. DM shares the code with players via any channel (Discord, voice, chat).
6. Players join; the DM sees each player appear in the **GM Screen Control Panel** with their chosen name and role.
7. The DM continues using the application exactly as in offline mode — all existing tools work identically.
8. Changes the DM makes (fog of war reveal, entity card push, audio change) are automatically reflected on connected player clients.
9. The DM can end the session at any time; players are notified and disconnected cleanly.

### 2.2 Player Journey

**Option A — Web Player (no install):**
1. Player receives the join code.
2. Player opens the web player URL in a browser, enters the join code and a display name.
3. Player is immediately connected and sees the current DM view (map, entity card, image, or blank).
4. Player can roll dice, view their character sheet (if the DM has shared it), and read the event log.

**Option B — Desktop Player Client:**
1. Player uses the same DM Tool application but opens it in **Player Mode**.
2. Player enters the join code; the interface simplifies to player-relevant views only.

### 2.3 Session Lifecycle

```
DM: Start Session
      │
      ▼
Server: Create session record, generate join code
      │
      ▼
DM Client: EventManager → NetworkBridge → Socket.io connected
      │
      ▼
Players: Join via code → Server validates → Player socket connected
      │
      ▼
Active Session:
  DM actions → EventManager → NetworkBridge → Server → Player clients
  Player dice rolls → Player client → Server (validates) → DM + all players
      │
      ▼
DM: End Session
      │
      ▼
Server: Archive session log, disconnect all players
```

---

## 3. Architecture Overview

### 3.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          CLIENT LAYER                                    │
│                                                                          │
│  ┌─────────────────────────────┐    ┌──────────────────────────────┐   │
│  │    DM Client (PyQt6)         │    │   Player Client              │   │
│  │                              │    │   (Web browser / PyQt6)      │   │
│  │  DataManager                 │    │                              │   │
│  │      ↕                       │    │  Simplified UI               │   │
│  │  EventManager                │    │  Socket.io client            │   │
│  │      ↕                       │    │                              │   │
│  │  NetworkBridge               │    │                              │   │
│  │  (Socket.io client)          │    │                              │   │
│  └──────────┬──────────────────┘    └─────────────┬────────────────┘   │
│             │ WebSocket (Socket.io)                │ WebSocket          │
└─────────────┼──────────────────────────────────────┼────────────────────┘
              │                                       │
              ▼                                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          SERVER LAYER                                    │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │              FastAPI + python-socketio (ASGI)                     │  │
│  │                                                                    │  │
│  │  /auth/*        — JWT issue, refresh, revoke                      │  │
│  │  /sessions/*    — create, join, list, archive                     │  │
│  │  /assets/*      — signed URL proxy, metadata                      │  │
│  │                                                                    │  │
│  │  Socket.io namespaces:                                            │  │
│  │    /session     — event relay, permission enforcement             │  │
│  │    /dice        — server-side dice generation                     │  │
│  └────┬──────────────┬──────────────┬───────────────────────────────┘  │
│       │              │              │                                    │
│  ┌────▼────┐   ┌─────▼─────┐ ┌────▼────┐                             │
│  │ Postgres│   │   Redis   │ │  MinIO  │                             │
│  │  (data) │   │  (pubsub/ │ │(assets) │                             │
│  │         │   │   cache)  │ │         │                             │
│  └─────────┘   └───────────┘ └─────────┘                             │
│                                                                          │
│  ┌────────────────┐  ┌────────────┐                                    │
│  │   Prometheus   │  │    Loki    │                                    │
│  │  (metrics)     │  │  (logs)    │                                    │
│  └────────────────┘  └────────────┘                                    │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Technology Stack

#### Client Side

| Component | Technology | Rationale |
|---|---|---|
| DM UI | Python 3.12 + PyQt6 | Existing codebase; rich desktop capabilities |
| Network client | `python-socketio[client]` | Matches server-side Socket.io; async-capable |
| Serialization (local) | MsgPack | Fast binary for offline data |
| Serialization (network) | JSON (via Socket.io) | Interoperability with web player |
| Data validation | Pydantic v2 | Event schema validation; fast |
| Caching | Local filesystem (existing pattern) | Asset cache for signed URLs |

#### Server Side

| Component | Technology | Rationale |
|---|---|---|
| API framework | FastAPI | Async, Pydantic-native, OpenAPI docs |
| WebSocket | `python-socketio` (ASGI mode) | Matches client library; room/namespace support |
| Database | PostgreSQL 16 | Relational, reliable, JSONB for entity snapshots |
| Cache / PubSub | Redis 7 | Session state, rate limiting, pub/sub for multi-instance |
| Object storage | MinIO (S3-compatible) | Self-hostable; S3 API for easy cloud migration |
| Migrations | Alembic | Schema version control with rollback |
| Auth | JWT (RS256) with refresh tokens | Stateless verification; revocable via Redis blocklist |
| ASGI server | Uvicorn + Gunicorn | Production-grade Python ASGI |
| Reverse proxy | Nginx | TLS termination, rate limiting, static assets |

#### Operations

| Component | Technology |
|---|---|
| Containerization | Docker + Docker Compose |
| Metrics | Prometheus + Grafana |
| Log aggregation | Loki + Grafana |
| CI/CD | GitHub Actions |
| Secrets | Docker secrets / environment files |

---

## 4. Bounded Contexts

The server is organized around 5 bounded contexts. Each has its own database tables, event types, and API surface.

### 4.1 Identity Context

**Responsibility:** User registration, authentication, JWT lifecycle.

**Entities:** `User`, `RefreshToken`

**API:**
```
POST /auth/register     — Create account (email + password)
POST /auth/login        — Issue access + refresh tokens
POST /auth/refresh      — Exchange refresh token for new access token
POST /auth/logout       — Revoke refresh token (add to Redis blocklist)
GET  /auth/me           — Current user profile
```

**Notes:**
- Players can join sessions without accounts (anonymous mode) — their `session_participant` record uses a temporary ID
- DMs must have accounts to create sessions
- Passwords hashed with bcrypt (cost factor 12)
- Access tokens expire in 15 minutes; refresh tokens in 30 days

### 4.2 Session Context

**Responsibility:** Session lifecycle, participant management, join codes.

**Entities:** `Session`, `SessionParticipant`

**API:**
```
POST /sessions/create         — DM creates a new session (returns join code)
POST /sessions/join           — Player joins with 6-char code + display name
GET  /sessions/{id}           — Session metadata (DM only: full; Players: limited)
POST /sessions/{id}/end       — DM ends session; all participants disconnected
GET  /sessions/history        — DM's past sessions (paginated)
```

**Join Code Generation:**
- 6 characters, uppercase alphanumeric, excluding confusable characters (0/O, 1/I/L)
- Codes are active only during an open session; reused after session ends
- Collision probability with 32^6 = 1 billion codes is negligible for typical session counts

**Session States:** `waiting` → `active` → `ended`

### 4.3 Sync Context

**Responsibility:** Real-time event relay between DM and player clients.

**Socket.io Namespace:** `/session`

**Rooms:** Each active session has a room (`session:{session_id}`) and a DM-only sub-room (`session:{session_id}:dm`).

**Event flow:**
1. DM client emits event to server
2. Server validates sender role and event type
3. Server filters payload based on content visibility rules (Section 5)
4. Server relays filtered event to all players in the session room
5. Server persists event to `event_log` table (append-only)

### 4.4 Assets Context

**Responsibility:** Proxying and caching DM asset files for player clients.

**API:**
```
POST /assets/upload           — DM uploads asset; server returns asset_id + signed URL
GET  /assets/{id}/url         — Get a fresh signed URL (expires in 15 min)
GET  /assets/{id}/metadata    — Filename, size, MIME type, dimensions (images)
DELETE /assets/{id}           — DM deletes asset
```

**Notes:**
- Assets are stored in MinIO; the server never serves them directly (avoids bandwidth bottleneck)
- Player clients receive signed MinIO URLs and download assets directly
- Player clients cache assets locally using a content-addressed file cache
- Signed URL TTL (15 minutes) balances security with reconnect usability

### 4.5 Gameplay Context

**Responsibility:** Server-authoritative features that must not be client-controlled.

**Sub-contexts:**

**Dice Roller:**
- Players and DM can request dice rolls via the server
- Server generates roll using `secrets.randbelow()` (cryptographically secure)
- Roll result is broadcast to all session participants simultaneously
- Roll history is appended to the event log
- Prevents any client from faking or pre-computing dice results

**Event Log:**
- Append-only log of all session events
- Persisted in PostgreSQL `event_log` table
- DM can query full log; players receive a filtered view
- Exported as plain text or JSON at session end

**Restricted Entity Views:**
- Entity cards with `visibility: private_dm` are never sent to player clients
- Entity cards with `visibility: shared_restricted` are sent with DM-marked fields redacted

---

## 5. Permission Model

### 5.1 Roles

| Role | Who | Capabilities |
|---|---|---|
| `DM_OWNER` | The session creator | Full control: read/write all data, control all sync events, end session |
| `PLAYER` | Joined participant (named) | Read shared content, roll dice, view their own character sheet |
| `OBSERVER` | Joined participant (spectator) | Read-only: see map and shared content; no dice, no character sheet |

### 5.2 Content Visibility Tiers

Every entity, map pin, and session object has a `visibility` field:

| Visibility | Transmitted to players? | Notes |
|---|---|---|
| `private_dm` | Never | Notes, hidden NPCs, secret map areas, DM prep |
| `shared_full` | Yes, complete | Combat-ready NPCs, shared images, public map data |
| `shared_restricted` | Yes, redacted | NPCs with some fields hidden (e.g., HP shown as "Bloodied", not exact number) |

### 5.3 Field-Level Redaction

For `shared_restricted` entities, the DM marks individual fields as hidden. The server removes these fields before forwarding to player clients:

```json
// DM sees (full entity)
{
  "name": "Shadow Assassin",
  "hp_current": 45,
  "hp_max": 60,
  "hidden_weakness": "sunlight",
  "_visibility": "shared_restricted",
  "_hidden_fields": ["hp_current", "hp_max", "hidden_weakness"]
}

// Players receive (redacted)
{
  "name": "Shadow Assassin",
  "hp_status": "wounded",
  "_visibility": "shared_restricted"
}
```

The `hp_status` label (`healthy`, `wounded`, `bloodied`, `critical`, `dead`) is computed server-side from the actual HP range.

### 5.4 Permission Enforcement

All permission checks are enforced **server-side**. The client never receives data it should not have access to. Even if a player modifies their client code, they cannot access `private_dm` content because it is filtered before reaching the WebSocket payload.

```python
# server/sync/relay.py

def filter_event_for_player(event: EventEnvelope, player_role: str) -> EventEnvelope | None:
    """Return filtered event payload appropriate for the player role, or None to suppress."""
    if event.event_type == "entity.updated":
        entity = db.get_entity(event.payload["entity_id"])
        if entity.visibility == "private_dm":
            return None  # Suppress entirely
        if entity.visibility == "shared_restricted":
            event.payload = redact_hidden_fields(entity, event.payload)
    return event
```

---

## 6. Real-Time Sync Design

### 6.1 EventManager Bridge

The `NetworkBridge` (created in Sprint 2 skeleton) subscribes to all `EventManager` events. When connected to the server, it serializes and transmits tagged events over the Socket.io connection.

```
DataManager.save_entity()
    → EventManager.emit("entity.updated", payload)
        → UI Widget._on_entity_updated(payload)   [local update]
        → NetworkBridge._on_any_event(payload)    [if connected: send to server]
```

### 6.2 Event Envelope

Every online event uses the standard envelope defined in `core/network/events.py`:

```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_type": "entity.updated",
  "session_id": "sess_abc123",
  "sender_role": "dm",
  "timestamp": "2026-04-15T20:30:00.000Z",
  "payload": {
    "entity_id": "npc_goblin_001",
    "changed_fields": ["hp_current", "conditions"],
    "patch": {
      "hp_current": 12,
      "conditions": ["poisoned"]
    }
  }
}
```

### 6.3 Delivery Guarantees

**At-least-once delivery:** The server persists all received events to the event log before relaying. If the server crashes mid-relay, a reconnecting client can request a delta since its last known `event_id`.

**Idempotency:** Each event has a UUID `event_id`. Clients that receive the same event twice (due to reconnect) check `event_id` against a local set of recently processed events and skip duplicates.

**Ordering:** Events from the same sender are ordered by `timestamp` + `event_id`. Events from different senders are ordered by server receipt time. The DM is always the authoritative source for game state; conflicting player events are rejected.

### 6.4 Snapshot and Delta Strategy

**Initial join:** When a player first connects (or reconnects after >30 seconds), the server sends a full **state snapshot** — the current map state, active combat state, and shared entity visibility — as a single `session.snapshot` event.

**Incremental delta:** After the snapshot, only delta events are sent (`entity.updated`, `map.fog_updated`, etc.). This keeps bandwidth usage minimal.

**Snapshot format:**
```json
{
  "event_type": "session.snapshot",
  "payload": {
    "revision": 142,
    "map_state": { "image_url": "...", "fog_data": "...", "pins": [...] },
    "combat_state": { "initiative_order": [...], "active_combatant": "..." },
    "shared_entities": [ /* all shared_full and shared_restricted entities */ ],
    "projection": { "mode": "map", "content_ref": null },
    "audio_state": { "theme": "tavern", "intensity": "calm", "is_playing": true }
  }
}
```

**Delta resync:** If a client has missed events (e.g., brief disconnect), it sends its last known `revision` number. The server replays all events since that revision from the event log. If the revision is too old (>200 events), a fresh snapshot is sent instead.

### 6.5 Event Rate Limiting

To prevent event floods (e.g., continuous fog-of-war drawing):

- **Fog events:** Debounced client-side to emit at most 1 event per 200ms
- **Mind map node drag:** Debounced to 1 event per 100ms; final position sent on mouse-up
- **Server-side rate limit:** Max 30 events/second per DM connection; max 5 events/second per player connection
- **Event queue:** If rate limit is exceeded, events are queued locally and sent as a batch

---

## 7. Asset Management

### 7.1 Flow

```
DM adds image to battle map
    │
    ▼
DM Client → POST /assets/upload → MinIO (stores file)
    │                  │
    │          Returns asset_id + initial signed URL
    │
    ▼
DM Client stores asset_id in campaign data
    │
    ▼
DM Client emits map.image_set event with asset_id (not raw URL)
    │
    ▼
Server relays event to players
    │
    ▼
Player Client receives asset_id
    │
    ▼
Player Client → GET /assets/{id}/url → fresh signed URL
    │
    ▼
Player Client downloads from MinIO URL → caches locally
```

### 7.2 Client-Side Cache

Player clients maintain a content-addressed local cache:

```
~/.dmt/asset_cache/
├── {sha256_of_content}.png
├── {sha256_of_content}.pdf
└── ...
```

Before downloading, the client checks if the asset's SHA-256 hash (included in asset metadata) already exists locally. Cache size is bounded at 500MB by default; LRU eviction removes oldest-accessed files.

### 7.3 Asset Constraints

| Constraint | Limit | Rationale |
|---|---|---|
| Max single asset size | 50 MB | Protects bandwidth and server storage |
| Allowed MIME types | image/*, application/pdf, audio/* | Security — no executables |
| Signed URL TTL | 15 minutes | Balance security with reconnect usability |
| Player cache max size | 500 MB (configurable) | Protects player's disk |

---

## 8. Reconnect and Resilience

### 8.1 Connection State Machine

```
DISCONNECTED
    │ user connects / session starts
    ▼
CONNECTING
    │ socket handshake succeeds
    ▼
CONNECTED
    │ socket closes (network drop)
    ▼
RECONNECTING
    │ max retries exceeded (5 attempts, exponential backoff)
    ▼
ERROR (manual reconnect required)
```

### 8.2 Offline Grace Period

When the DM client loses connection:
1. **0–5 seconds:** Silent; attempting reconnect in background
2. **5–30 seconds:** UI shows "Reconnecting..." banner; DM can continue working offline
3. **30+ seconds:** UI shows "Connection lost" dialog with manual reconnect button
4. All events generated while disconnected are queued in `NetworkBridge._offline_queue`

### 8.3 Reconnect Procedure

Upon successful reconnection:
1. Client authenticates (JWT refresh if needed)
2. Client sends its last known `revision` number
3. Server compares with current revision
   - If gap ≤ 200 events: Server replays delta events to client
   - If gap > 200 events: Server sends fresh snapshot
4. Client processes delta/snapshot events
5. Client flushes its `_offline_queue` to server (events generated while disconnected)

### 8.4 Player Reconnect

Players reconnect identically. Their session slot is held for 60 seconds after disconnect before the server marks them as `disconnected`. If they rejoin within 60 seconds, they receive only the delta; otherwise they receive a fresh snapshot.

---

## 9. Security

### 9.1 Authentication

- **Algorithm:** RS256 (asymmetric) — private key signs, public key verifies
- **Access token TTL:** 15 minutes
- **Refresh token TTL:** 30 days, stored in HTTP-only cookie
- **Revocation:** Refresh tokens are stored in Redis; logout adds them to a blocklist
- **Anonymous players:** Receive a short-lived session token (no account required) tied to the session

### 9.2 Authorization

- Every Socket.io event handler validates the sender's role before processing
- Players cannot emit `dm_*` event types
- Players cannot request entity data beyond their current `visibility` entitlement
- DM session ownership is verified on every sensitive API call (not just at login)

### 9.3 Content Security

- **Zero content leakage:** `private_dm` content is filtered at the server relay layer before any player-bound packet is assembled. The content never enters a player-bound WebSocket frame.
- **Asset access:** Signed URLs expire in 15 minutes. Leaked URLs become invalid quickly.
- **Injection prevention:** All database queries use parameterized statements (via SQLAlchemy ORM). No raw SQL string interpolation.
- **Rate limiting:** Nginx limits connections per IP; application layer limits events per socket.

### 9.4 Audit Logging

Every sensitive action is written to an immutable audit log:
- Session created, joined, ended
- DM role assigned / revoked
- Asset uploaded, deleted
- Auth events (login, logout, token refresh, failed login)

Audit logs are retained for 90 days and are never shown to players.

### 9.5 Self-Hosted Security Considerations

For users running their own server instance:
- HTTPS is mandatory (Nginx + Let's Encrypt recommended)
- JWT secret key must be generated fresh per deployment (`openssl genrsa -out jwt_private.pem 2048`)
- MinIO must not be publicly accessible without signed URLs
- Default admin credentials must be changed at first run (enforced by setup wizard)
- Recommend placing server behind a firewall with only ports 80/443 exposed

---

## 10. Performance Targets

| Metric | Target | Measurement Method |
|---|---|---|
| P95 event end-to-end latency | < 120ms | Localtunnel DM→Server→Player round-trip timing |
| P50 event latency | < 50ms | Same |
| 5MB map image load time (player) | < 3 seconds | Timed from `map.image_set` event to player render complete |
| Reconnect + delta resync | < 5 seconds | Timed from socket reconnect to UI restored |
| Session snapshot delivery | < 2 seconds | Timed from `session.snapshot` emit to client process complete |
| Server-side dice roll response | < 100ms | Timed from player request to broadcast received |
| Maximum concurrent sessions | 50 (single server) | Load test benchmark |
| Maximum participants per session | 8 (DM + 7 players) | Product constraint, not technical limit |

### 10.1 Performance Budget Allocation

For a 5MB map load (target < 3s):
- Upload to MinIO: < 1s (DM to server)
- Event relay: < 50ms
- Player HTTP download from MinIO: < 1.5s (assumes 30 Mbps player connection)
- Player render: < 500ms
- **Total budget:** 3050ms → target 3s

---

## 11. Online-Only Features

These features are only available when connected to an online session.

### 11.1 Server-Side Dice Roller

**Rationale:** Client-side dice rolls cannot be trusted in competitive or high-stakes sessions. Server generation ensures all players see the same result simultaneously and no client can pre-compute or manipulate rolls.

**Flow:**
1. Player/DM requests roll: `{dice: "2d6+3", purpose: "Attack roll"}`
2. Server generates each die using `secrets.randbelow(n)` (CSPRNG)
3. Server broadcasts roll result to all session participants: `{roller: "DM", dice: "2d6+3", rolls: [4, 5], modifier: 3, total: 12, purpose: "Attack roll"}`
4. Roll is appended to event log

**Supported notation:** `NdX`, `NdX+M`, `NdX-M`, `NdX*M`, drop-lowest `NdXdL`, advantage `2d20kh1`, disadvantage `2d20kl1`

### 11.2 Persistent Event Log

The event log records every significant event in a session:

- Combat events: HP changes, conditions, turn advances, death saves, deaths
- DM actions: Fog reveals, entity cards pushed, map changes
- Dice rolls: All server-side rolls with context
- Player notes: Freeform notes submitted during session
- System events: Joins, disconnects, reconnects

The log is stored in PostgreSQL and never deleted (archived when session ends). DMs can access the full log after the session. Players receive a filtered log (no `private_dm` events).

**Export formats:** Plain text, JSON, Markdown (for session recap posts)

### 11.3 Restricted Entity Views

When the DM shares an NPC with `visibility: shared_restricted`:

- Players see a player-facing card with only DM-approved fields
- Hidden fields are replaced with narrative descriptions:
  - HP → "Bloodied" / "Wounded" / "Healthy" / "Critical"
  - Saving throws → not shown
  - Hidden traits → replaced with "???"
- DM can toggle field visibility in real-time during the session (changes broadcast immediately)

### 11.4 Audio State Broadcast

When the DM changes audio (theme, intensity, soundpad trigger), the current audio state is broadcast to player clients. Player clients with the desktop application can mirror the DM's audio (playing the same theme at the same intensity) — useful for groups where multiple players have speakers.

The audio state event:
```json
{
  "event_type": "audio.state_changed",
  "payload": {
    "theme": "dungeon_ambience",
    "intensity": "tense",
    "master_volume": 0.7,
    "is_playing": true,
    "current_track": "dungeon_tense_02"
  }
}
```

---

## 12. Deployment Architecture

### 12.1 Docker Compose (Development)

```yaml
# docker-compose.dev.yml (simplified)
services:
  api:
    build: ./server
    ports: ["8000:8000"]
    environment:
      DATABASE_URL: postgresql://dm:dm@db/dmtool
      REDIS_URL: redis://redis:6379
      MINIO_ENDPOINT: minio:9000
    depends_on: [db, redis, minio]

  db:
    image: postgres:16
    environment: {POSTGRES_DB: dmtool, POSTGRES_USER: dm, POSTGRES_PASSWORD: dm}
    volumes: [postgres_data:/var/lib/postgresql/data]

  redis:
    image: redis:7-alpine

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    ports: ["9000:9000", "9001:9001"]
    volumes: [minio_data:/data]
```

### 12.2 Production Docker Compose

```yaml
# docker-compose.prod.yml additions
services:
  nginx:
    image: nginx:alpine
    ports: ["80:80", "443:443"]
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf
      - ./certs:/etc/nginx/certs  # Let's Encrypt or self-signed

  prometheus:
    image: prom/prometheus
    volumes: [./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml]

  loki:
    image: grafana/loki
    volumes: [loki_data:/loki]

  grafana:
    image: grafana/grafana
    ports: ["3000:3000"]
    depends_on: [prometheus, loki]
```

### 12.3 Nginx Configuration

Nginx handles:
- TLS termination (HTTPS → HTTP to backend)
- WebSocket upgrade headers for Socket.io
- Static file serving (if any)
- Rate limiting per IP (`limit_req_zone`)
- Request size limits (protect against large file uploads bypassing the API)

### 12.4 Observability

**Metrics (Prometheus):**
- Active session count
- Events per second (by type)
- WebSocket connection count
- API endpoint latency (P50, P95, P99)
- Database query latency
- MinIO request latency

**Logs (Loki):**
- All API requests (level: info)
- All WebSocket events (level: debug in dev, warning in prod)
- All errors and exceptions (level: error)
- Audit log events (separate log stream, never rotated)

**Alerts:**
- Session event latency P95 > 200ms for > 60 seconds
- Error rate > 1% of requests for > 60 seconds
- Database connection pool exhausted
- MinIO storage > 80% capacity

---

## 13. Phase Roadmap

### Phase 1 — Auth and Session Gateway (Sprints 3–4, Apr 6 – May 1)

**Deliverables:**
- FastAPI project structure with python-socketio
- JWT authentication (register, login, refresh, logout)
- Session create/join with 6-character codes
- PostgreSQL schema (users, sessions, participants, event_log)
- Basic Socket.io relay (no filtering yet)
- Asset upload/download via MinIO signed URLs
- Map state sync (image set, fog update)
- Player Window content push (images, stat blocks)

**Success Gate:** DM can start a session; a player can join; the DM can reveal fog and push an entity card to the player's screen.

---

### Phase 2 — Full Sync (Sprints 5–6, May 4 – May 29)

**Deliverables:**
- Mind map node sync (create, update, delete — last-write-wins)
- Reconnect state machine (client side)
- Delta resync from server event log
- Full snapshot on initial join or stale reconnect
- Audio state broadcast and mirror
- Sync state machine: pending → applying → synced
- Performance benchmarking and optimization

**Success Gate:** A player can disconnect and reconnect mid-session and see the full current state within 5 seconds. Audio mirrors correctly across clients.

---

### Phase 3 — Gameplay Features (Sprint 7, Jun 1–12)

**Deliverables:**
- Server-side dice roller (broadcast to all participants)
- Event log persistence and player-filtered query
- Restricted entity view with field-level redaction
- Real-time field visibility toggle by DM

**Success Gate:** Players see server-rolled dice simultaneously. Event log is viewable after session end. DM can hide/show individual entity fields live.

---

### Phase 4 — Deployment and Beta (Sprint 8, Jun 15–26)

**Deliverables:**
- Production Docker Compose (Nginx, Prometheus, Loki, MinIO, PostgreSQL)
- Let's Encrypt / self-signed TLS setup guide
- Backup and restore procedures for PostgreSQL and MinIO
- Grafana dashboards for all key metrics
- Beta launch: closed group of 10–20 DMs testing real sessions
- Bug bash and hotfix cycle

**Success Gate:** Three consecutive closed beta sessions run without P1 bugs. All performance targets met under realistic load (3–6 players, 1 DM).

---

## 14. Success Criteria and KPIs

### Technical KPIs

| KPI | Target | Measured At |
|---|---|---|
| P95 event latency (DM→Player) | < 120ms | Sprint 6 benchmark |
| P50 event latency | < 50ms | Sprint 6 benchmark |
| 5MB map load (player) | < 3 seconds | Sprint 4 acceptance test |
| Reconnect + resync | < 5 seconds | Sprint 5 acceptance test |
| Server-side dice response | < 100ms | Sprint 7 acceptance test |
| Zero content leakage | 0 violations | Security audit before beta |
| Server test coverage | ≥ 80% | Sprint 8 CI check |
| Uptime (hosted service) | 99.5% monthly | Production monitoring |

### Product KPIs (Beta Phase)

| KPI | Target | Notes |
|---|---|---|
| Sessions per beta user per week | ≥ 2 | Indicates real use, not just testing |
| Player join friction (time to connected) | < 60 seconds | From receiving code to seeing DM's screen |
| DM satisfaction score | ≥ 4.0 / 5.0 | Post-session survey |
| P1 bug rate | 0 per session | Crash or data loss |
| Beta DMs converting to paid (Phase 2 monetization) | ≥ 20% | Tracked post-beta |

### Definition of Online Beta Ready

The application is ready for closed beta when:
- [ ] All Phase 1–4 sprint deliverables are merged and tested
- [ ] All technical KPIs met in a load test (simulated 6-player session)
- [ ] Security review completed (at minimum: permission model, content leakage audit)
- [ ] Backup/restore procedure documented and tested
- [ ] At least 2 full end-to-end test sessions run internally
- [ ] Monitoring dashboards operational
- [ ] Beta onboarding guide written (how to install, configure, and start a session)
