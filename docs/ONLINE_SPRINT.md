# Online Sprint Plan — Dungeon Master Tool

> **Document Status:** Active
> **Last Updated:** 2026-03-22
> **Supersedes:** Portions of `docs/archive/SPRINT_MAP.md` (Sprints 3–8)
> **Companion Document:** `docs/ONLINE.md` (architecture reference)
> **Scope:** Sprints 3–8 — the complete online implementation from auth gateway to beta launch

---

## Table of Contents

1. [Overview and Timeline](#1-overview-and-timeline)
2. [Sprint 3 — Auth and Session Gateway (Apr 6–17)](#2-sprint-3--auth-and-session-gateway-apr-6-17)
3. [Sprint 4 — Asset Proxy and Map Sync (Apr 20 – May 1)](#3-sprint-4--asset-proxy-and-map-sync-apr-20--may-1)
4. [Sprint 5 — Mind Map Sync and Reconnect (May 4–15)](#4-sprint-5--mind-map-sync-and-reconnect-may-4-15)
5. [Sprint 6 — Audio Sync and Performance (May 18–29)](#5-sprint-6--audio-sync-and-performance-may-18-29)
6. [Sprint 7 — Gameplay Features (Jun 1–12)](#6-sprint-7--gameplay-features-jun-1-12)
7. [Sprint 8 — Deployment and Beta (Jun 15–26)](#7-sprint-8--deployment-and-beta-jun-15-26)
8. [Cross-Sprint Dependencies](#8-cross-sprint-dependencies)
9. [Definition of Done](#9-definition-of-done)

---

## 1. Overview and Timeline

### Sprint Calendar

| Sprint | Dates | Phase | Focus |
|---|---|---|---|
| Sprint 3 | Apr 6–17, 2026 | Phase 1 | Auth/Session gateway, PostgreSQL schema |
| Sprint 4 | Apr 20–May 1, 2026 | Phase 1 | Asset proxy, Map sync, Player Window content |
| Sprint 5 | May 4–15, 2026 | Phase 2 | Mind map sync, reconnect state machine |
| Sprint 6 | May 18–29, 2026 | Phase 2 | Audio sync, performance benchmarking |
| Sprint 7 | Jun 1–12, 2026 | Phase 3 | Dice roller, event log, restricted views |
| Sprint 8 | Jun 15–26, 2026 | Phase 4 | Docker Compose, TLS, backup, beta launch |

### Entry Criteria for Sprint 3

Sprint 3 must not begin until the **Sprint 2 Stability Gate** is fully satisfied (see `docs/PRE_ONLINE_SPRINT.md §5 Appendix C`). Specifically:

- [ ] EventManager local dispatch fully operational (all 20 event types wiring)
- [ ] NetworkBridge skeleton exists with connection state machine
- [ ] Event schema v1 Pydantic models validated
- [ ] Single PlayerWindow merged
- [ ] `core/` test coverage ≥ 60%
- [ ] No known P1 bugs

---

## 2. Sprint 3 — Auth and Session Gateway (Apr 6–17)

### Sprint Goal

Establish the complete server-side foundation: FastAPI project, database schema, authentication system, and session create/join flow. By the end of Sprint 3, a DM can start a session on the server and a player can join using a 6-character code — even if they can only see a connection status indicator.

### Files to Create

```
server/
├── __init__.py
├── main.py                          # FastAPI app factory + lifespan
├── config.py                        # Settings (pydantic-settings)
├── database.py                      # SQLAlchemy engine + session factory
├── models/
│   ├── user.py                      # User ORM model
│   ├── session.py                   # Session + SessionParticipant ORM models
│   └── event_log.py                 # EventLog ORM model
├── schemas/
│   ├── auth.py                      # Pydantic request/response schemas
│   └── session.py
├── routers/
│   ├── auth.py                      # /auth/* endpoints
│   └── sessions.py                  # /sessions/* endpoints
├── socket/
│   ├── manager.py                   # Socket.io server instance + namespace setup
│   └── session_namespace.py        # /session namespace event handlers
├── services/
│   ├── auth_service.py              # JWT generation, bcrypt, token refresh
│   └── session_service.py          # Join code generation, session lifecycle
├── middleware/
│   └── auth_middleware.py           # JWT verification for HTTP + WS
└── migrations/
    ├── env.py                       # Alembic environment
    └── versions/
        └── 001_initial_schema.py    # First migration
```

### Day-by-Day Schedule

#### Week 1 (Apr 6–10)

---

**Monday, Apr 6 — Project scaffold**

| # | Task | Files | Estimate |
|---|---|---|---|
| 1 | Initialize `server/` directory with FastAPI + python-socketio | `server/main.py`, `server/config.py` | 2h |
| 2 | Set up Alembic + PostgreSQL connection | `server/database.py`, `server/migrations/env.py` | 2h |
| 3 | Write User and Session ORM models | `server/models/user.py`, `server/models/session.py` | 2h |
| 4 | Run initial migration: `alembic upgrade head` | `server/migrations/versions/001_initial_schema.py` | 1h |

**Acceptance:** `uvicorn server.main:app` starts without errors. `/docs` (Swagger UI) is accessible. Database tables are created by migration.

---

**Tuesday, Apr 7 — Auth endpoints**

| # | Task | Files | Estimate |
|---|---|---|---|
| 5 | Implement `POST /auth/register` (bcrypt password, return user ID) | `server/routers/auth.py`, `server/services/auth_service.py` | 2h |
| 6 | Implement `POST /auth/login` (verify password, issue JWT + refresh token) | `server/routers/auth.py`, `server/services/auth_service.py` | 2h |
| 7 | Implement `POST /auth/refresh` (exchange refresh token, Redis blocklist check) | `server/routers/auth.py` | 2h |
| 8 | Implement `POST /auth/logout` (add refresh token to Redis blocklist) | `server/routers/auth.py` | 1h |

**Acceptance:** Full auth flow tested with `pytest`: register → login → get JWT → refresh → logout → verify refresh is blocked.

---

**Wednesday, Apr 8 — Session endpoints**

| # | Task | Files | Estimate |
|---|---|---|---|
| 9 | Implement `POST /sessions/create` (DM creates session, generates join code) | `server/routers/sessions.py`, `server/services/session_service.py` | 3h |
| 10 | Implement `POST /sessions/join` (player joins with code + display name, returns session token) | `server/routers/sessions.py` | 2h |
| 11 | Implement `POST /sessions/{id}/end` (DM ends session, all participants notified) | `server/routers/sessions.py` | 2h |

**Acceptance:** DM creates a session; session appears in DB with `status=waiting`. Player joins using the code; participant record created. DM ends session; status changes to `ended`.

---

**Thursday, Apr 9 — Socket.io server namespace**

| # | Task | Files | Estimate |
|---|---|---|---|
| 12 | Set up python-socketio ASGI integration with FastAPI | `server/main.py`, `server/socket/manager.py` | 2h |
| 13 | Implement `/session` namespace: `connect` handler (validate session token) | `server/socket/session_namespace.py` | 2h |
| 14 | Implement `disconnect` handler (mark participant offline; hold slot 60s) | `server/socket/session_namespace.py` | 1h |
| 15 | Implement basic event relay: DM emits → server validates role → broadcast to room | `server/socket/session_namespace.py` | 2h |

**Acceptance:** DM connects via Socket.io; player connects using session token; DM emits a test event; player receives it. Role-based filtering blocks players from emitting DM events.

---

**Friday, Apr 10 — DM client integration (NetworkBridge activation)**

| # | Task | Files | Estimate |
|---|---|---|---|
| 16 | Activate NetworkBridge: connect to real server on session start | `core/network/bridge.py` | 3h |
| 17 | Handle server events received by DM client (session.player_joined, etc.) | `core/network/bridge.py` | 2h |
| 18 | Update GM Screen Control Panel to show connected players | `ui/components/gm_control_panel.py` | 2h |

**Acceptance:** DM starts a session; NetworkBridge connects to server; player joins; DM sees player name appear in control panel.

---

#### Week 2 (Apr 13–17)

---

**Monday, Apr 13 — Player client integration**

| # | Task | Files | Estimate |
|---|---|---|---|
| 19 | Create player join flow: join code input dialog | `ui/dialogs/join_session_dialog.py` | 2h |
| 20 | Player client socket connection + session token handling | `core/network/player_bridge.py` | 3h |
| 21 | Player client receives session.snapshot; parses and applies to PlayerWindow | `ui/windows/player_window.py`, `core/network/player_bridge.py` | 3h |

**Acceptance:** Player opens join dialog, enters code, is connected. PlayerWindow shows the current DM state (even if just a blank screen).

---

**Tuesday, Apr 14 — Auth edge cases and security**

| # | Task | Files | Estimate |
|---|---|---|---|
| 22 | Validate join code format on server (reject invalid characters, expired codes) | `server/services/session_service.py` | 2h |
| 23 | Rate limit auth endpoints (5 attempts/minute per IP via Nginx or middleware) | `server/middleware/` | 2h |
| 24 | Anonymous player flow: no account required to join | `server/routers/sessions.py` | 2h |

---

**Wednesday–Thursday, Apr 15–16 — Tests and error handling**

| # | Task | Files | Estimate |
|---|---|---|---|
| 25 | Write server unit tests: auth service | `server/tests/test_auth.py` | 3h |
| 26 | Write server unit tests: session service | `server/tests/test_sessions.py` | 3h |
| 27 | Write server integration tests: full join flow | `server/tests/test_integration_join.py` | 3h |
| 28 | Error handling: graceful responses for invalid codes, expired tokens | All routers | 2h |

---

**Friday, Apr 17 — Sprint 3 review**

| # | Task | Files | Estimate |
|---|---|---|---|
| 29 | Sprint 3 acceptance criteria verification | All Sprint 3 files | 2h |
| 30 | Retrospective notes | `docs/` | 1h |
| 31 | Update `CHANGELOG.md` | `CHANGELOG.md` | 30m |

### Sprint 3 Acceptance Criteria

| Deliverable | Test |
|---|---|
| `POST /auth/register` + `/login` | Pytest: register→login→JWT valid |
| `POST /auth/refresh` + `/logout` | Pytest: refresh works; logout blocks refresh |
| `POST /sessions/create` | Pytest: session created, 6-char code returned |
| `POST /sessions/join` | Pytest: join with valid code → participant created |
| Socket.io event relay | Integration test: DM emits, player receives |
| Role enforcement | Player emitting DM event → rejected |
| DM client connects to server | Manual: start session → GM panel shows "Connected" |
| Player client joins | Manual: player joins → appears in DM's panel |

---

## 3. Sprint 4 — Asset Proxy and Map Sync (Apr 20 – May 1)

### Sprint Goal

Players can see the battle map (with fog of war), receive pushed entity cards, and view images sent by the DM. Asset uploads go through MinIO. This sprint makes the application actually useful for an online session — not just connected.

### Files to Create

```
server/
├── routers/
│   └── assets.py                    # /assets/* endpoints
├── services/
│   └── asset_service.py             # MinIO interaction, signed URL generation
└── storage/
    └── minio_client.py              # MinIO client wrapper
```

### Day-by-Day Schedule

#### Week 1 (Apr 20–24) — Asset Infrastructure

---

**Monday, Apr 20 — MinIO integration**

| # | Task | Files | Estimate |
|---|---|---|---|
| 1 | Set up MinIO client wrapper | `server/storage/minio_client.py` | 2h |
| 2 | Implement `POST /assets/upload` — accepts multipart file, stores in MinIO | `server/routers/assets.py`, `server/services/asset_service.py` | 3h |
| 3 | Implement `GET /assets/{id}/url` — return fresh 15-min signed URL | `server/routers/assets.py` | 2h |

**Acceptance:** DM uploads a PNG; server returns `asset_id`. Requesting signed URL returns a valid MinIO presigned URL that downloads the image.

---

**Tuesday, Apr 21 — DM client asset upload integration**

| # | Task | Files | Estimate |
|---|---|---|---|
| 4 | DM client: upload local asset to server on session start (or on first use) | `core/network/asset_uploader.py` | 3h |
| 5 | DM client: store `asset_id` mapping in session data | `core/data_manager.py` | 2h |
| 6 | DM client: emit `map.image_set` with `asset_id` instead of local path | `core/data_manager.py`, `core/network/bridge.py` | 2h |

---

**Wednesday, Apr 22 — Player client asset download**

| # | Task | Files | Estimate |
|---|---|---|---|
| 7 | Player client: receive `map.image_set` event with `asset_id` | `core/network/player_bridge.py` | 1h |
| 8 | Player client: request signed URL from server | `core/network/player_bridge.py` | 1h |
| 9 | Player client: download asset from MinIO to local cache | `core/cache/asset_cache.py` | 3h |
| 10 | Player Window: display downloaded map image | `ui/windows/player_window.py` | 2h |

**Acceptance:** DM loads a battle map; player sees the same image within 3 seconds (local network). Image is cached — second load is instant.

---

**Thursday, Apr 23 — Fog of war sync**

| # | Task | Files | Estimate |
|---|---|---|---|
| 11 | Serialize fog mask for transmission (base64 or compressed binary) | `core/network/bridge.py` | 2h |
| 12 | Emit `map.fog_updated` event when DM reveals/hides fog | `core/data_manager.py`, `core/network/bridge.py` | 2h |
| 13 | Player client: receive and apply fog state to PlayerWindow map | `ui/windows/player_window.py`, `core/network/player_bridge.py` | 3h |
| 14 | Debounce fog events (max 1 per 200ms during continuous fog editing) | `core/network/bridge.py` | 1h |

**Acceptance:** DM reveals fog area; player sees the reveal within 200ms (local network). Fog state is included in `session.snapshot` on reconnect.

---

**Friday, Apr 24 — Map pin sync**

| # | Task | Files | Estimate |
|---|---|---|---|
| 15 | Emit `map.pin_added` / `map.pin_removed` when DM adds/removes pins | `core/data_manager.py` | 2h |
| 16 | Player client: receive and render map pins | `ui/windows/player_window.py` | 2h |
| 17 | Visibility: only pins with `visibility: shared_full` transmitted | `server/socket/session_namespace.py` | 2h |

---

#### Week 2 (Apr 27–May 1) — Player Window Content Push

---

**Monday, Apr 27 — Entity card push**

| # | Task | Files | Estimate |
|---|---|---|---|
| 18 | DM sends entity card to PlayerWindow via `projection.content_set` event | `ui/components/gm_control_panel.py`, `core/network/bridge.py` | 2h |
| 19 | Server: apply content visibility filtering (Section 5 of ONLINE.md) | `server/socket/session_namespace.py` | 3h |
| 20 | Player Window: render received entity card (read-only NPC sheet) | `ui/windows/player_window.py` | 3h |

**Acceptance:** DM pushes a "shared_full" NPC card; player sees it. DM pushes a "private_dm" card; player sees nothing (server suppresses). DM pushes "shared_restricted" card; player sees redacted version.

---

**Tuesday, Apr 28 — Image and PDF push to PlayerWindow**

| # | Task | Files | Estimate |
|---|---|---|---|
| 21 | DM sends image to PlayerWindow (asset_id → signed URL → player displays) | `ui/components/gm_control_panel.py`, `ui/windows/player_window.py` | 2h |
| 22 | DM sends PDF page to PlayerWindow (asset_id + page number) | `ui/components/gm_control_panel.py`, `ui/windows/player_window.py` | 2h |
| 23 | PlayerWindow displays received image full-screen (fit-width) | `ui/windows/player_window.py` | 2h |

---

**Wednesday–Thursday, Apr 29–30 — Tests**

| # | Task | Files | Estimate |
|---|---|---|---|
| 24 | Server tests: asset upload, signed URL generation | `server/tests/test_assets.py` | 2h |
| 25 | Server tests: content visibility filtering | `server/tests/test_visibility.py` | 3h |
| 26 | Client tests: asset cache (cache hit, eviction) | `tests/test_core/test_asset_cache.py` | 2h |
| 27 | Integration test: full map sync flow (DM upload → player download) | `server/tests/test_integration_map.py` | 3h |

---

**Friday, May 1 — Sprint 4 review**

| # | Task | Files | Estimate |
|---|---|---|---|
| 28 | Sprint 4 acceptance criteria verification | All Sprint 4 files | 2h |
| 29 | Phase 1 milestone review | — | 1h |

### Sprint 4 Acceptance Criteria

| Deliverable | Test |
|---|---|
| Asset upload → MinIO | DM uploads image; signed URL returns downloadable file |
| Map image sync | Player sees DM's map image within 3s (LAN) |
| Fog of war sync | Fog reveal appears on player within 200ms |
| Entity card push (full) | Player sees full card when visibility=shared_full |
| Entity card push (private) | Player sees nothing when visibility=private_dm |
| Entity card push (restricted) | Player sees redacted card; HP shown as status label |
| Image push to PlayerWindow | Player sees full-screen image within 1s |

---

## 4. Sprint 5 — Mind Map Sync and Reconnect (May 4–15)

### Sprint Goal

Mind map changes sync in real time. Players who disconnect (network hiccup, tab switch) and reconnect receive the full current state quickly without manual intervention. The reconnect path is hardened and tested.

### Day-by-Day Schedule

#### Week 1 (May 4–8) — Mind Map Sync

---

**Monday, May 4 — Mind map event emission**

| # | Task | Files | Estimate |
|---|---|---|---|
| 1 | Wire mind map mutations to EventManager: node CRUD + edge CRUD | `core/data_manager.py`, `ui/tabs/mind_map_tab.py` | 3h |
| 2 | Assign `sync_id` (UUID) to each node on creation; persist in campaign data | `core/data_manager.py`, `core/models.py` | 2h |
| 3 | Assign `owner_id` (DM user ID) and `visibility` to each node | `core/data_manager.py`, `core/models.py` | 1h |

---

**Tuesday, May 5 — Server-side mind map relay**

| # | Task | Files | Estimate |
|---|---|---|---|
| 4 | Server: relay mind map events to players (applying visibility filter) | `server/socket/session_namespace.py` | 2h |
| 5 | Conflict resolution: last-write-wins on `node_updated` (compare timestamps) | `server/socket/session_namespace.py` | 2h |
| 6 | Session snapshot: include shared mind map state | `server/services/session_service.py` | 3h |

---

**Wednesday, May 6 — Player client mind map rendering**

| # | Task | Files | Estimate |
|---|---|---|---|
| 7 | Player client: receive and apply mind map node events | `core/network/player_bridge.py` | 2h |
| 8 | Player Window: read-only mind map view (DM can push specific map to player) | `ui/windows/player_window.py` | 4h |

**Acceptance:** DM creates a mind map node; connected player sees it appear within 200ms. DM moves a node; player sees the update.

---

**Thursday–Friday, May 7–8 — Mind map sync tests**

| # | Task | Files | Estimate |
|---|---|---|---|
| 9 | Unit tests: mind map event emission | `tests/test_core/test_mindmap_events.py` | 3h |
| 10 | Server tests: mind map visibility filter | `server/tests/test_mindmap.py` | 2h |
| 11 | Integration test: node create → player receives | `server/tests/test_integration_mindmap.py` | 3h |

---

#### Week 2 (May 11–15) — Reconnect State Machine

---

**Monday, May 11 — Client reconnect logic**

| # | Task | Files | Estimate |
|---|---|---|---|
| 12 | Implement reconnect state machine (DISCONNECTED → CONNECTING → CONNECTED → RECONNECTING → ERROR) | `core/network/bridge.py` | 3h |
| 13 | Exponential backoff: 1s, 2s, 4s, 8s, 16s (max 5 attempts) | `core/network/bridge.py` | 1h |
| 14 | Offline queue: buffer events generated while disconnected | `core/network/bridge.py` | 2h |
| 15 | UI reconnect banner: show status after 5 seconds disconnected | `ui/components/connection_status.py` | 1h |

---

**Tuesday, May 12 — Server-side delta resync**

| # | Task | Files | Estimate |
|---|---|---|---|
| 16 | Client sends `last_revision` on reconnect | `core/network/bridge.py` | 1h |
| 17 | Server: fetch events since `last_revision` from event_log table | `server/socket/session_namespace.py`, `server/services/session_service.py` | 3h |
| 18 | Server: if gap > 200 events, send full snapshot instead | `server/services/session_service.py` | 2h |

---

**Wednesday, May 13 — Offline queue flush + idempotency**

| # | Task | Files | Estimate |
|---|---|---|---|
| 19 | Client flushes offline queue after successful reconnect | `core/network/bridge.py` | 2h |
| 20 | Idempotency: client tracks recent event_ids (dedup set, last 500 IDs) | `core/network/bridge.py` | 2h |
| 21 | Player reconnect: server holds slot for 60 seconds | `server/socket/session_namespace.py` | 2h |

---

**Thursday–Friday, May 14–15 — Reconnect tests**

| # | Task | Files | Estimate |
|---|---|---|---|
| 22 | Unit test: reconnect state machine transitions | `tests/test_core/test_network_bridge.py` | 3h |
| 23 | Integration test: disconnect → reconnect → delta received correctly | `server/tests/test_integration_reconnect.py` | 4h |
| 24 | Integration test: disconnect > 200 events → snapshot received | `server/tests/test_integration_reconnect.py` | 2h |

### Sprint 5 Acceptance Criteria

| Deliverable | Test |
|---|---|
| Mind map node sync | Player sees new node within 200ms |
| Mind map visibility filter | Private nodes not transmitted to players |
| Reconnect < 5 seconds | Integration test: disconnect 10s → reconnect → state restored |
| Delta resync | Gap of 50 events replayed correctly after reconnect |
| Snapshot resync | Gap of 300 events → full snapshot received correctly |
| Offline queue flush | Events emitted while disconnected are sent on reconnect |

---

## 5. Sprint 6 — Audio Sync and Performance (May 18–29)

### Sprint Goal

Audio state is mirrored across clients. All Phase 2 features are benchmarked against performance targets. Any identified bottlenecks are resolved before Phase 3 begins.

### Day-by-Day Schedule

#### Week 1 (May 18–22) — Audio Sync

---

**Monday, May 18 — Audio state emission**

| # | Task | Files | Estimate |
|---|---|---|---|
| 1 | Wire audio state changes to EventManager: theme, intensity, volume, track trigger | `core/audio/engine.py`, `core/data_manager.py` | 3h |
| 2 | Serialize `MusicBrain` state to JSON-serializable dict | `core/audio/engine.py` | 2h |
| 3 | Emit `audio.state_changed` and `audio.track_triggered` events | `core/data_manager.py` | 1h |

---

**Tuesday, May 19 — Server audio relay**

| # | Task | Files | Estimate |
|---|---|---|---|
| 4 | Server: relay audio events to player clients | `server/socket/session_namespace.py` | 2h |
| 5 | Audio state included in `session.snapshot` | `server/services/session_service.py` | 2h |
| 6 | Rate limit audio events (max 5/second; debounce volume slider) | `core/network/bridge.py` | 2h |

---

**Wednesday, May 20 — Player audio mirroring (optional feature)**

| # | Task | Files | Estimate |
|---|---|---|---|
| 7 | Player desktop client: subscribe to audio events | `core/network/player_bridge.py` | 1h |
| 8 | Player client: apply received audio state to local MusicBrain | `core/audio/engine.py` | 3h |
| 9 | Player settings: toggle audio mirroring on/off | `ui/dialogs/preferences_dialog.py` | 1h |

**Acceptance:** DM switches theme to "Tavern"; player desktop client (with mirroring enabled) plays the same theme within 500ms.

---

**Thursday, May 21 — Sync state machine**

| # | Task | Files | Estimate |
|---|---|---|---|
| 10 | Implement sync state machine: `pending → applying → synced → error` | `core/network/bridge.py` | 3h |
| 11 | UI sync indicator: per-event-type status (last synced timestamp) | `ui/components/connection_status.py` | 2h |

---

**Friday, May 22 — Audio tests**

| # | Task | Files | Estimate |
|---|---|---|---|
| 12 | Unit test: MusicBrain state serialization round-trip | `tests/test_core/test_audio_sync.py` | 3h |
| 13 | Integration test: audio state change → player receives within 500ms | `server/tests/test_integration_audio.py` | 2h |

---

#### Week 2 (May 25–29) — Performance Benchmarking

---

**Monday, May 25 — Benchmark setup**

| # | Task | Files | Estimate |
|---|---|---|---|
| 14 | Create performance test harness | `server/tests/perf/benchmark.py` | 3h |
| 15 | Instrument server: measure event latency end-to-end | `server/socket/session_namespace.py` | 2h |
| 16 | Instrument client: measure event → UI update time | `core/network/bridge.py` | 2h |

---

**Tuesday, May 26 — Run benchmarks**

| # | Task | Files | Estimate |
|---|---|---|---|
| 17 | Benchmark: P50/P95 event latency (1 DM + 6 players, 30 events/s) | `server/tests/perf/` | 4h |
| 18 | Benchmark: 5MB map load time (DM upload → player render) | `server/tests/perf/` | 2h |
| 19 | Benchmark: reconnect + delta resync time | `server/tests/perf/` | 1h |

**Target:** All metrics meet targets in `ONLINE.md §10`.

---

**Wednesday–Thursday, May 27–28 — Performance fixes**

Address any benchmarks that miss targets:

| Likely Fix Areas | Approach |
|---|---|
| Event latency > 120ms P95 | Profile server relay; check DB query in event log write path; add Redis buffering |
| Map load > 3s | Check MinIO signed URL generation time; parallelize player download + decode |
| Reconnect > 5s | Profile delta replay query; add index on `event_log(session_id, revision)` |
| Memory leak in long sessions | Profile WebSocket connection memory; check asyncio task cleanup |

---

**Friday, May 29 — Phase 2 milestone review**

| # | Task | Files | Estimate |
|---|---|---|---|
| 20 | All benchmarks rerun after fixes | `server/tests/perf/` | 2h |
| 21 | Performance report document | `docs/` | 2h |
| 22 | Sprint 6 retrospective | — | 1h |

### Sprint 6 Acceptance Criteria

| Deliverable | Test |
|---|---|
| Audio theme sync | DM changes theme → player receives within 500ms |
| Audio state in snapshot | Reconnecting player resumes correct audio state |
| P95 event latency < 120ms | Benchmark result |
| 5MB map load < 3s | Benchmark result |
| Reconnect + resync < 5s | Benchmark result |

---

## 6. Sprint 7 — Gameplay Features (Jun 1–12)

### Sprint Goal

The session is now genuinely useful for tabletop play: players can roll dice via the server, view the event log, and see appropriate (redacted) versions of entities. The DM can control field visibility live during the session.

### Day-by-Day Schedule

#### Week 1 (Jun 1–5) — Server-Side Dice Roller

---

**Monday, Jun 1 — Dice server implementation**

| # | Task | Files | Estimate |
|---|---|---|---|
| 1 | Implement dice notation parser: `NdX`, `NdX+M`, advantage, disadvantage, drop-lowest | `server/services/dice_service.py` | 4h |
| 2 | Use `secrets.randbelow(n)` for each die (CSPRNG) | `server/services/dice_service.py` | 1h |
| 3 | Socket.io event: `dice.roll_request` → server processes → `dice.roll_result` broadcast | `server/socket/session_namespace.py` | 2h |

---

**Tuesday, Jun 2 — Dice client integration**

| # | Task | Files | Estimate |
|---|---|---|---|
| 4 | DM client: dice roll request via EventManager | `core/network/bridge.py` | 2h |
| 5 | Player client: dice roll UI (input field + roll button) | `ui/components/dice_panel.py` | 3h |
| 6 | All clients: display roll result overlay/notification | `ui/components/dice_result.py` | 2h |

**Acceptance:** Player requests `2d6+3`; all clients (DM + all players) see the result simultaneously within 200ms. Roll result is appended to event log.

---

**Wednesday, Jun 3 — Persistent event log**

| # | Task | Files | Estimate |
|---|---|---|---|
| 7 | Confirm all events are persisting to `event_log` table | `server/socket/session_namespace.py` | 1h |
| 8 | Implement `GET /sessions/{id}/log` — paginated query, DM gets full log | `server/routers/sessions.py` | 2h |
| 9 | Player log: filter out `private_dm` events | `server/routers/sessions.py` | 2h |
| 10 | DM client: event log panel shows all events from current session | `ui/widgets/event_log_panel.py` | 3h |

---

**Thursday, Jun 4 — Event log UI + export**

| # | Task | Files | Estimate |
|---|---|---|---|
| 11 | Event log panel: filter by event type or combatant name | `ui/widgets/event_log_panel.py` | 2h |
| 12 | Export log as plain text and JSON | `ui/widgets/event_log_panel.py`, `core/export/log_exporter.py` | 3h |

---

**Friday, Jun 5 — Dice tests**

| # | Task | Files | Estimate |
|---|---|---|---|
| 13 | Unit tests: dice parser (standard notation + edge cases) | `server/tests/test_dice.py` | 3h |
| 14 | Integration test: roll request → result broadcast | `server/tests/test_integration_dice.py` | 2h |

---

#### Week 2 (Jun 8–12) — Restricted Entity Views

---

**Monday, Jun 8 — Field-level redaction engine**

| # | Task | Files | Estimate |
|---|---|---|---|
| 15 | Implement `redact_hidden_fields(entity, payload)` in server relay | `server/socket/session_namespace.py` | 3h |
| 16 | HP range → status label: healthy/wounded/bloodied/critical/dead | `server/services/entity_service.py` | 2h |
| 17 | DM client: UI to mark individual fields as hidden on entity card | `ui/widgets/npc_sheet.py` | 3h |

---

**Tuesday, Jun 9 — Live visibility toggle**

| # | Task | Files | Estimate |
|---|---|---|---|
| 18 | DM can toggle field visibility during session; `entity.visibility_changed` event | `ui/widgets/npc_sheet.py`, `core/network/bridge.py` | 3h |
| 19 | Server: relay `entity.visibility_changed`; re-apply redaction | `server/socket/session_namespace.py` | 2h |
| 20 | Player client: update rendered card immediately on visibility change | `ui/windows/player_window.py` | 2h |

---

**Wednesday–Thursday, Jun 10–11 — Tests**

| # | Task | Files | Estimate |
|---|---|---|---|
| 21 | Server tests: full redaction scenarios | `server/tests/test_visibility.py` | 4h |
| 22 | Server tests: HP status label boundaries | `server/tests/test_entity_service.py` | 2h |
| 23 | Integration test: DM toggles visibility → player card updates | `server/tests/test_integration_visibility.py` | 3h |

---

**Friday, Jun 12 — Sprint 7 review + Phase 3 milestone**

| # | Task | Files | Estimate |
|---|---|---|---|
| 24 | Sprint 7 acceptance criteria verification | All Sprint 7 files | 2h |
| 25 | Phase 3 milestone: all gameplay features ready for beta | — | 1h |

### Sprint 7 Acceptance Criteria

| Deliverable | Test |
|---|---|
| Server-side dice roller | All clients receive result simultaneously within 200ms |
| Dice notation support | Unit test: 2d6+3, 2d20kh1 (advantage), 4d6dL all parse correctly |
| Event log persistence | Log survives server restart; DM can query after session end |
| Event log export | Plain text and JSON exports produce valid, readable files |
| Field-level redaction | Player receives redacted card; HP shown as status label |
| Live visibility toggle | DM hides a field → player card updates within 300ms |

---

## 7. Sprint 8 — Deployment and Beta (Jun 15–26)

### Sprint Goal

The application is deployed in a production-grade configuration. All observability is in place. Closed beta begins with 10–20 DMs running real sessions.

### Day-by-Day Schedule

#### Week 1 (Jun 15–19) — Docker Compose and Infrastructure

---

**Monday, Jun 15 — Production Docker Compose**

| # | Task | Files | Estimate |
|---|---|---|---|
| 1 | Write production Docker Compose (server, db, redis, minio, nginx) | `docker-compose.prod.yml` | 3h |
| 2 | Write development Docker Compose | `docker-compose.dev.yml` | 1h |
| 3 | Write Nginx configuration (TLS termination, WebSocket upgrade, rate limiting) | `nginx/nginx.conf` | 3h |

---

**Tuesday, Jun 16 — TLS and secrets management**

| # | Task | Files | Estimate |
|---|---|---|---|
| 4 | Document Let's Encrypt setup with `certbot` + Nginx | `docs/SELF_HOSTING.md` | 2h |
| 5 | Self-signed certificate generation guide (for LAN/offline servers) | `docs/SELF_HOSTING.md` | 1h |
| 6 | Secrets: move all credentials to Docker secrets / `.env` files | `docker-compose.prod.yml`, `server/config.py` | 2h |
| 7 | First-run setup wizard: force admin credential change | `server/setup.py` | 2h |

---

**Wednesday, Jun 17 — Backup and restore**

| # | Task | Files | Estimate |
|---|---|---|---|
| 8 | PostgreSQL backup script: `pg_dump` → compressed archive | `scripts/backup_db.sh` | 2h |
| 9 | MinIO backup script: `mc mirror` to secondary storage | `scripts/backup_assets.sh` | 2h |
| 10 | Restore procedure: documented and tested with a real backup | `docs/SELF_HOSTING.md` | 2h |
| 11 | Automated daily backup via `cron` (Docker container) | `docker-compose.prod.yml` | 1h |

---

**Thursday, Jun 18 — Observability**

| # | Task | Files | Estimate |
|---|---|---|---|
| 12 | Add Prometheus metrics to FastAPI (request count, latency, active sessions) | `server/main.py`, `server/monitoring.py` | 3h |
| 13 | Loki logging integration: structured JSON logs → Loki | `server/main.py` | 2h |
| 14 | Grafana dashboards: active sessions, event latency, error rate | `monitoring/grafana/dashboards/` | 3h |

---

**Friday, Jun 19 — Alert rules**

| # | Task | Files | Estimate |
|---|---|---|---|
| 15 | Prometheus alert: event latency P95 > 200ms for 60s | `monitoring/prometheus/alerts.yml` | 1h |
| 16 | Prometheus alert: error rate > 1% for 60s | `monitoring/prometheus/alerts.yml` | 30m |
| 17 | Prometheus alert: MinIO storage > 80% | `monitoring/prometheus/alerts.yml` | 30m |
| 18 | Test all alerts with synthetic failures | — | 2h |

---

#### Week 2 (Jun 22–26) — Beta Launch

---

**Monday, Jun 22 — Pre-beta review**

| # | Task | Files | Estimate |
|---|---|---|---|
| 19 | Full internal test session (2 internal DMs + 4 players) | — | 4h |
| 20 | Document issues found; triage by severity | — | 2h |
| 21 | Fix any P1 issues found | Various | Up to 4h |

---

**Tuesday, Jun 23 — Beta onboarding materials**

| # | Task | Files | Estimate |
|---|---|---|---|
| 22 | Write beta onboarding guide: install, configure, start session | `docs/BETA_ONBOARDING.md` | 3h |
| 23 | Write player quick start: download, enter code, join | `docs/PLAYER_QUICKSTART.md` | 2h |
| 24 | Beta feedback survey setup (Google Forms or Typeform) | — | 1h |

---

**Wednesday, Jun 24 — Beta launch: Wave 1 (10 DMs)**

| # | Task | Files | Estimate |
|---|---|---|---|
| 25 | Provision hosted server | Cloud provider | 2h |
| 26 | Deploy production Docker Compose | Server | 2h |
| 27 | Send invitations to Wave 1 beta DMs | — | 1h |
| 28 | Monitor dashboards during first sessions | — | Ongoing |

---

**Thursday, Jun 25 — Bug triage**

| # | Task | Files | Estimate |
|---|---|---|---|
| 29 | Triage all issues reported by beta DMs | — | 3h |
| 30 | Fix P1 issues same-day | Various | Up to 4h |
| 31 | Schedule P2/P3 fixes for post-beta sprint | `docs/` | 1h |

---

**Friday, Jun 26 — Sprint 8 review + Beta Wave 2**

| # | Task | Files | Estimate |
|---|---|---|---|
| 32 | Beta expansion to Wave 2 (20 DMs) if Wave 1 P1 issues resolved | — | 1h |
| 33 | Sprint 8 retrospective | — | 1h |
| 34 | Post-online roadmap planning (begin monetization activation) | `docs/` | 2h |

### Sprint 8 Acceptance Criteria

| Deliverable | Test |
|---|---|
| Production Docker Compose | Full stack starts with `docker compose up`; all health checks pass |
| TLS | HTTPS works; HTTP redirects to HTTPS |
| Backup | `backup_db.sh` + `backup_assets.sh` produce valid archives; restore tested |
| Grafana dashboards | All panels show real data during a test session |
| Alert rules | Synthetic failures trigger all defined alerts |
| Internal test session | 0 P1 bugs in 4-hour internal session |
| Beta Wave 1 launched | 10+ DMs invited; sessions running |

---

## 8. Cross-Sprint Dependencies

```
Sprint 2 (pre-online)
    │ EventManager, NetworkBridge skeleton, Event schema
    ▼
Sprint 3 (auth + session)
    │ FastAPI, JWT, Session lifecycle, PostgreSQL schema
    ▼
Sprint 4 (assets + map sync)
    │ MinIO, Asset upload/download, Fog sync, Entity push
    │
    ├──────────────────────────────────────────────────┐
    ▼                                                  ▼
Sprint 5 (mind map + reconnect)              Sprint 6 (audio + performance)
    │ Node sync, Reconnect state machine          │ MusicBrain sync, Benchmarks
    └──────────────────────────┬──────────────────┘
                               ▼
                         Sprint 7 (gameplay)
                         │ Dice, Event log, Restricted views
                               ▼
                         Sprint 8 (deployment + beta)
                         │ Docker, TLS, Backup, Beta launch
```

**Critical path:** Every sprint depends on the one before it. A slip in Sprint 3 delays all subsequent sprints. The only parallelism opportunity is Sprint 5 (mind map) and Sprint 6 (audio) — these two can be worked on in parallel tracks if resources allow.

---

## 9. Definition of Done

A sprint is **Done** when:

### Server-Side
- [ ] All planned API endpoints implemented and passing tests
- [ ] All Socket.io handlers implemented and passing integration tests
- [ ] Server test coverage ≥ 80% on new code
- [ ] No raw SQL string interpolation (all queries via SQLAlchemy ORM)
- [ ] All new endpoints documented in FastAPI's Swagger UI

### Client-Side
- [ ] All planned NetworkBridge changes implemented
- [ ] All planned UI changes implemented and accessible
- [ ] No regressions in existing offline functionality
- [ ] `ruff check .` passes on all modified files

### Integration
- [ ] At least one end-to-end integration test per major feature
- [ ] All performance targets met (measured, not estimated)
- [ ] Manual smoke test: full DM + player session without errors

### Documentation
- [ ] Acceptance criteria verified for every task
- [ ] `CHANGELOG.md` updated
- [ ] Retrospective notes written
- [ ] Any new architecture decisions documented in `docs/ONLINE.md`
