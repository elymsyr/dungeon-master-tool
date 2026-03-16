# Dungeon Master Tool — Sprint Map and Implementation Guide

> **Document version:** 1.0
> **Date:** March 16, 2026
> **Companion:** `docs/DEVELOPMENT_REPORT.md` (architecture and specifications)
> **Purpose:** Sprint-by-sprint, file-level implementation plan for the online transition

---

## Table of Contents

1. [Program Framework](#1-program-framework)
2. [Sprint 1: UI Consolidation and Event Layer](#2-sprint-1-ui-consolidation-and-event-layer)
3. [Sprint 2: Embedded Viewer and Socket Infrastructure](#3-sprint-2-embedded-viewer-and-socket-infrastructure)
4. [Sprint 3: Auth/Session Gateway](#4-sprint-3-authsession-gateway)
5. [Sprint 4: Asset Proxy and Map/Projection Sync](#5-sprint-4-asset-proxy-and-mapprojection-sync)
6. [Sprint 5: Mind Map Sync and Reconnect](#6-sprint-5-mind-map-sync-and-reconnect)
7. [Sprint 6: Audio Sync and Performance](#7-sprint-6-audio-sync-and-performance)
8. [Sprint 7: Event Log, Dice Roller, Restricted Cards](#8-sprint-7-event-log-dice-roller-restricted-cards)
9. [Sprint 8: Self-Hosted Deployment and Beta](#9-sprint-8-self-hosted-deployment-and-beta)
10. [Cross-Sprint Quality Gates](#10-cross-sprint-quality-gates)
11. [Sprint Reporting Template](#11-sprint-reporting-template)
12. [Appendices](#appendices)

---

## 1. Program Framework

### 1.1 Timeline

| Sprint | Phase | Dates | Focus |
|--------|-------|-------|-------|
| Sprint 1 | Phase 0 | Mar 9 – Mar 20, 2026 | UI consolidation, EventManager skeleton |
| Sprint 2 | Phase 0 | Mar 23 – Apr 3, 2026 | Embedded viewer, socket smoke test |
| Sprint 3 | Phase 1 | Apr 6 – Apr 17, 2026 | FastAPI gateway, JWT auth, sessions |
| Sprint 4 | Phase 1 | Apr 20 – May 1, 2026 | Asset proxy, map/projection sync |
| Sprint 5 | Phase 2 | May 4 – May 15, 2026 | Mind map sync, reconnect/resync |
| Sprint 6 | Phase 2 | May 18 – May 29, 2026 | Audio sync, performance benchmarks |
| Sprint 7 | Phase 3 | Jun 1 – Jun 12, 2026 | Event log, dice roller, restricted views |
| Sprint 8 | Phase 4 | Jun 15 – Jun 26, 2026 | Self-hosted deployment, backup, beta |

### 1.2 Success Metrics

| Metric | Target |
|--------|--------|
| P95 event latency | < 120ms |
| 5MB map first load | < 3 seconds |
| Reconnect + state recovery | < 5 seconds |
| Critical security breaches | 0 |
| Test coverage (server) | > 80% |

### 1.3 Team Roles

| Role | Responsibility |
|------|---------------|
| Tech Lead | Architecture, contracts, code quality gate |
| Backend Developer | Auth, session, gateway, event routing |
| Desktop Developer | PyQt6 DM/Player integration |
| QA | Functional + non-functional test scenarios |
| DevOps | Environments, observability, release safety |

### 1.4 Sprint Dependency Graph

```
Sprint 1 ──► Sprint 2 ──► Sprint 3 ──► Sprint 4
  (Phase 0)    (Phase 0)    (Phase 1)    (Phase 1)
                                │             │
                                ▼             ▼
                            Sprint 5 ──► Sprint 6
                             (Phase 2)    (Phase 2)
                                              │
                                              ▼
                                          Sprint 7 ──► Sprint 8
                                           (Phase 3)    (Phase 4)
```

**Hard dependencies:**
- Sprint 2 requires Sprint 1 (EventManager API)
- Sprint 3 requires Sprint 2 (socket client layer)
- Sprint 4 requires Sprint 3 (auth/session backend)
- Sprint 5 requires Sprint 4 (asset proxy + sync foundation)
- Sprint 6 requires Sprint 5 (reconnect infrastructure)
- Sprint 7 requires Sprint 4 (session + auth)
- Sprint 8 requires Sprint 7 (all features for beta)

---

## 2. Sprint 1: UI Consolidation and Event Layer

### 2.1 Period
**March 9 – March 20, 2026** (Phase 0)

### 2.2 Sprint Goal
Establish the Phase 0 backbone: UI consolidation and client-side event abstraction layer.

### 2.3 User Stories

#### US-1.1: Single-Window Player View
```
GIVEN the DM has battle map and player views open
WHEN the DM launches the application
THEN both views are combined as tabs within a single window
AND switching between them is seamless with no separate window management
```

#### US-1.2: GM Player Screen Control Panel
```
GIVEN the DM is running a session
WHEN the DM opens the Session Control panel
THEN the DM can see projection status, toggle player screen, and manage displayed content
AND placeholder controls exist for future online session management
```

#### US-1.3: UI Standardization
```
GIVEN the application has inconsistent button sizes and layouts
WHEN the common style tokens are applied
THEN all buttons follow the standardized sizing (small: 28px, medium: 36px, large: 44px)
AND spacing, typography, and padding are consistent across all themes
```

#### US-1.4: EventManager Skeleton
```
GIVEN the application uses direct Qt signals for inter-component communication
WHEN the EventManager is integrated
THEN all state mutations route through EventManager.emit()
AND event handlers are registered via EventManager.subscribe()
AND the same interface works in offline mode (local dispatch) and online mode (WebSocket)
```

### 2.4 File-Level Task List

#### NEW: `core/event_manager.py`

Create the EventManager abstraction layer.

```python
# core/event_manager.py
from typing import Callable, Any, Protocol
from enum import Enum
from pydantic import BaseModel, Field
from datetime import datetime
from uuid import uuid4


class EventMode(str, Enum):
    LOCAL = "local"       # Offline: direct dispatch
    ONLINE = "online"     # Online: dispatch via WebSocket


class BaseEvent(BaseModel):
    """Base event model for all application events."""
    event_id: str = Field(default_factory=lambda: str(uuid4()))
    event_type: str
    payload: dict = Field(default_factory=dict)
    ts: datetime = Field(default_factory=datetime.utcnow)


class EventManagerProtocol(Protocol):
    """Protocol defining the EventManager interface."""

    def connect(self, server_url: str, token: str) -> None:
        """Connect to remote server (switches to online mode)."""
        ...

    def disconnect(self) -> None:
        """Disconnect from remote server (switches to local mode)."""
        ...

    def emit(self, event_type: str, payload: dict) -> None:
        """Emit an event (dispatched locally or via network)."""
        ...

    def subscribe(self, event_type: str, handler: Callable[[dict], Any]) -> str:
        """Subscribe to an event type. Returns subscription ID."""
        ...

    def unsubscribe(self, subscription_id: str) -> None:
        """Unsubscribe from an event."""
        ...

    @property
    def mode(self) -> EventMode:
        """Current operating mode (local or online)."""
        ...

    @property
    def is_connected(self) -> bool:
        """Whether the online connection is active."""
        ...


class EventManager:
    """
    Central event bus for the application.
    In LOCAL mode: events are dispatched directly to subscribers.
    In ONLINE mode: events are sent to server and received from server.
    """

    def __init__(self):
        self._mode = EventMode.LOCAL
        self._subscribers: dict[str, dict[str, Callable]] = {}
        self._socket_client = None  # Injected in Sprint 2

    @property
    def mode(self) -> EventMode:
        return self._mode

    @property
    def is_connected(self) -> bool:
        return self._mode == EventMode.ONLINE and self._socket_client is not None

    def connect(self, server_url: str, token: str) -> None:
        # Implementation in Sprint 2 (socket_client integration)
        pass

    def disconnect(self) -> None:
        self._mode = EventMode.LOCAL
        self._socket_client = None

    def emit(self, event_type: str, payload: dict) -> None:
        if self._mode == EventMode.ONLINE and self._socket_client:
            self._socket_client.emit(event_type, payload)
        # Always dispatch locally (for both modes)
        self._dispatch_local(event_type, payload)

    def subscribe(self, event_type: str, handler: Callable) -> str:
        sub_id = str(uuid4())
        if event_type not in self._subscribers:
            self._subscribers[event_type] = {}
        self._subscribers[event_type][sub_id] = handler
        return sub_id

    def unsubscribe(self, subscription_id: str) -> None:
        for event_type in self._subscribers:
            self._subscribers[event_type].pop(subscription_id, None)

    def _dispatch_local(self, event_type: str, payload: dict) -> None:
        handlers = self._subscribers.get(event_type, {})
        for handler in handlers.values():
            try:
                handler(payload)
            except Exception as e:
                print(f"[EventManager] Handler error for {event_type}: {e}")
```

#### MODIFY: `ui/main_root.py`

Changes:
- Merge player view and battle map into single window as tabs within Session tab
- Add Session Control panel placeholder
- Pass EventManager instance to widgets that need it

Key modifications:
- Add `session_control_panel` widget to the toolbar or as a collapsible sidebar
- Replace separate `BattleMapWindow` launch with embedded tab
- Wire EventManager to all tabs

#### MODIFY: `ui/player_window.py`

Changes:
- Add GM control panel section with:
  - Current projection status indicator
  - Quick toggle buttons for projection content
  - Placeholder for online session controls (join key display, player list)

#### MODIFY: `themes/*.qss` (all 11 theme files)

Changes:
- Add common style tokens at the top of each theme:

```css
/* Common Style Tokens */
QPushButton[sizeClass="small"]  { min-height: 28px; padding: 4px 8px; }
QPushButton[sizeClass="medium"] { min-height: 36px; padding: 6px 12px; }
QPushButton[sizeClass="large"]  { min-height: 44px; padding: 8px 16px; }
```

#### MODIFY: `main.py`

Changes:
- Instantiate `EventManager` alongside `DataManager`
- Pass `event_manager` to `MainWindow`

### 2.5 Test Requirements

#### NEW: `tests/test_core/test_event_manager.py`

```python
def test_subscribe_and_emit():
    """EventManager delivers events to registered handlers."""

def test_unsubscribe_stops_delivery():
    """Unsubscribed handlers do not receive events."""

def test_local_mode_is_default():
    """EventManager starts in LOCAL mode."""

def test_multiple_subscribers_same_event():
    """Multiple handlers for same event type all receive the event."""

def test_emit_unknown_event_no_error():
    """Emitting an event with no subscribers does not raise."""

def test_handler_error_does_not_break_dispatch():
    """A failing handler does not prevent other handlers from executing."""
```

#### UPDATE: `tests/test_ui/test_main_window.py`

```python
def test_single_window_tabs_exist():
    """Main window has all 4 tabs including embedded session view."""

def test_session_control_panel_visible():
    """Session control panel placeholder is rendered."""
```

### 2.6 Acceptance Criteria

- [ ] Single-window flow is stable (no separate battle map window needed)
- [ ] Session control panel is visible and renders placeholder controls
- [ ] EventManager unit tests pass (subscribe/emit lifecycle)
- [ ] UI regression: all existing features work after refactor
- [ ] Style tokens applied to at least 3 themes without visual breakage

### 2.7 Risks and Mitigation

| Risk | Mitigation |
|------|-----------|
| UI refactor breaks existing screen flows | Visual comparison checklist + incremental merge |
| EventManager adds overhead to local mode | Benchmarking: local dispatch must add < 1ms per event |

### 2.8 Dependencies

None (first sprint).

---

## 3. Sprint 2: Embedded Viewer and Socket Infrastructure

### 3.1 Period
**March 23 – April 3, 2026** (Phase 0)

### 3.2 Sprint Goal
Complete Phase 0 with embedded viewers and socket connectivity layer.

### 3.3 User Stories

#### US-2.1: Embedded PDF/Image Viewer
```
GIVEN the DM opens a PDF or image within the application
WHEN the content is displayed
THEN it renders within the application (not an external program)
AND the viewer supports both local files and remote URLs
```

#### US-2.2: Socket.io Client Integration
```
GIVEN the application has an EventManager
WHEN the DM enables online mode
THEN the application connects to the server via python-socketio
AND connection status is displayed in the UI (Disconnected/Connecting/Connected/Error)
```

#### US-2.3: Event Schema v1 Draft
```
GIVEN the team needs a shared event contract
WHEN the event schema v1 is drafted
THEN all events follow the envelope format with event_id, session_id, schema_version, ts, seq
AND the schema is documented and reviewed
```

### 3.4 File-Level Task List

#### NEW: `core/socket_client.py`

```python
# core/socket_client.py
import socketio
from enum import Enum
from typing import Callable, Optional


class ConnectionState(str, Enum):
    DISCONNECTED = "disconnected"
    CONNECTING = "connecting"
    CONNECTED = "connected"
    RECONNECTING = "reconnecting"
    ERROR = "error"


class SocketClient:
    """
    WebSocket client wrapper around python-socketio.
    Handles connection, authentication, reconnection, and event routing.
    """

    def __init__(self, event_manager):
        self.event_manager = event_manager
        self.sio = socketio.Client(
            reconnection=True,
            reconnection_attempts=5,
            reconnection_delay=1,
            reconnection_delay_max=16,
        )
        self._state = ConnectionState.DISCONNECTED
        self._state_callback: Optional[Callable] = None
        self._setup_handlers()

    @property
    def state(self) -> ConnectionState:
        return self._state

    def on_state_change(self, callback: Callable[[ConnectionState], None]):
        """Register callback for connection state changes."""
        self._state_callback = callback

    def connect(self, server_url: str, token: str):
        """Connect to server with JWT token."""
        self._set_state(ConnectionState.CONNECTING)
        try:
            self.sio.connect(
                server_url,
                auth={"token": token},
                transports=["websocket"],
            )
        except Exception as e:
            self._set_state(ConnectionState.ERROR)
            raise

    def disconnect(self):
        """Disconnect from server."""
        self.sio.disconnect()
        self._set_state(ConnectionState.DISCONNECTED)

    def emit(self, event_type: str, payload: dict):
        """Send an event to the server."""
        if self._state == ConnectionState.CONNECTED:
            self.sio.emit("game_event", {
                "event_type": event_type,
                "payload": payload,
            })

    def _setup_handlers(self):
        @self.sio.on("connect")
        def on_connect():
            self._set_state(ConnectionState.CONNECTED)

        @self.sio.on("disconnect")
        def on_disconnect():
            self._set_state(ConnectionState.DISCONNECTED)

        @self.sio.on("reconnect_attempt")
        def on_reconnect_attempt(attempt_number):
            self._set_state(ConnectionState.RECONNECTING)

        @self.sio.on("game_event")
        def on_game_event(data):
            event_type = data.get("event_type")
            payload = data.get("payload", {})
            self.event_manager._dispatch_local(event_type, payload)

    def _set_state(self, new_state: ConnectionState):
        self._state = new_state
        if self._state_callback:
            self._state_callback(new_state)
```

#### MODIFY: `core/event_manager.py`

Changes:
- Implement `connect()` method using `SocketClient`
- Wire incoming WebSocket events to local dispatch

```python
# Add to EventManager.connect():
def connect(self, server_url: str, token: str) -> None:
    from core.socket_client import SocketClient
    self._socket_client = SocketClient(self)
    self._socket_client.connect(server_url, token)
    self._mode = EventMode.ONLINE
```

#### MODIFY: `ui/player_window.py`

Changes:
- Standardize viewer to handle both local file paths and remote URLs
- Add embedded QWebEngineView for PDF rendering
- Support switching between image viewer and PDF viewer based on content type

#### MODIFY: `ui/main_root.py`

Changes:
- Add connection status badge to toolbar:
  - `🔴 Disconnected` | `🟡 Connecting` | `🟢 Connected` | `🔴 Error`
- Wire badge to `SocketClient.on_state_change()`

### 3.5 Event Schema v1

See `DEVELOPMENT_REPORT.md` Section 8.2 for the full `EventEnvelope` Pydantic model.

Summary of required fields:
```
event_id:       UUID v4 (unique per event)
schema_version: "1.0"
session_id:     str (session identifier)
event:          EventType enum
sender:         {role, user_id, username}
ts:             ISO 8601 datetime
seq:            int (monotonically increasing per session)
payload:        dict (type-specific)
```

### 3.6 Test Requirements

#### NEW: `tests/test_core/test_socket_client.py`

```python
def test_initial_state_disconnected():
    """SocketClient starts in DISCONNECTED state."""

def test_connect_changes_state():
    """Successful connect transitions to CONNECTED."""

def test_disconnect_changes_state():
    """Disconnect transitions to DISCONNECTED."""

def test_state_callback_fires():
    """State change callback is invoked on every transition."""

def test_emit_while_disconnected_is_noop():
    """Emitting while disconnected does not raise."""

def test_incoming_event_dispatches_locally():
    """Events received from server are dispatched to EventManager subscribers."""
```

#### NEW: `tests/test_ui/test_viewer.py`

```python
def test_image_viewer_renders_local_file():
    """Image viewer displays a local PNG file."""

def test_pdf_viewer_renders_local_file():
    """PDF viewer displays a local PDF file."""

def test_viewer_handles_missing_file_gracefully():
    """Viewer shows error message for non-existent file."""
```

### 3.7 Acceptance Criteria

- [ ] Viewer renders PDFs and images within the application
- [ ] Socket client connects and disconnects in controlled manner
- [ ] Connection status badge updates in UI
- [ ] Event schema v1 documented and team-reviewed
- [ ] Broken payload handled gracefully (no crash)

### 3.8 Risks and Mitigation

| Risk | Mitigation |
|------|-----------|
| Viewer performance with large files | Lazy load + thumbnail preview |
| QWebEngineView dependency size | Already in requirements (PyQt6-WebEngine) |

### 3.9 Dependencies

Sprint 1 (EventManager API).

---

## 4. Sprint 3: Auth/Session Gateway

### 4.1 Period
**April 6 – April 17, 2026** (Phase 1)

### 4.2 Sprint Goal
Build the first backend core: authentication and session management.

### 4.3 User Stories

#### US-3.1: DM Registration and Login
```
GIVEN a new DM user
WHEN they register with username, email, and password
THEN an account is created and JWT tokens are returned
AND the DM can log in with their credentials
```

#### US-3.2: Session Creation
```
GIVEN an authenticated DM
WHEN they create a new session
THEN a session record is created with a 6-character join key
AND the DM receives a WebSocket URL for real-time communication
```

#### US-3.3: Player Session Join
```
GIVEN an active session with a valid join key
WHEN a player enters the join key
THEN they are added as a participant with PLAYER role
AND they receive a WebSocket URL to connect
```

### 4.4 File-Level Task List

#### NEW: `server/` Directory Structure

```
server/
├── __init__.py
├── main.py                    # FastAPI app + socketio mount
├── config.py                  # Settings (env vars, secrets)
├── dependencies.py            # Dependency injection (db, redis)
├── auth/
│   ├── __init__.py
│   ├── router.py              # Auth endpoints (/register, /login, /refresh, /me)
│   ├── service.py             # Auth business logic
│   ├── jwt.py                 # JWT generation/validation
│   ├── guard.py               # Permission guard middleware
│   └── schemas.py             # Pydantic request/response models
├── sessions/
│   ├── __init__.py
│   ├── router.py              # Session endpoints (/create, /join, /close)
│   ├── service.py             # Session business logic
│   ├── join_key.py            # Join key generation + collision check
│   └── schemas.py             # Pydantic models
├── ws/
│   ├── __init__.py
│   ├── handler.py             # Socket.io event handlers
│   ├── middleware.py          # WS auth middleware
│   └── events.py              # Event routing logic
├── models/
│   ├── __init__.py
│   ├── user.py                # SQLAlchemy User model
│   ├── session.py             # SQLAlchemy Session model
│   └── participant.py         # SQLAlchemy Participant model
├── migrations/
│   ├── env.py                 # Alembic environment
│   ├── alembic.ini
│   └── versions/
│       └── 001_initial.py     # Initial migration (users, sessions, participants)
├── Dockerfile
└── requirements.txt
```

#### NEW: `server/main.py`

```python
# server/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import socketio

from server.config import settings
from server.auth.router import router as auth_router
from server.sessions.router import router as sessions_router
from server.ws.handler import sio

app = FastAPI(title="DM Tool Server", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/v1/auth", tags=["auth"])
app.include_router(sessions_router, prefix="/v1/sessions", tags=["sessions"])

# Mount Socket.IO
sio_app = socketio.ASGIApp(sio, other_app=app)

# The ASGI entry point is sio_app, not app
```

#### NEW: `server/auth/schemas.py`

```python
# server/auth/schemas.py
from pydantic import BaseModel, EmailStr, Field

class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    user_id: str
    username: str
    access_token: str
    refresh_token: str
    expires_in: int

class RefreshRequest(BaseModel):
    refresh_token: str

class UserProfile(BaseModel):
    user_id: str
    username: str
    email: str
    created_at: str
```

#### NEW: `server/sessions/schemas.py`

```python
# server/sessions/schemas.py
from pydantic import BaseModel, Field

class CreateSessionRequest(BaseModel):
    world_name: str = Field(min_length=1, max_length=255)
    max_players: int = Field(default=10, ge=1, le=50)

class CreateSessionResponse(BaseModel):
    session_id: str
    join_key: str
    join_key_expires_at: str
    ws_url: str

class JoinSessionRequest(BaseModel):
    join_key: str = Field(min_length=6, max_length=6)
    display_name: str = Field(default="", max_length=100)

class JoinSessionResponse(BaseModel):
    session_id: str
    role: str
    ws_url: str
    participant_id: str

class SessionDetail(BaseModel):
    session_id: str
    world_name: str
    status: str
    dm: dict
    participants: list[dict]
    created_at: str
```

#### NEW: `server/sessions/join_key.py`

```python
# server/sessions/join_key.py
import random
import string
from server.dependencies import get_redis

CHARSET = string.ascii_uppercase + string.digits  # A-Z, 0-9
KEY_LENGTH = 6
MAX_ATTEMPTS = 10

async def generate_unique_join_key(redis) -> str:
    """Generate a 6-character join key that doesn't collide with active keys."""
    for _ in range(MAX_ATTEMPTS):
        key = "".join(random.choices(CHARSET, k=KEY_LENGTH))
        exists = await redis.exists(f"joinkey:{key}")
        if not exists:
            return key
    raise RuntimeError("Failed to generate unique join key after max attempts")
```

#### NEW: `docker-compose.yml`

See `DEVELOPMENT_REPORT.md` Section 16.1 for the full Docker Compose configuration.

#### NEW: `server/migrations/versions/001_initial.py`

Contains DDL for: `users`, `sessions`, `session_participants` tables.
See `DEVELOPMENT_REPORT.md` Section 9.1 for the full schema.

### 4.5 PostgreSQL Schema (This Sprint)

Tables created in this sprint:
- `users` — User accounts
- `sessions` — Game sessions
- `session_participants` — Session membership

See `DEVELOPMENT_REPORT.md` Section 9.1 for full DDL.

### 4.6 Redis Key Patterns (This Sprint)

| Key | Type | TTL | Purpose |
|-----|------|-----|---------|
| `joinkey:{key}` | String | 24h | Maps join key → session_id |
| `session:{id}:state` | Hash | Session lifetime | Session status |
| `session:{id}:participants` | Set | Session lifetime | Connected users |
| `user:{id}:active_session` | String | Session lifetime | Active session |

### 4.7 Test Requirements

#### NEW: `tests/test_server/test_auth.py`

```python
def test_register_success():
    """Valid registration creates user and returns tokens."""

def test_register_duplicate_username():
    """Duplicate username returns 409."""

def test_login_success():
    """Valid credentials return tokens."""

def test_login_invalid_password():
    """Invalid password returns 401."""

def test_refresh_token_success():
    """Valid refresh token returns new token pair."""

def test_refresh_token_invalid():
    """Invalid refresh token returns 401."""

def test_me_with_valid_token():
    """Valid access token returns user profile."""

def test_me_with_expired_token():
    """Expired access token returns 401."""
```

#### NEW: `tests/test_server/test_sessions.py`

```python
def test_create_session_success():
    """Authenticated DM can create a session with join key."""

def test_create_session_unauthenticated():
    """Unauthenticated request returns 401."""

def test_join_session_valid_key():
    """Valid join key allows player to join."""

def test_join_session_invalid_key():
    """Invalid join key returns 404."""

def test_join_session_full():
    """Joining a full session returns 409."""

def test_close_session_by_dm():
    """DM can close their own session."""

def test_close_session_by_player():
    """Player cannot close a session (403)."""

def test_join_key_collision_resistance():
    """Generate 1000 keys with no collisions."""
```

### 4.8 Acceptance Criteria

- [ ] DM can register, login, and receive JWT tokens
- [ ] DM can create a session with a 6-character join key
- [ ] Player can join with valid key, rejected with invalid key
- [ ] Session full and closed states handled correctly
- [ ] Auth integration tests all pass
- [ ] Docker Compose dev environment runs with `docker compose up`

### 4.9 Risks and Mitigation

| Risk | Mitigation |
|------|-----------|
| Join key brute-force | Rate limiting (10 attempts / 15 min per IP) + short expiry |
| JWT secret exposure | Docker secrets, never committed to git |

### 4.10 Dependencies

Sprint 1 (EventManager), Sprint 2 (SocketClient).

---

## 5. Sprint 4: Asset Proxy and Map/Projection Sync

### 5.1 Period
**April 20 – May 1, 2026** (Phase 1)

### 5.2 Sprint Goal
Make Hub MVP functional: asset distribution and basic map/projection synchronization.

### 5.3 User Stories

#### US-4.1: Asset Upload and Secure Distribution
```
GIVEN the DM has a map image to share
WHEN the DM starts an online session
THEN the map image is uploaded to MinIO via presigned URL
AND players can download it via time-limited, session-scoped URLs
AND URLs expire after 60 seconds
```

#### US-4.2: Map/Projection Sync
```
GIVEN the DM changes the projected content
WHEN the projection is updated
THEN all connected players see the new content within 3 seconds
AND the map state (grid, viewport) is synchronized
```

#### US-4.3: Session State Broadcast
```
GIVEN a session is active
WHEN the session state changes (player joins/leaves, view changes)
THEN all participants receive SESSION_STATE event
```

### 5.4 File-Level Task List

#### NEW: `server/assets/`

```
server/assets/
├── __init__.py
├── router.py          # /presign, /{asset_id} endpoints
├── service.py         # MinIO integration, signed URL generation
└── schemas.py         # Pydantic models
```

#### NEW: `server/assets/service.py`

```python
# server/assets/service.py
import boto3
from botocore.config import Config
from server.config import settings

class AssetService:
    def __init__(self):
        self.s3 = boto3.client(
            "s3",
            endpoint_url=settings.minio_url,
            aws_access_key_id=settings.minio_access_key,
            aws_secret_access_key=settings.minio_secret_key,
            config=Config(signature_version="s3v4"),
        )
        self.bucket = "dm-assets"

    def generate_upload_url(self, session_id: str, filename: str,
                            content_type: str) -> tuple[str, str]:
        """Returns (asset_id, presigned_upload_url)."""
        asset_id = f"{session_id}/{filename}"
        url = self.s3.generate_presigned_url(
            "put_object",
            Params={"Bucket": self.bucket, "Key": f"sessions/{asset_id}",
                    "ContentType": content_type},
            ExpiresIn=300,  # 5 minutes to upload
        )
        return asset_id, url

    def generate_download_url(self, asset_id: str) -> str:
        """Returns presigned download URL (60s TTL)."""
        return self.s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": self.bucket, "Key": f"sessions/{asset_id}"},
            ExpiresIn=60,
        )
```

#### MODIFY: `server/ws/handler.py`

Add event handlers:
- `MAP_STATE_SYNC` — DM sends map state → broadcast to session players
- `PROJECTION_UPDATE` — DM sends projection → broadcast to session players
- `SESSION_STATE` — Server broadcasts session state periodically

```python
# Add to server/ws/handler.py

@sio.on("game_event")
async def handle_game_event(sid, data):
    event_type = data.get("event_type")
    payload = data.get("payload", {})
    session_id = data.get("session_id")

    # Validate sender has permission for this event type
    conn = await get_connection_info(sid)
    if not conn:
        return

    if event_type in ("MAP_STATE_SYNC", "PROJECTION_UPDATE"):
        if conn["role"] != "DM_OWNER":
            return  # Only DM can send these

        # Assign seq number
        seq = await increment_seq(session_id)

        # Broadcast to all session participants (except sender)
        envelope = build_envelope(event_type, payload, conn, session_id, seq)
        await sio.emit("game_event", envelope, room=session_id, skip_sid=sid)

        # Buffer for resync
        await buffer_event(session_id, seq, envelope)
```

#### MODIFY: `ui/widgets/projection_manager.py`

Changes:
- On projection change, emit `PROJECTION_UPDATE` via EventManager
- Upload asset to MinIO before emitting event

#### MODIFY: `ui/tabs/map_tab.py`

Changes:
- On map change, emit `MAP_STATE_SYNC` via EventManager
- Upload map image asset on session start

#### MODIFY: `ui/player_window.py`

Changes:
- Subscribe to `PROJECTION_UPDATE` events
- Download assets via signed URL when received
- Render received content

### 5.5 Security Test Checklist

```
[ ] Expired asset URL returns 403
[ ] Asset URL from different session returns 403
[ ] Non-participant cannot access session assets
[ ] Upload without presigned URL returns 403
[ ] File size exceeding limit is rejected
[ ] Content-type mismatch is detected
```

### 5.6 Test Requirements

#### NEW: `tests/test_server/test_assets.py`

```python
def test_presign_upload_success():
    """Authenticated DM gets a valid presigned upload URL."""

def test_presign_upload_unauthenticated():
    """Unauthenticated request returns 401."""

def test_download_url_success():
    """Session participant gets a valid download URL."""

def test_download_url_wrong_session():
    """Participant from different session gets 403."""

def test_download_url_expired():
    """Expired download URL returns 403 from MinIO."""
```

#### NEW: `tests/test_integration/test_map_sync.py`

```python
def test_dm_updates_map_players_receive():
    """DM sends MAP_STATE_SYNC → all players receive it."""

def test_projection_update_broadcast():
    """DM sends PROJECTION_UPDATE → all players receive it."""

def test_map_load_under_3_seconds():
    """5MB map image loads on player side within 3 seconds."""
```

### 5.7 Acceptance Criteria

- [ ] DM projection content appears on all players
- [ ] Map state consistent across all session participants
- [ ] 5MB map loads in < 3 seconds
- [ ] Security checklist passes with no critical findings
- [ ] Asset URLs expire correctly

### 5.8 Risks and Mitigation

| Risk | Mitigation |
|------|-----------|
| Asset URL sharing (unauthorized access) | 60-second TTL, session-scoped, one-time use option |
| Large map upload timeouts | Chunked upload, progress indicator |

### 5.9 Dependencies

Sprint 3 (auth + session backend).

---

## 6. Sprint 5: Mind Map Sync and Reconnect

### 6.1 Period
**May 4 – May 15, 2026** (Phase 2)

### 6.2 Sprint Goal
Deliver mind map sharing and network resilience (reconnect/resync).

### 6.3 User Stories

#### US-5.1: Mind Map Push
```
GIVEN the DM has nodes on their mind map
WHEN the DM right-clicks a node and selects "Push to Players"
THEN the node appears in all target players' mind map workspace
AND the node retains its content, position, and connections
```

#### US-5.2: Reconnect and State Recovery
```
GIVEN a player is connected to a session
WHEN their network connection drops and recovers
THEN the player automatically reconnects within 5 seconds
AND all state is recovered via delta resync or full snapshot
```

### 6.4 File-Level Task List

#### MODIFY: `ui/tabs/mind_map_tab.py`

Changes:
- Add "Push to Players" context menu option on right-click
- Subscribe to `MINDMAP_PUSH`, `MINDMAP_NODE_UPDATE`, `MINDMAP_LINK_SYNC`, `MINDMAP_NODE_DELETE` events
- On receive: add node to local canvas with `origin: "dm"` marker
- Emit events when user modifies shared nodes

#### MODIFY: `ui/widgets/mind_map_items.py`

Changes:
- Add fields to `MindMapNode`:
  - `origin: str` — "dm" or "player"
  - `visibility: str` — "private", "shared_full", "shared_restricted"
  - `sync_id: str` — network-stable identifier
  - `owner_id: str` — user who created the node
- Visual indicator for shared nodes (e.g., small icon or border color)
- DM-origin nodes cannot be deleted by players

#### MODIFY: `core/socket_client.py`

Changes:
- Implement reconnect state machine (see `DEVELOPMENT_REPORT.md` Section 13.1)
- On reconnect: send `resync_request` with `last_known_seq`
- Handle `resync_response` (delta events) and `full_snapshot` fallback

```python
# Add to SocketClient
def _on_reconnect(self):
    """After reconnect, request delta resync."""
    self._set_state(ConnectionState.RECONNECTING)
    self.sio.emit("resync_request", {
        "session_id": self._session_id,
        "from_seq": self._last_received_seq,
    })
```

#### MODIFY: `server/ws/handler.py`

Changes:
- Add `MINDMAP_PUSH`, `MINDMAP_NODE_UPDATE`, `MINDMAP_LINK_SYNC`, `MINDMAP_NODE_DELETE` handlers
- Add `resync_request` handler:
  - Retrieve buffered events from Redis
  - If available, send delta events
  - If expired, send full snapshot

### 6.5 Reconnect State Machine

```
CONNECTED ──(network drop)──► RECONNECTING
  │                               │
  │                    attempt 1: delay 1s + jitter
  │                    attempt 2: delay 2s + jitter
  │                    attempt 3: delay 4s + jitter
  │                    attempt 4: delay 8s + jitter
  │                    attempt 5: delay 16s + jitter
  │                               │
  │                    ┌──── success ────┐
  │                    ▼                 │
  │              DELTA_RESYNC            │
  │                    │                 │
  │              ┌── success ──┐    ── fail ──┐
  │              ▼             │              ▼
  │          CONNECTED    FULL_SNAPSHOT    DISCONNECTED
  │                            │         (user must retry)
  │                       ── success ──┐
  │                                    ▼
  │                                CONNECTED
```

### 6.6 Delta Resync Algorithm

```python
# Pseudocode for delta resync
async def handle_resync_request(session_id, from_seq):
    current_seq = await redis.get(f"session:{session_id}:seq")

    if from_seq >= current_seq:
        # Client is up to date
        return {"type": "resync_complete", "seq": current_seq}

    # Try to retrieve buffered events
    events = await redis.lrange(
        f"session:{session_id}:events:{from_seq}:{current_seq}",
        0, -1
    )

    if events:
        return {"type": "delta_resync", "events": events}
    else:
        # Events expired from buffer — send full snapshot
        snapshot = await build_session_snapshot(session_id)
        return {"type": "full_snapshot", "state": snapshot, "seq": current_seq}
```

### 6.7 Test Requirements

#### NEW: `tests/test_integration/test_mindmap_sync.py`

```python
def test_push_node_to_all_players():
    """DM pushes a node → appears on all player mind maps."""

def test_push_node_with_connections():
    """Pushed node preserves connections to other pushed nodes."""

def test_player_cannot_delete_dm_node():
    """Player attempting to delete DM-origin node is rejected."""

def test_player_can_move_received_node():
    """Player can reposition a received node in their workspace."""
```

#### NEW: `tests/test_integration/test_reconnect.py`

```python
def test_reconnect_with_delta_resync():
    """After brief disconnect, client receives missed events."""

def test_reconnect_with_full_snapshot():
    """After long disconnect (events expired), client gets full snapshot."""

def test_reconnect_preserves_state():
    """After reconnect, client state matches server state."""

def test_reconnect_within_5_seconds():
    """Reconnect + state recovery completes within 5 seconds."""
```

### 6.8 Acceptance Criteria

- [ ] DM-pushed nodes appear on all player mind maps
- [ ] Connections between pushed nodes synchronize correctly
- [ ] Reconnect after network drop recovers state within 5 seconds
- [ ] Delta resync works for brief disconnections
- [ ] Full snapshot fallback works for long disconnections
- [ ] State drift rate below acceptable threshold

### 6.9 Risks and Mitigation

| Risk | Mitigation |
|------|-----------|
| State drift between clients | Seq-based ordering, idempotent apply, snapshot fallback |
| Concurrent node edits conflict | Last-write-wins strategy (acceptable for mind map) |

### 6.10 Dependencies

Sprint 4 (asset proxy + sync foundation).

---

## 7. Sprint 6: Audio Sync and Performance

### 7.1 Period
**May 18 – May 29, 2026** (Phase 2)

### 7.2 Sprint Goal
Production-quality audio synchronization and performance validation.

### 7.3 User Stories

#### US-6.1: Audio State Sync
```
GIVEN the DM changes the music theme, intensity, or volume
WHEN the audio state changes
THEN all players hear the same audio within acceptable drift tolerance
AND crossfade transitions occur simultaneously across all clients
```

#### US-6.2: Audio File Auto-Caching
```
GIVEN a player does not have an audio file locally
WHEN the DM plays a track
THEN the file is automatically downloaded from the server
AND future plays use the cached version
```

#### US-6.3: Performance Benchmarks
```
GIVEN the system is under normal load (10 concurrent players)
WHEN events are being exchanged
THEN P95 event latency is under 120ms
AND 5MB map loads in under 3 seconds
```

### 7.4 File-Level Task List

#### MODIFY: `core/audio/engine.py`

Changes:
- Add `get_state()` method to `MusicBrain` that returns serializable audio state
- Add `apply_state(state_dict)` method to apply remote audio state
- Add `get_crossfade_params()` for crossfade synchronization

```python
# Add to MusicBrain class
def get_state(self) -> dict:
    """Return serializable audio state for network sync."""
    return {
        "theme_id": self.current_theme_id,
        "state_id": self.current_state_id,
        "intensity_level": self.current_intensity_level,
        "master_volume": self.master_volume,
        "ambience_slots": [
            {"id": slot.current_id, "volume": slot.volume}
            for slot in self.ambience_slots
        ],
    }

def apply_state(self, state: dict) -> None:
    """Apply remote audio state (used by players)."""
    if state.get("theme_id") != self.current_theme_id:
        self.load_theme(state["theme_id"])
    if state.get("state_id") != self.current_state_id:
        self.switch_state(state["state_id"])
    if state.get("intensity_level") != self.current_intensity_level:
        self.set_intensity(state["intensity_level"])
    self.set_master_volume(state.get("master_volume", 1.0))
    for i, slot_data in enumerate(state.get("ambience_slots", [])):
        if i < len(self.ambience_slots):
            self.set_ambience_slot(i, slot_data["id"], slot_data["volume"])
```

#### MODIFY: `ui/soundpad_panel.py`

Changes:
- On any audio state change, emit `AUDIO_STATE` via EventManager
- Subscribe to `AUDIO_STATE`, `AUDIO_CROSSFADE`, `AUDIO_AMBIENCE_UPDATE`, `AUDIO_SFX_TRIGGER`
- Apply debouncing for slider movements (100ms)
- In player mode: disable controls, only display state

#### MODIFY: `server/ws/handler.py`

Changes:
- Add `AUDIO_STATE`, `AUDIO_CROSSFADE`, `AUDIO_AMBIENCE_UPDATE`, `AUDIO_SFX_TRIGGER` handlers
- Audio events broadcast to all session participants

#### NEW: `tests/test_integration/test_audio_sync.py`

```python
def test_audio_state_broadcast():
    """DM audio state change reaches all players."""

def test_crossfade_synchronization():
    """Crossfade events include server_time for sync."""

def test_audio_file_auto_download():
    """Player downloads missing audio file on cache miss."""

def test_master_volume_cap():
    """Player local volume capped by DM master volume."""
```

#### NEW: `tests/test_performance/test_benchmarks.py`

```python
def test_event_latency_p95_under_120ms():
    """P95 event latency across 10 concurrent clients < 120ms."""

def test_map_load_5mb_under_3s():
    """5MB map loads on player side within 3 seconds."""

def test_reconnect_under_5s():
    """Reconnect + state recovery within 5 seconds."""

def test_sustained_10_players_30_minutes():
    """10 concurrent players for 30 minutes with stable latency."""
```

### 7.5 Acceptance Criteria

- [ ] Audio state changes apply consistently across all players
- [ ] Crossfade transitions are synchronized
- [ ] Missing audio files auto-download from server
- [ ] P95 event latency < 120ms (or improvement backlog opened)
- [ ] Performance benchmark report generated

### 7.6 Risks and Mitigation

| Risk | Mitigation |
|------|-----------|
| Device-specific audio sync drift | Server-time reference, tolerance window, periodic re-align |
| High-frequency slider events flood network | 100ms debounce on client side |

### 7.7 Dependencies

Sprint 5 (reconnect infrastructure).

---

## 8. Sprint 7: Event Log, Dice Roller, Restricted Cards

### 8.1 Period
**June 1 – June 12, 2026** (Phase 3)

### 8.2 Sprint Goal
Build shared gameplay mechanics for collaborative play.

### 8.3 User Stories

#### US-7.1: Automated Event Log
```
GIVEN combat is active
WHEN a combat round completes (damage, healing, conditions)
THEN an event log entry is automatically appended
AND all participants see the same log in real-time
```

#### US-7.2: Shared Dice Roller
```
GIVEN a player or DM wants to roll dice
WHEN they submit a dice formula (e.g., "2d6+3")
THEN the server generates the result
AND the result is displayed to all participants with roll details
AND the result is stored in an immutable audit trail
```

#### US-7.3: Restricted Card Database Views
```
GIVEN the DM has entities in their database
WHEN the DM shares an entity with "shared_restricted" visibility
THEN the player sees the entity with dm_notes and secret fields stripped
AND the player cannot access the full version
```

### 8.4 File-Level Task List

#### MODIFY: `ui/tabs/session_tab.py`

Changes:
- Add event log panel that subscribes to `EVENT_LOG_APPEND` events
- Display log entries in real-time with filtering (by type, round)
- Auto-append combat actions from `CombatTracker`

#### MODIFY: `ui/widgets/combat_tracker.py`

Changes:
- On combat actions (damage, healing, condition add/remove), emit `EVENT_LOG_APPEND`
- Emit `COMBAT_STATE_SYNC` on every state change
- Subscribe to incoming `COMBAT_STATE_SYNC` for player mode display

#### NEW: `server/gameplay/`

```
server/gameplay/
├── __init__.py
├── router.py          # Gameplay endpoints (if needed)
├── dice.py            # Server-side dice roller
├── event_log.py       # Event log service
└── schemas.py         # Pydantic models
```

#### NEW: `server/gameplay/dice.py`

```python
# server/gameplay/dice.py
import re
import secrets

def roll_dice(formula: str) -> dict:
    """
    Server-authoritative dice roller.
    Parses formula like "2d6+3", "1d20", "4d8-2".
    Uses secrets.randbelow for cryptographic randomness.
    """
    match = re.match(r"^(\d+)d(\d+)([+-]\d+)?$", formula.strip())
    if not match:
        raise ValueError(f"Invalid dice formula: {formula}")

    num_dice = int(match.group(1))
    die_size = int(match.group(2))
    modifier = int(match.group(3) or 0)

    if num_dice < 1 or num_dice > 100 or die_size < 2 or die_size > 100:
        raise ValueError("Dice parameters out of range")

    individual_rolls = [secrets.randbelow(die_size) + 1 for _ in range(num_dice)]
    total = sum(individual_rolls) + modifier

    return {
        "individual_rolls": individual_rolls,
        "modifier": modifier,
        "total": total,
    }
```

#### MODIFY: `server/ws/handler.py`

Changes:
- Add `DICE_ROLL_REQUEST` handler:
  - Validate formula
  - Generate result using `server/gameplay/dice.py`
  - Store in `dice_rolls` table
  - Broadcast `DICE_ROLL_RESULT` to all
- Add `EVENT_LOG_APPEND` handler:
  - Store in `event_log` table
  - Broadcast to all
- Add `COMBAT_STATE_SYNC` handler:
  - Strip DM-only fields for player recipients
  - Broadcast to session

#### MODIFY: `ui/tabs/database_tab.py`

Changes:
- In player mode, filter entity list to only shared entities
- Render entities based on visibility level:
  - `shared_full` → all fields visible
  - `shared_restricted` → `dm_notes`, `secret_info`, and DM-flagged fields hidden

#### MODIFY: `ui/widgets/npc_sheet.py`

Changes:
- Add `render_mode` parameter: "full" (DM) or "restricted" (Player)
- In restricted mode:
  - Hide `dm_notes` section
  - Hide fields marked as secret by DM
  - Show "Restricted" badge

#### NEW: PostgreSQL Tables (This Sprint)

Tables added: `event_log`, `dice_rolls`, `shared_entities`.
See `DEVELOPMENT_REPORT.md` Section 9.1 for full DDL.

### 8.5 Test Requirements

#### NEW: `tests/test_server/test_dice.py`

```python
def test_roll_basic_formula():
    """'2d6+3' returns valid result with 2 rolls, correct total."""

def test_roll_invalid_formula():
    """Invalid formula raises ValueError."""

def test_roll_result_consistency():
    """Same session dice roll stored in database correctly."""

def test_roll_uses_crypto_random():
    """Dice rolls use secrets module (not random)."""
```

#### NEW: `tests/test_integration/test_gameplay.py`

```python
def test_dice_roll_broadcast():
    """Player rolls dice → all participants see result."""

def test_event_log_append_broadcast():
    """Combat action creates log entry visible to all."""

def test_restricted_entity_view():
    """Player sees restricted entity without dm_notes."""

def test_full_entity_view():
    """Player sees full entity with all permitted fields."""

def test_restricted_entity_bypass_blocked():
    """Player cannot access full version of restricted entity."""
```

### 8.6 Acceptance Criteria

- [ ] Event log shows consistent history on DM and player screens
- [ ] Dice results are server-generated and tamper-proof
- [ ] Restricted entity views correctly hide DM-only fields
- [ ] Full entity views show all permitted content
- [ ] Audit trail records all dice rolls

### 8.7 Risks and Mitigation

| Risk | Mitigation |
|------|-----------|
| Hidden fields accidentally exposed | Server-side redaction + contract tests |
| Dice manipulation | Cryptographic randomness (secrets module) |

### 8.8 Dependencies

Sprint 4 (session + auth), Sprint 5 (sync infrastructure).

---

## 9. Sprint 8: Self-Hosted Deployment and Beta

### 9.1 Period
**June 15 – June 26, 2026** (Phase 4)

### 9.2 Sprint Goal
Deploy to production server and prepare for controlled beta release.

### 9.3 User Stories

#### US-8.1: Self-Hosted Production Deployment
```
GIVEN the development is complete
WHEN the deployment script is executed
THEN the full stack (API, DB, Redis, MinIO, Nginx) runs on a VPS
AND the system is accessible via domain with TLS
```

#### US-8.2: World Backup and Restore
```
GIVEN the DM has an active world
WHEN the DM triggers a backup
THEN the world data and assets are packaged and stored
AND the DM can restore from any backup
AND integrity is verified during restore
```

#### US-8.3: Observability and Monitoring
```
GIVEN the system is in production
WHEN events are processed
THEN metrics are collected (latency, connections, errors)
AND alerts fire on threshold breaches
AND logs are searchable with correlation IDs
```

### 9.4 File-Level Task List

#### NEW: `docker-compose.prod.yml`

See `DEVELOPMENT_REPORT.md` Section 16.2 for the full production Docker Compose.

#### NEW: `nginx/nginx.conf`

See `DEVELOPMENT_REPORT.md` Section 16.3 for the full Nginx configuration.

#### NEW: `.github/workflows/deploy.yml`

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    tags:
      - "v*"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build and push Docker image
        run: |
          docker build -t ghcr.io/${{ github.repository }}/dm-tool-server:${{ github.ref_name }} -f server/Dockerfile .
          echo "${{ secrets.GHCR_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
          docker push ghcr.io/${{ github.repository }}/dm-tool-server:${{ github.ref_name }}

      - name: Deploy to server
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          script: |
            cd /opt/dm-tool
            export TAG=${{ github.ref_name }}
            docker compose -f docker-compose.prod.yml pull
            docker compose -f docker-compose.prod.yml up -d
            docker compose -f docker-compose.prod.yml exec -T api alembic upgrade head
```

#### NEW: `scripts/backup.sh`

See `DEVELOPMENT_REPORT.md` Section 16.4 for the backup script.

#### NEW: `server/observability/`

```
server/observability/
├── __init__.py
├── metrics.py         # Prometheus metric definitions
├── middleware.py       # Request timing middleware
└── logging.py         # Structured logging setup
```

#### NEW: `server/observability/metrics.py`

```python
# server/observability/metrics.py
from prometheus_client import Counter, Histogram, Gauge

ws_connected_clients = Gauge(
    "ws_connected_clients", "Current WebSocket connections"
)

ws_events_total = Counter(
    "ws_events_total", "Total WebSocket events processed",
    ["event_type"]
)

event_delivery_latency = Histogram(
    "event_delivery_latency_ms", "Event delivery latency in milliseconds",
    buckets=[10, 25, 50, 75, 100, 120, 150, 200, 500, 1000]
)

http_request_duration = Histogram(
    "http_request_duration_ms", "HTTP request duration in milliseconds",
    ["method", "endpoint", "status"],
    buckets=[10, 50, 100, 250, 500, 1000, 2500]
)

session_active_count = Gauge(
    "session_active_count", "Currently active sessions"
)

asset_download_duration = Histogram(
    "asset_download_duration_ms", "Asset download duration",
    buckets=[100, 500, 1000, 2000, 3000, 5000]
)
```

#### NEW: `monitoring/` directory

```
monitoring/
├── prometheus.yml         # Prometheus scrape config
├── grafana/
│   └── dashboards/
│       └── dm-tool.json   # Main dashboard definition
└── alerting/
    └── rules.yml          # Alerting rules
```

### 9.5 Beta Release Checklist

```
Pre-release:
[ ] All sprint acceptance criteria met
[ ] Zero critical or high security findings
[ ] P95 latency < 120ms confirmed in benchmark
[ ] 3-hour soak test passed
[ ] Backup/restore verified
[ ] Monitoring dashboards and alerts configured
[ ] TLS certificate valid
[ ] DNS records configured
[ ] Rate limiting verified
[ ] Rollback procedure tested

Release:
[ ] Tag release (e.g., v1.0.0-beta.1)
[ ] Deploy to production server
[ ] Run Alembic migrations
[ ] Verify MinIO bucket creation
[ ] Smoke test: create session, join, sync map, roll dice
[ ] Monitor metrics for 1 hour post-deploy
[ ] Notify beta testers
```

### 9.6 Test Requirements

#### NEW: `tests/test_e2e/test_full_session.py`

```python
def test_full_session_lifecycle():
    """DM creates session → 2 players join → map sync → dice roll → session close."""

def test_internet_join():
    """Player joins from external network via domain."""

def test_backup_restore_integrity():
    """Backup taken → restore → data matches original."""

def test_soak_3_hours():
    """3-hour session with 5 players, stable latency, no crashes."""
```

### 9.7 Acceptance Criteria

- [ ] System accessible from internet via domain with TLS
- [ ] Backup/restore completes successfully with integrity check
- [ ] Monitoring dashboards show real-time metrics
- [ ] Alerts fire correctly on threshold breach
- [ ] 3-hour soak test passes
- [ ] Beta release checklist complete

### 9.8 Risks and Mitigation

| Risk | Mitigation |
|------|-----------|
| Single server bottleneck | Resource limits, regular backup, quick restore runbook |
| TLS certificate expiry | Certbot auto-renewal + monitoring alert |

### 9.9 Dependencies

Sprint 7 (all features complete).

---

## 10. Cross-Sprint Quality Gates

Every sprint must pass these gates before proceeding:

### 10.1 Security Gate
- Zero critical and high severity findings
- Auth guard covers all new endpoints/events
- Audit log captures new sensitive actions
- No secrets in code or git history

### 10.2 Test Gate
- All sprint-specific tests pass
- No regression in existing tests
- Integration tests cover happy path + error cases
- Target: > 80% coverage for server code

### 10.3 Performance Gate
- Sprint-end benchmark report shared
- No P95 latency regression > 20% from previous sprint
- Memory leak check (no unbounded growth in 30-min test)

### 10.4 Documentation Gate
- API/event contracts updated if changed
- New configuration options documented
- Migration steps documented for database changes
- Sprint report completed (see template below)

---

## 11. Sprint Reporting Template

Complete this template at the end of each sprint:

### 11.1 Sprint Summary
- Planned story points: ___
- Completed story points: ___
- Deviation: ___%

### 11.2 Deliverables
- Completed user stories: [list]
- Closed technical debt items: [list]
- Deferred items: [list with reasons]

### 11.3 Quality
- Test summary: ___ passed / ___ failed / ___ skipped
- Bugs found: ___ | Bugs closed: ___
- Performance: P50 = ___ms, P95 = ___ms
- Security findings: ___ critical / ___ high / ___ medium

### 11.4 Risks and Actions
- Ongoing risks: [list]
- Mitigation actions for next sprint: [list]

### 11.5 Decisions
- Architectural decision records (ADRs): [list]
- Scope changes and rationale: [list]

---

## Appendices

### Appendix A: File Change Matrix

| File | S1 | S2 | S3 | S4 | S5 | S6 | S7 | S8 |
|------|----|----|----|----|----|----|----|----|
| `core/event_manager.py` | NEW | MOD | — | — | — | — | — | — |
| `core/socket_client.py` | — | NEW | — | — | MOD | — | — | — |
| `core/audio/engine.py` | — | — | — | — | — | MOD | — | — |
| `core/models.py` | — | — | — | — | — | — | MOD | — |
| `config.py` | — | — | MOD | — | — | — | — | — |
| `main.py` | MOD | — | — | — | — | — | — | — |
| `ui/main_root.py` | MOD | MOD | — | — | — | — | — | — |
| `ui/campaign_selector.py` | — | — | MOD | — | — | — | — | — |
| `ui/player_window.py` | MOD | MOD | — | MOD | — | — | — | — |
| `ui/soundpad_panel.py` | — | — | — | — | — | MOD | — | — |
| `ui/tabs/database_tab.py` | — | — | — | — | — | — | MOD | — |
| `ui/tabs/mind_map_tab.py` | — | — | — | — | MOD | — | — | — |
| `ui/tabs/map_tab.py` | — | — | — | MOD | — | — | — | — |
| `ui/tabs/session_tab.py` | — | — | — | — | — | — | MOD | — |
| `ui/widgets/combat_tracker.py` | — | — | — | — | — | — | MOD | — |
| `ui/widgets/npc_sheet.py` | — | — | — | — | — | — | MOD | — |
| `ui/widgets/mind_map_items.py` | — | — | — | — | MOD | — | — | — |
| `ui/widgets/projection_manager.py` | — | — | — | MOD | — | — | — | — |
| `ui/windows/battle_map_window.py` | MOD | — | — | — | — | — | — | — |
| `themes/*.qss` | MOD | — | — | — | — | — | — | — |
| `server/` | — | — | NEW | MOD | MOD | MOD | MOD | MOD |
| `docker-compose.yml` | — | — | NEW | — | — | — | — | — |
| `docker-compose.prod.yml` | — | — | — | — | — | — | — | NEW |
| `nginx/` | — | — | — | — | — | — | — | NEW |
| `.github/workflows/deploy.yml` | — | — | — | — | — | — | — | NEW |
| `monitoring/` | — | — | — | — | — | — | — | NEW |
| `scripts/backup.sh` | — | — | — | — | — | — | — | NEW |

### Appendix B: API Endpoint Reference

See `DEVELOPMENT_REPORT.md` Appendix B for the full API endpoint table.

### Appendix C: WebSocket Event Reference

See `DEVELOPMENT_REPORT.md` Appendix C for the full WebSocket event table.

### Appendix D: Database Migration Sequence

| Sprint | Migration | Tables |
|--------|-----------|--------|
| Sprint 3 | `001_initial.py` | users, sessions, session_participants |
| Sprint 4 | `002_assets.py` | (MinIO metadata table if needed) |
| Sprint 7 | `003_gameplay.py` | shared_entities, event_log, dice_rolls, audit_log |

### Appendix E: Test Scenario Catalog

| Sprint | Test File | Scenarios |
|--------|-----------|-----------|
| S1 | `test_event_manager.py` | 6 unit tests |
| S1 | `test_main_window.py` | 2 UI tests |
| S2 | `test_socket_client.py` | 6 unit tests |
| S2 | `test_viewer.py` | 3 UI tests |
| S3 | `test_auth.py` | 8 integration tests |
| S3 | `test_sessions.py` | 8 integration tests |
| S4 | `test_assets.py` | 5 integration tests |
| S4 | `test_map_sync.py` | 3 integration tests |
| S5 | `test_mindmap_sync.py` | 4 integration tests |
| S5 | `test_reconnect.py` | 4 integration tests |
| S6 | `test_audio_sync.py` | 4 integration tests |
| S6 | `test_benchmarks.py` | 4 performance tests |
| S7 | `test_dice.py` | 4 unit tests |
| S7 | `test_gameplay.py` | 5 integration tests |
| S8 | `test_full_session.py` | 4 E2E tests |
| **Total** | | **~68 test scenarios** |
