# 🐉 DMT — Hibrit Online Mimarisi: Teknik Rapor

> **Doküman:** ONLINE_REPORT v2.0
> **Son güncelleme:** 2026-04-09
> **Hedef kitle:** Geliştiriciler, mimari karar vericiler, erken benimseyenler
> **Durum:** Approved (mimari kararlar kesinleşti, implementation sub-faz 8a devam ediyor)
> **İlgili dokümanlar:** `FLUTTER_DEVELOPMENT_ROADMAP.md`, `FLUTTER_MIGRATION_BLUEPRINT.md`

---

## İçindekiler

1. [Yönetici Özeti](#1-yönetici-özeti)
2. [Tasarım Prensipleri](#2-tasarım-prensipleri)
3. [Sistem Topolojisi](#3-sistem-topolojisi)
4. [Bileşen Detayları](#4-bileşen-detayları)
5. [Wire Format — EventEnvelope](#5-wire-format--eventenvelope)
6. [NetworkBridge Mimarisi](#6-networkbridge-mimarisi)
7. [Veri Akışları (Diyagramlar)](#7-veri-akışları-diyagramlar)
8. [Mimari Sorunlar ve Çözümler](#8-mimari-sorunlar-ve-çözümler)
9. [Güvenlik Modeli](#9-güvenlik-modeli)
10. [Maliyet Modeli ve Free Tier Matematiği](#10-maliyet-modeli-ve-free-tier-matematiği)
11. [Failure Modes & Recovery](#11-failure-modes--recovery)
12. [Implementation Status (Flutter)](#12-implementation-status-flutter)
13. [Roadmap & Sprint Entegrasyonu](#13-roadmap--sprint-entegrasyonu)
14. [Açık Sorular ve Trade-off'lar](#14-açık-sorular-ve-trade-offlar)
15. [Sözlük](#15-sözlük)
16. [Versiyon Geçmişi](#16-versiyon-geçmişi)

---

## 1. Yönetici Özeti

**Dungeon Master Tool (DMT)**, masaüstü rol yapma oyunları (TTRPG) için **offline-first** prensibine dayalı, açık kaynaklı ve düşük maliyetli bir VTT (Virtual Tabletop) ve kampanya yönetim aracıdır. Bu rapor, DMT'ye eklenen **Hibrit Online Katmanı**'nın mimarisini, tasarım kararlarını ve implementation durumunu detaylandırır.

Hibrit online katmanı, DMT'nin offline gücünü hiçbir şekilde bozmadan üç ek yetenek sunar:

1. **Co-op Oyun:** Oyuncuların kendi cihazlarından DM'in haritasına bağlanması, token hareketi, zar senkronizasyonu
2. **Topluluk Pazarı:** DM'lerin oluşturduğu `.dmt` paketlerinin paylaşılması (dünya, harita, senaryo)
3. **Bulut Yedekleme:** İstenildiğinde yerel verilerin başka cihaza aktarılması

Bu rapor, sıfır sunucu maliyetiyle, açık kaynak felsefesiyle uyumlu ve piyasadaki dev rakiplerine (Roll20, Foundry) modern alternatif sunan bir mimarinin nasıl kurulduğunu açıklar. Stack: **Flutter + Drift (SQLite) + Supabase + Cloudflare R2/Workers**.

---

## 2. Tasarım Prensipleri

| # | Prensip | Açıklama |
|---|---|---|
| **P1** | **Offline-First** | Her özellik internet olmadan tam çalışmalıdır. Online sadece **opt-in** ekstra katmandır. |
| **P2** | **DM as Source of Truth** | DM'in lokal `dmt.sqlite` veritabanı tek doğruluk kaynağıdır. Server hiçbir oyun state'ini değiştiremez, yalnızca event relay yapar. |
| **P3** | **Sıfır Sunucu Maliyeti** | Tüm bileşenler free tier'larda kalmalıdır. Pro plana geçiş eşik ≥ 1000 DAU. |
| **P4** | **Açık Kaynak Güvenliği** | Kod açık olduğu için güvenlik **matematiğe (JWT, SHA-256, asymmetric crypto)** dayanır, gizli secret'a değil. Hardcoded credential yoktur. |
| **P5** | **Minimal Player Friction** | 6 karakterlik join code + display name yeterlidir. Full hesap opsiyoneldir; observer modu anonim çalışır. |
| **P6** | **İçerik Sahipliği** | DM kendi dünyasını her an `.dmt` olarak export edebilir. Vendor lock-in yoktur; veriler standard formatlarda kalır. |
| **P7** | **Artımlı Sync** | Delta event'ler temel mekanizma, snapshot yalnızca fallback. |
| **P8** | **At-Least-Once Delivery** | Event'ler client-generated UUID ile idempotent; tekrar gelirse zarar vermez. |

---

## 3. Sistem Topolojisi

```
┌──────────────────────────────────────────────────────────────────┐
│                          DM Desktop                               │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Flutter App (lib/)                                          │ │
│  │  ──────────────────                                          │ │
│  │  • Drift SQLite (offline source of truth)                    │ │
│  │  • Riverpod state management                                 │ │
│  │  • AppEventBus + EventEnvelope                               │ │
│  │  • SupabaseNetworkBridge (Sprint 9'da)                       │ │
│  │  • SoLoud audio engine                                       │ │
│  └─────────────────────────────────────────────────────────────┘ │
└────────────────┬────────────────────┬────────────────────────────┘
                 │                    │
        (Auth + Realtime          (Asset upload via
         Broadcast WS)            presigned URL)
                 │                    │
                 ▼                    ▼
┌─────────────────────────┐  ┌────────────────────────────────┐
│      Supabase           │  │   Cloudflare R2 + Workers      │
│  ─────────────────      │  │  ──────────────────────────    │
│  • Auth (JWT)           │  │  • R2 private bucket           │
│  • Postgres + RLS       │  │  • Worker (TypeScript)         │
│  • Realtime Channel     │  │    - JWT verify                │
│    "session:{code}"     │  │    - RLS check                 │
│  • Storage (small)      │  │    - KV rate limit (20/h/user) │
│                         │  │    - R2 stream                 │
│  Free tier:             │  │  Free tier:                    │
│  • 50k MAU              │  │  • 10GB R2 storage             │
│  • 500MB DB             │  │  • Zero egress                 │
│  • 1GB storage          │  │  • 100k Worker req/day         │
│  • 200 concurrent WS    │  │  • 1k KV ops/day               │
└─────────────────────────┘  └────────────────────────────────┘
                 ▲                    ▲
                 │                    │
                 └─────────┬──────────┘
                           │
┌──────────────────────────┴───────────────────────────────────────┐
│                      Player Devices                              │
│       (Phone / Tablet / Desktop — Flutter app same code)         │
│                                                                  │
│  • Drift SQLite (lokal cache + restored snapshot)                │
│  • SupabaseNetworkBridge (read incoming + emit local events)     │
│  • SoLoud (DM trigger'ları local'de oynatır)                     │
│  • Mobile: opsiyonel WebRTC P2P screen share (Sprint 11)         │
└──────────────────────────────────────────────────────────────────┘
```

**Akış özeti:**
- DM ve player'lar Flutter uygulamasının **aynı kod tabanını** çalıştırır
- Lokal Drift SQLite her cihazda mevcuttur — DM = canonical, Player = mirror
- Tüm online iletişim **EventEnvelope** wire format'ında geçer
- Asset'ler (görsel/PDF/audio) Supabase üzerinden değil, Cloudflare R2 + Worker üzerinden indirilir

---

## 4. Bileşen Detayları

### 4.1 İstemci (Flutter)

| Modül | Sorumluluk | Lokasyon |
|---|---|---|
| **Drift SQLite** | Lokal storage; 11 tablo (campaigns, entities, sessions, encounters, combatants, world_schemas, map_pins, timeline_pins, mind_map_nodes, mind_map_edges, combat_conditions); schema v2 + `state_json` blob | `lib/data/database/` |
| **Riverpod Notifiers** | Reaktif UI state; campaign, entity, combat, mind map, world map | `lib/application/providers/` |
| **AppEventBus + EventEnvelope** | Cross-cutting event pub/sub + bridge interceptor noktası | `lib/application/services/event_bus.dart` + `lib/domain/entities/events/` |
| **NetworkBridge** | Abstract interface — `NoOpNetworkBridge` (offline default) → `SupabaseNetworkBridge` (Sprint 9) | `lib/data/network/` |
| **SessionManager** | createSession / joinSession / leaveSession contract | `lib/data/network/session_manager.dart` |
| **SoLoud Audio Engine** | `flutter_soloud` 3.1.0 — gapless loop, crossfade, ambience pool, SFX one-shot | `lib/application/services/audio_engine.dart` |
| **PDF Viewer** | `pdfrx` 2.2.24 | embedded widget |

### 4.2 Supabase

**Auth:**
- Email/password (built-in)
- Google OAuth (gelecek, Sprint 10+)
- JWT access (1 saat) + refresh (30 gün)
- Email verification + password reset built-in

**Postgres tabloları (server-side):**

| Tablo | Amaç |
|---|---|
| `auth.users` | Supabase Auth tarafından otomatik yönetilir |
| `game_sessions` | Aktif oyun masaları + 6-char `join_code` |
| `session_participants` | DM/Player/Observer rolleri |
| `event_log` | Revision-based delta sync için event geçmişi |
| `community_worlds` | Paylaşılan `.dmt` market metadata |
| `community_assets` | R2 object key + erişim kontrolü |

**Realtime Broadcast:** Her aktif session için `session:{join_code}` adlı kanal açılır. Fire-and-forget WebSocket; veritabanına yazmaz, sadece relay eder. Dolayısıyla ucuz ve hızlıdır.

**RLS Policy örnekleri:** Section 9.3'e bakın.

**Free tier limitleri:** 50k MAU, 500MB DB, 1GB storage, 200 concurrent WebSocket bağlantısı.

### 4.3 Cloudflare R2 + Worker

**R2 Bucket (`dmt-assets`):**
- Tamamen private — public erişim KAPALI
- Custom domain bağlı (gelecek)
- Object key formatı: `{user_id}/{campaign_id}/{sha256}.{ext}`

**Worker Akışı (TypeScript):**
1. `Authorization: Bearer {jwt}` header zorunlu
2. JWT, Supabase JWT secret ile asimetrik doğrulama
3. RLS check: Supabase REST API'den asset ownership sorgulanır (service role ile)
4. Rate limit: KV-backed counter — 20 download/saat per user (key: `rate:{userId}:{hour}`)
5. R2'dan stream + edge cache headers (`Cache-Control: private, max-age=3600`)

**Hata kodları:**
- `401 Unauthorized` — JWT eksik/geçersiz
- `403 Forbidden` — RLS check başarısız
- `404 Not Found` — R2 object yok
- `429 Too Many Requests` — Rate limit aşıldı

**Free tier:** 10GB R2 storage, **zero egress**, 100k Worker request/day, 1k KV op/day. Pro plan: $5/ay → 10M req/ay.

### 4.4 Python Engine — Tarihsel Not (Production'da Kullanılmaz)

v1.0'da Python core (`core/`) iş mantığı taşıyordu ve Flutter UI ile IPC üzerinden konuşuyordu. v2.0+ Flutter portunda **bu katman tamamen kaldırıldı**:
- Kural motoru `lib/application/services/rule_engine.dart` olarak Dart'a port edildi
- Event bus `AppEventBus` ile değiştirildi
- Bridge `NetworkBridge` interface'i ile soyutlandı

Python kodu sadece **tarihsel referans** ve TR→EN field migration script'leri için repository'de kalır.

---

## 5. Wire Format — EventEnvelope

Tüm online ve offline cross-cutting iletişim tek bir Freezed class üzerinden geçer:

```dart
@freezed
class EventEnvelope with _$EventEnvelope {
  const factory EventEnvelope({
    required String eventId,        // UUID v4 — idempotency key
    required String eventType,      // "entity.created", "session.turn_advanced", ...
    String? sessionId,              // Online session ID (offline = null)
    String? campaignId,
    required DateTime emittedAt,    // UTC
    required Map<String, dynamic> payload,
  }) = _EventEnvelope;

  factory EventEnvelope.now(String type, Map<String, dynamic> payload) =>
      EventEnvelope(
        eventId: const Uuid().v4(),
        eventType: type,
        emittedAt: DateTime.now().toUtc(),
        payload: payload,
      );

  factory EventEnvelope.fromJson(Map<String, dynamic> json) =>
      _$EventEnvelopeFromJson(json);
}
```

### 5.1 24 Event Tipi

`lib/domain/entities/events/event_types.dart` içinde `EventTypes` sınıfı altında string sabitleri olarak tutulur:

| Domain | Tipler | Online forward? |
|---|---|---|
| **Campaign** | `campaign.loaded`, `campaign.saved`, `campaign.created` | ❌ Local only |
| **Entity** | `entity.created`, `entity.updated`, `entity.deleted` | ✅ |
| **Session** | `session.created`, `session.activated`, `session.combatant_added`, `session.combatant_updated`, `session.turn_advanced` | `session.combatant_*` ve `session.turn_advanced` ✅ |
| **Map** | `map.image_set`, `map.fog_updated`, `map.pin_added`, `map.pin_removed` | ✅ |
| **Mind Map** | `mindmap.node_created`, `mindmap.node_updated`, `mindmap.node_deleted`, `mindmap.edge_created`, `mindmap.edge_deleted` | ✅ |
| **Projection** | `projection.content_set`, `projection.mode_changed` | `projection.content_set` ✅ |
| **Audio** | `audio.state_changed`, `audio.track_triggered` | `audio.state_changed` ✅ |

**`EventTypes.onlineEvents` set'i** 17 elemanlıdır ve `NetworkBridge` interceptor'u yalnızca bu set'teki tipleri forward eder.

### 5.2 Örnek Payload'lar

**`entity.updated`:**
```json
{
  "eventId": "550e8400-e29b-41d4-a716-446655440000",
  "eventType": "entity.updated",
  "sessionId": "789...",
  "campaignId": "abc...",
  "emittedAt": "2026-04-09T14:32:18Z",
  "payload": {
    "entity_id": "goblin-1",
    "changed_fields": ["fields.combatStats.hp", "dm_notes"]
  }
}
```

**`map.fog_updated`:**
```json
{
  "eventId": "...",
  "eventType": "map.fog_updated",
  "payload": {
    "encounter_id": "battle-vault",
    "fog_data": "iVBORw0KGgo..."  // base64 PNG mask
  }
}
```

**`audio.state_changed`** (DM müzik teması değiştirir):
```json
{
  "eventId": "...",
  "eventType": "audio.state_changed",
  "payload": {
    "theme": "forest",
    "state": "combat",
    "intensity": 0.8
  }
}
```

**Idempotency:** Her event `eventId` UUID v4 taşır. Server bu ID'yi `event_log.event_id` UNIQUE constraint ile dedup eder; tekrar gelen event'ler insert hatası verir (yok sayılır).

---

## 6. NetworkBridge Mimarisi

### 6.1 Connection State Machine

```
       ┌──────────────┐
       │ disconnected │ ◄──── İlk durum / disconnect()
       └──────┬───────┘
              │
              │ connect(sessionId, token)
              ▼
       ┌──────────────┐
       │  connecting  │
       └──────┬───────┘
              │
       ┌──────┴───────┐
       │              │
   success         failure
       │              │
       ▼              ▼
 ┌──────────┐   ┌─────────┐
 │ connected│   │  error  │
 └────┬─────┘   └────┬────┘
      │              │
      │  network     │  retry (exp backoff)
      │  drop        │
      ▼              │
 ┌──────────┐        │
 │  error   │ ◄──────┘
 └────┬─────┘
      │
      │ auto-reconnect
      ▼
  connecting
```

### 6.2 Outgoing Event Flow

```
┌─────────────────────┐
│ Notifier            │  Notifier mutasyonu sırasında EventEnvelope.now() çağırır
│ (combat, entity,    │
│  mind_map, ...)     │
└──────────┬──────────┘
           │ AppEventBus.emit(envelope)
           ▼
┌─────────────────────┐
│ AppEventBus         │  • Stream'e push (lokal listener'lar)
│                     │  • _networkInterceptor?.call(envelope) — bridge'e forward
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ SupabaseNetworkBridge               │
│  if (eventType in onlineEvents):    │
│    if (connected):                  │
│      channel.sendBroadcastMessage() │
│    else:                            │
│      _pendingQueue.add(envelope)    │
└─────────────────────────────────────┘
```

### 6.3 Incoming Event Flow

```
┌─────────────────────────────────────┐
│ Supabase Realtime Channel           │
│  channel.onBroadcast('event', cb)   │
└──────────────┬──────────────────────┘
               │ Map<String, dynamic> payload
               ▼
┌─────────────────────────────────────┐
│ SupabaseNetworkBridge               │
│  EventEnvelope.fromJson(payload)    │
│  _incomingController.add(envelope)  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ AppEventBus.injectRemote(envelope)  │
│  → _controller.add(envelope)        │
└──────────────┬──────────────────────┘
               │ ref.listen(eventBus.allEvents)
               ▼
┌─────────────────────────────────────┐
│ Notifier.applyRemote(envelope)      │
│  → Drift DAO update                 │
│  → state = state.copyWith(...)      │
└─────────────────────────────────────┘
```

### 6.4 Pending Queue + Reconnect

```dart
class SupabaseNetworkBridge implements NetworkBridge {
  final List<EventEnvelope> _pendingQueue = [];

  @override
  void broadcast(EventEnvelope event) {
    if (status != ConnectionStatus.connected) {
      _pendingQueue.add(event);
      return;
    }
    _channel?.sendBroadcastMessage(event: 'event', payload: event.toJson());
  }

  Future<void> _onReconnected() async {
    final flush = List<EventEnvelope>.from(_pendingQueue);
    _pendingQueue.clear();
    for (final event in flush) {
      _channel?.sendBroadcastMessage(event: 'event', payload: event.toJson());
    }
  }
}
```

### 6.5 NoOpNetworkBridge — Offline-First Garantisi

`NoOpNetworkBridge` tamamen no-op'tur: tüm metodlar boş döner, hiçbir yan etki yapmaz. Bu class **default** olarak Riverpod provider'dan döner. Kullanıcı bir session create/join etmediği sürece online katman tamamen devre dışıdır.

```dart
class NoOpNetworkBridge implements NetworkBridge {
  @override
  ConnectionStatus get status => ConnectionStatus.disconnected;

  @override
  Stream<ConnectionStatus> get statusStream => const Stream.empty();

  @override
  Future<void> connect(String sessionId, String token) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void broadcast(EventEnvelope event) {} // no-op

  @override
  Stream<EventEnvelope> get incomingEvents => const Stream.empty();
}
```

Bu sayede **P1: Offline-First** prensibi korunur: kullanıcı internete bağlanmasa bile uygulama tamamen çalışır.

---

## 7. Veri Akışları (Diyagramlar)

### 7.1 Session Create (DM)

```
DM Client                          Supabase
──────────                         ────────
1. createSession(name)
   ─────────────────────────────►  INSERT INTO game_sessions
                                   (..., join_code: random_6char())
                                   ◄───── { id: "...", joinCode: "ABC123" }

2. _channel = Realtime.channel(
     "session:ABC123"
   ).subscribe()
   ─────────────────────────────►  Realtime subscribes
                                   ◄───── connected

3. UI shows join code: "ABC123"

4. State change → emit envelope
   ─────────────────────────────►  channel.sendBroadcastMessage(...)
                                   ◄───── ack
                                   (rebroadcasts to all channel subs)
```

### 7.2 Session Join (Player)

```
Player Client                      Supabase                       DM Client
─────────────                      ────────                       ─────────
1. Auth (signIn or anonymous)
   ──────────────────────────────► auth.signIn() / signInAnon()
                                   ◄────── access_token

2. joinSession("ABC123")
   ──────────────────────────────► SELECT id FROM game_sessions
                                       WHERE join_code = 'ABC123'
                                   ◄───── { sessionId, dmUserId }

3. INSERT INTO session_participants
   ──────────────────────────────► (..., role: 'PLAYER')
                                   ◄────── ack

4. _channel = Realtime.channel(
     "session:ABC123"
   ).subscribe()
   ──────────────────────────────► Realtime subscribes

5. emit "player.joined" envelope
   ──────────────────────────────► broadcast ────────────────────►  receives "player.joined"

                                                                   6. snapshot = StateSnapshotService
                                                                                   .capture(campaignId)
                                                                      sendSnapshot(snapshot, toUserId)
                                                                   ──► broadcast (private to player)

7. receives snapshot
   StateSnapshotService.restore(snap)
   → Drift transaction:
     - replaceAll entities
     - replaceAll sessions
     - replaceAll mind_map_nodes
     - ...
   → UI rebuild

8. ✅ Player ready to play
```

### 7.3 Asset Download (Player)

```
Player Client            Cloudflare Worker             R2
─────────────            ─────────────────             ──
1. GET /assets/abc.png
   Authorization: Bearer {jwt}
   ─────────────────────► verifyJwt(jwt, env.SUPABASE_JWT_SECRET)
                          ✓ ok, payload.sub = userId

                          checkAssetAccess(userId, "abc.png")
                          ──► SELECT 1 FROM community_assets
                                WHERE r2_object_key = 'abc.png'
                                  AND (uploader_id = $1 OR
                                       session_id IN (
                                         SELECT session_id
                                         FROM session_participants
                                         WHERE user_id = $1
                                       ))
                          ✓ allowed

                          rateLimitCheck(userId)
                          ──► env.RATE_KV.get("rate:userId:14")
                              count = 7  (< 20)
                              env.RATE_KV.put(..., 8, ttl: 3600)

                          env.R2_BUCKET.get("abc.png")
                                                        ──► fetch
                                                        ◄── stream
                          ◄── stream
   ◄── stream
   write to local cache:
     ${cacheDir}/assets/${sha256}.bin
```

### 7.4 Audio Trigger (DM → Player)

```
DM Client                        Supabase Realtime           Player Client
─────────                        ─────────────────           ─────────────
1. User changes theme to "Forest Combat"
2. soundpadProvider.notifier
     .setState("combat")

3. emit envelope:
   {
     eventType: "audio.state_changed",
     payload: {
       theme: "forest",
       state: "combat",
       intensity: 0.8
     }
   }
   ───────────────────────────────► channel.broadcast ──────────►  receives envelope

                                                                   4. soundpadProvider
                                                                        .applyRemote(env)
                                                                      → audioEngine.setState("combat")
                                                                      → SoLoud loads pre-cached file
                                                                        from .dmt package
                                                                      → fadeVolume(handle, 0.8, 3s)

5. ✅ Both DM and Player hear the same music
   • Network payload: ~120 bytes JSON
   • Latency: < 100ms (Realtime broadcast)
   • Audio sync: <500ms (within crossfade duration)
```

### 7.5 Mobile WebRTC Screen Share (P2P)

```
DM Phone                                              Player Phone
────────                                              ────────────
1. Generate or reuse joinCode "ABC123"
2. Open RTCPeerConnection (DM as offerer)
3. Create offer → SDP

4. emit "webrtc.offer" via Supabase
   ─────────────────────────────────►  Player receives via channel

                                       5. Player creates RTCPeerConnection
                                       6. setRemoteDescription(offer)
                                       7. createAnswer → SDP
                                       8. emit "webrtc.answer" via Supabase
   ◄─────────────────────────────────────────  receives answer
9. setRemoteDescription(answer)

10. ICE candidates exchange via Supabase
    ←─── DM ICE ──→ Player ←─── Player ICE ──→ DM
    (typically Cloudflare TURN if NAT-restricted)

11. P2P data channel ESTABLISHED ────────────────────  data channel ready

12. DM captures projection content (RepaintBoundary.toImage)
13. JPEG encode → 15 FPS
14. dataChannel.send(jpegBytes) ─────────────────────►  receives frame
                                                       Image.memory() display

15. Sync continues until session ends
```

---

## 8. Mimari Sorunlar ve Çözümler

Bu bölüm, açık kaynak ve free-tier kısıtlarıyla çalışırken karşılaşılan beş ana mimari darboğazı ve çözümlerini detaylandırır.

### 8.1 Açık Kaynak Veri Güvenliği — Worker JWT Pattern

**Sorun:** Proje açık kaynak olduğu için, uygulama içine gizlenen şifreler veya HTTP header'ları koddan okunabilir. Kötü niyetli biri R2'daki premium veya kapalı içerik dosyalarını herkesle paylaşabilir.

**Çözüm:** R2 bucket tamamen private; tüm istekler Cloudflare Worker'dan geçer:
1. Flutter istemcisi her asset isteğinde **Supabase JWT** (kullanıcının oturum token'ı) gönderir
2. Worker JWT'yi Supabase'in **public key'i** ile asimetrik olarak doğrular (private key sızdırılamaz)
3. Worker, kullanıcının veritabanında o asset'e erişim izni olduğunu kontrol eder (RLS check, service role API)
4. Onaylanırsa R2'dan stream eder, aksi halde 401/403 döner

**Avantaj:** Kod tamamen açık olsa da güvenlik **matematiğe (asimetrik kripto)** dayanır. Sadece sisteme giriş yapmış ve izinli kullanıcılar dosya indirebilir.

**Ek katman:** Worker üzerinde **rate limit** (saatte max 20 download per user) bot saldırılarını engeller.

### 8.2 Broadcast Veri Kaybı — DM Snapshot Recovery

**Sorun:** Supabase Realtime Broadcast veritabanına yazmadan çalıştığı için (fire-and-forget) hızlı ve maliyetsizdir. Ancak interneti kopup geri gelen bir oyuncu, koptuğu andaki harita hareketlerini (örn. NPC pozisyon güncellemeleri) kaçırır.

**Çözüm: DM as Source of Truth + İki kademeli recovery:**

| Senaryo | Strateji |
|---|---|
| **Yeniden bağlanma, < 200 event kayıp** | **Delta resync:** Server'daki `event_log` tablosundan kullanıcının son `revision` numarasından sonraki event'ler çekilir, sırayla replay edilir |
| **Yeniden bağlanma, > 200 event kayıp veya ilk join** | **Snapshot fallback:** Player DM'e `sync_request` envelope'ı yollar, DM `StateSnapshotService.capture()` ile lokal Drift'ten tam state'i çıkarır, broadcast eder, player `restore()` ile lokal'e yazar |

```dart
class StateSnapshotService {
  Future<GameSnapshot> capture(String campaignId) async {
    return GameSnapshot(
      capturedAt: DateTime.now().toUtc(),
      campaignId: campaignId,
      entities: await _db.entityDao.getAllForCampaign(campaignId),
      sessions: await _db.sessionDao.getAllForCampaign(campaignId),
      mapData: await _db.mapDao.getAllForCampaign(campaignId),
      mindMaps: await _db.mindMapDao.getAllForCampaign(campaignId),
      // ...
    );
  }
}
```

**Garanti:** Reconnect'ten sonra player tam state'i < 5 saniyede yükler.

### 8.3 Audio Bant Genişliği — Trigger / Pre-cache Pattern

**Sorun:** Yüksek kaliteli savaş müzikleri ve ortam seslerini online stream etmek devasa bir ağ yüküdür ve gecikmeden dolayı senkronizasyon felakettir.

**Çözüm:** **Dosyalar pre-cached, sadece JSON command broadcast.**

1. `.dmt` paketleri (kampanya export'ları) tüm ses dosyalarını içerir
2. Player oyuna katılmadan önce paketi Worker üzerinden indirir (bir kere)
3. DM tema/intensity değiştirdiğinde sadece JSON gider:
   ```json
   {"event": "audio.state_changed", "track_id": "rain", "intensity": 0.8}
   ```
4. Player'ın lokal `flutter_soloud` engine'i kendi cihazındaki dosyayı oynatır

**Sonuç:**
- Bant tüketimi: **byte düzeyinde** (300 byte JSON vs MB düzeyinde audio stream)
- Gecikme: **sıfır** (sadece broadcast latency, ses dosyası zaten lokal)
- Senkronizasyon: SoLoud `fadeVolume()` ile crossfade aynı eğride çalar

### 8.4 Concurrent WebSocket Limit — Bölünmüş Ağ Mimarisi

**Sorun:** Supabase Free Tier yalnızca **200 concurrent WebSocket** sunar. Sosyal medya/market özelliklerini gezen her kullanıcı bu limiti tüketirse aktif oyun masaları tıkanır.

**Çözüm: Bölünmüş Ağ:**

| Özellik kategorisi | Protokol | WS limit tüketimi |
|---|---|---|
| Community market browse | HTTP REST | Sıfır |
| `.dmt` download | HTTP (Worker proxy) | Sıfır |
| Profile / settings | HTTP REST | Sıfır |
| Session join/leave (metadata) | HTTP REST | Sıfır |
| **Aktif oyun masası** | **Realtime Broadcast** | DM + 4-5 player ≈ 5-6 WS |

**Yaşam döngüsü:** Realtime kanal **yalnızca** session aktifken açıktır. Kullanıcı session'dan çıktığında kanal **derhal** `disconnect()` edilir. Bu sayede 200 limit ile ~33-40 paralel oyun masası mümkündür.

### 8.5 Python Realtime SDK Olgunluğu — Flutter as Network Bridge

**Sorun:** v1.0'da Python core hem oyun mantığını hem de online iletişimi yapacaktı. Ancak Python ekosistemindeki Supabase Realtime SDK'sı, Dart kadar olgun ve stabil değildir.

**Çözüm:** Python katmanı v2.0+ Flutter portunda **tamamen kaldırıldı**. Kural motoru `lib/application/services/rule_engine.dart` olarak Dart'a port edildi. Tüm online iletişim **`supabase_flutter`** SDK üzerinden yürütülür.

**Bonus:** Bu karar tek kod tabanı (Flutter) sayesinde DM/Player aynı binary'i kullanır, deployment ve test surface'i %50 azalır.

---

## 9. Güvenlik Modeli

### 9.1 Threat Model

| Tehdit | Risk seviyesi | Mitigation |
|---|---|---|
| Unauthorized asset download | Yüksek | Worker JWT verify + RLS check |
| Bot scraping (asset enum) | Orta | Worker rate limit (20/h/user) + KV counter |
| Auth credential brute force | Düşük | Supabase built-in 5/dk/IP login limit |
| JWT forgery | Çok düşük | Asimetrik (RS256), Supabase secret server-side only |
| MITM attack | Çok düşük | Tüm trafik HTTPS/WSS |
| Tampered `.dmt` upload | Orta | SHA-256 hash verify, mime type check |
| DM private notes leak | Yüksek | RLS policy + client-side `private_dm` filter (event server'a gitmez) |
| WebRTC ICE leak (NAT) | Düşük | TURN server (Cloudflare Calls veya coturn) |

### 9.2 JWT Lifetime ve Refresh

| Token | Süre | Kullanım |
|---|---|---|
| `access_token` | 1 saat | Tüm API çağrıları, Worker requests, Realtime auth |
| `refresh_token` | 30 gün | Access token süresi dolduğunda yenileme |

**Refresh akışı (otomatik):** `supabase_flutter` SDK access token'ın süresi dolmadan önce arka planda yeniler. Worker yalnızca **valid access token** kabul eder; refresh token'ı asla görmez.

### 9.3 RLS Policies (SQL Örnekleri)

```sql
-- DM yalnızca kendi session'larını yönetebilir
CREATE POLICY "DM owns session"
  ON game_sessions
  FOR ALL
  USING (auth.uid() = dm_user_id);

-- Player'lar session'ı join_code ile okuyabilir
CREATE POLICY "Players read session by code"
  ON game_sessions
  FOR SELECT
  USING (join_code IS NOT NULL AND state = 'active');

-- Participant'lar yalnızca kendi katıldıkları session'ları görür
CREATE POLICY "Participant sees own sessions"
  ON session_participants
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR session_id IN (
      SELECT id FROM game_sessions WHERE dm_user_id = auth.uid()
    )
  );

-- Event log: yalnızca katılınan session'ın event'lerini oku
CREATE POLICY "Read event log in joined session"
  ON event_log
  FOR SELECT
  USING (session_id IN (
    SELECT session_id FROM session_participants WHERE user_id = auth.uid()
  ));

-- Asset metadata: uploader veya aynı session'daki katılımcı görür
CREATE POLICY "Asset accessible to session participants"
  ON community_assets
  FOR SELECT
  USING (
    uploader_id = auth.uid()
    OR session_id IN (
      SELECT session_id FROM session_participants WHERE user_id = auth.uid()
    )
  );
```

### 9.4 Rate Limiting Tablosu

| Kanal | Limit | Uygulama | Bypass |
|---|---|---|---|
| Worker R2 download | 20/saat per user | Cloudflare KV counter | Yok |
| Supabase Realtime emit | DM 30/s, Player 5/s | Server-side throttle | Plan upgrade |
| Auth login | 5/dk per IP | Supabase built-in | Captcha (gelecek) |
| Flutter client fog | 200ms debounce | Local debouncer | — |
| Flutter client mind map | 100ms debounce | Local debouncer | — |
| `.dmt` upload | 1/dk per user | Worker KV counter | — |

### 9.5 İçerik İzolasyonu

**Field-level visibility (Section 10.10 of FLUTTER_MIGRATION_BLUEPRINT):**

| Visibility | Açıklama | Server'a gönderilir mi? |
|---|---|---|
| `private_dm` | Sadece DM görür (DM notes, gizli alanlar) | **Hayır** — client-side filter |
| `shared_full` | Tam erişim (paylaşılan entity'ler, harita) | Evet |
| `shared_restricted` | Maskelenmiş (HP → "Bloodied/Healthy") | Sunucuya tam, client filter |

**Asset bütünlüğü:** Her asset upload'unda SHA-256 hash hesaplanır ve `community_assets.sha256_hash` kolonuna yazılır. Player download sonrası hash doğrulaması yapar; tamper edilmiş dosya tespit edilirse cache atılır ve hata loglanır.

---

## 10. Maliyet Modeli ve Free Tier Matematiği

### 10.1 Supabase Free Tier

| Kaynak | Limit | DMT Tüketim Tahmini |
|---|---|---|
| **MAU (Monthly Active Users)** | 50,000 | ≤ 1k kullanıcı için bol bol yeterli |
| **Database** | 500 MB | event_log büyür; 30 gün retention ile ~50k session = ~200MB |
| **Storage** | 1 GB | Sadece avatar/küçük asset; büyük dosyalar R2'da |
| **Realtime concurrent WS** | 200 | ~33 paralel session × 5-6 WS = ~180-200 |
| **Auth API requests** | Sınırsız | — |
| **Bandwidth (egress)** | 5 GB/ay | event payload küçük; tahminen 100MB/ay |

**Per-session WS gerçek tüketim:** DM + 4-5 player + 1 observer ≈ **5-6 WebSocket**. 200 limitle paralel **~33-40 oyun masası** desteklenir.

### 10.2 Cloudflare R2 + Worker Free Tier

| Kaynak | Limit | DMT Tüketim Tahmini |
|---|---|---|
| **R2 Storage** | 10 GB | Ortalama 50 MB/`.dmt` paket × 200 paket = 10 GB |
| **R2 Class A ops** (writes) | 1M/ay | DM upload nadir; ~100/gün = 3k/ay |
| **R2 Class B ops** (reads) | 10M/ay | Asset download yoğun; ~5k/gün = 150k/ay |
| **R2 Egress** | **0$** (zero egress) | — |
| **Worker requests** | 100k/gün | Asset proxy: ~5k/gün; rate limit ile sıkı |
| **KV operations** | 1k/gün | Rate limit counter: 1 read + 1 write per download = ~10k/gün ⚠️ |

> ⚠️ **KV op limit dikkat:** Free tier KV write 1k/gün → ~50 download/gün limit gibi gözükür. Gerçekte rate limit counter 1 saatlik bucket olduğu için aynı kullanıcıya yapılan ardışık download'lar tek write yapar (TTL refresh). Production'da Workers KV alternatifi olarak Durable Objects veya R2 metadata kullanılabilir.

### 10.3 Yıllık Tahmini Maliyet (Free Tier İçinde)

| Kullanıcı sayısı | Aylık maliyet |
|---|---|
| ≤ 100 DAU (alpha) | **$0** |
| 100–500 DAU (beta) | **$0** |
| 500–1,000 DAU | **$0** (yakın limit) |
| 1,000–5,000 DAU | **$5-25/ay** (Workers Paid + Supabase Pro) |
| 5,000–10,000 DAU | **$25-75/ay** + bandwidth |

### 10.4 Ücretli Plana Geçiş Kriterleri ve Maliyetleri

**Supabase Pro (`$25/ay`):**
- 100k MAU, 8 GB DB, 100 GB storage, **500 concurrent WS**
- Tetikleyici: > 200 concurrent WS aşımı (≈ 33+ paralel session)

**Cloudflare Workers Paid (`$5/ay`):**
- 10M req/ay, no rate limit on KV (?)
- Tetikleyici: > 100k Worker req/gün

**R2 Standard:**
- $0.015/GB-month storage
- $0 egress
- Tetikleyici: > 10 GB asset

**Toplam ölçeklenme tahmini:**
- 1k DAU: **$30/ay** (Supabase Pro + Workers Paid)
- 10k DAU: **$100/ay** + storage
- 100k DAU: **$500-1000/ay** (custom enterprise plan)

---

## 11. Failure Modes & Recovery

| Failure | Detection | Recovery |
|---|---|---|
| **Supabase down** | Health check fail / WS reject | `NoOpNetworkBridge` fallback → offline mode; UI badge "Offline (Server unreachable)" |
| **R2 throttle (429)** | Worker 429 response | Local cache fallback, exponential backoff retry, alternatif asset göster |
| **Worker offline** | DNS fail / 503 | Asset hizmeti erişilemez; offline mode; mevcut cache çalışmaya devam |
| **DM disconnect** | WS heartbeat fail (> 30s) | Player'lar son snapshot ile **read-only** moda geçer; DM döndüğünde sync resume |
| **Player disconnect** | WS heartbeat fail | Auto-reconnect (exp backoff) → delta resync (revision) veya snapshot fallback |
| **JWT expire** | Worker 401 | `supabase_flutter` SDK refresh token ile auto-renew → request retry |
| **Asset not found** (R2 404) | Worker 404 | Placeholder image; log; asset_missing event |
| **Network partition** (mobile) | ICE failure | Fallback: Supabase relay (slower but works) |
| **Drift schema corruption** | SQLite open error | `.dat.bak` legacy fallback; migration log; user prompted to reimport |
| **Rate limit hit** | Worker 429 | UI toast: "Çok hızlı indiriyorsunuz, 1 saat bekleyin"; retry-after header |
| **Stale snapshot** (revision drift) | Server detects stale revision | Snapshot fallback otomatik tetiklenir (>200 event eşiği) |

---

## 12. Implementation Status (Flutter)

> Son güncelleme: 2026-04-09

| Bileşen | Dosya | Durum |
|---|---|---|
| `EventEnvelope` Freezed | `lib/domain/entities/events/event_envelope.dart` | ✅ Tamamlandı |
| `EventTypes` (24 sabit) | `lib/domain/entities/events/event_types.dart` | ✅ Tamamlandı |
| `GameSnapshot` Freezed | `lib/domain/entities/events/game_snapshot.dart` | ✅ Tamamlandı |
| `AppEventBus` (interceptor pattern) | `lib/application/services/event_bus.dart` | ✅ Tamamlandı |
| `appEventBusProvider` | `lib/application/providers/event_bus_provider.dart` | ✅ Tamamlandı |
| `NetworkBridge` interface | `lib/data/network/network_bridge.dart` | ✅ Tamamlandı |
| `NoOpNetworkBridge` | `lib/data/network/no_op_network_bridge.dart` | ✅ Tamamlandı |
| `SessionManager` interface | `lib/data/network/session_manager.dart` | ✅ Tamamlandı |
| `NoOpSessionManager` | `lib/data/network/no_op_session_manager.dart` | ✅ Tamamlandı |
| Network Riverpod providers | `lib/data/network/network_providers.dart` | ✅ Tamamlandı |
| **Drift SQLite (11 tablo)** | `lib/data/database/` | ✅ Tamamlandı (schema v2) |
| `CampaignRepositoryImpl` (Drift + legacy) | `lib/data/repositories/campaign_repository_impl.dart` | ✅ Tamamlandı |
| `supabase_flutter` SDK entegrasyonu | `pubspec.yaml` | ⏳ Bekliyor (Sprint 9) |
| `SupabaseAuthService` | `lib/application/services/auth_service.dart` (yeni) | ⏳ Bekliyor |
| `SupabaseNetworkBridge` impl | `lib/data/network/supabase_network_bridge.dart` (yeni) | ⏳ Bekliyor |
| `SupabaseSessionManager` impl | `lib/data/network/supabase_session_manager.dart` (yeni) | ⏳ Bekliyor |
| `GameSession` Freezed model | `lib/domain/entities/game_session.dart` (yeni) | ⏳ Bekliyor |
| `StateSnapshotService` (capture/restore) | `lib/application/services/state_snapshot_service.dart` (yeni) | ⏳ Bekliyor |
| Auth UI (login/register) | `lib/presentation/screens/auth/` (yeni) | ⏳ Bekliyor |
| Session create/join UI | `lib/presentation/screens/session/online_*.dart` (yeni) | ⏳ Bekliyor |
| Connection status badge | `lib/presentation/widgets/connection_badge.dart` (yeni) | ⏳ Bekliyor |
| `AssetService` (upload/download) | `lib/data/network/asset_service.dart` (yeni) | ⏳ Bekliyor (Sprint 10) |
| **Cloudflare Worker** (TypeScript) | `cloudflare/worker.ts` (yeni dizin) | ⏳ Bekliyor (Sprint 10) |
| **Supabase migration SQL** | `supabase/migrations/*.sql` (yeni dizin) | ⏳ Bekliyor (Sprint 10) |
| Mobile WebRTC screen share | `flutter_webrtc` + service | ⏳ Bekliyor (Sprint 11) |

---

## 13. Roadmap & Sprint Entegrasyonu

| Sprint | Konu | Online katmanına katkı |
|---|---|---|
| **Sprint 9 — Foundation** | Supabase Auth + Realtime + Session create/join | Sub-faz 8a: Bridge impl, auth UI, session UI, snapshot service |
| **Sprint 10 — Sync + Assets** | R2 + Worker + delta sync + asset pipeline | Sub-faz 8b: AssetService, Worker yazımı, audio trigger pattern, reconnect flow |
| **Sprint 11 — Mobile + Polish** | WebRTC mobile screen share + permission filtering | Sub-faz 8c: flutter_webrtc, Cloudflare TURN, restricted entity view |
| **Sprint 12 — Deployment** | Production deploy + integration tests + beta | Supabase production project, Worker deploy, R2 bucket, monitoring |

Detaylı task listesi: `docs/FLUTTER_DEVELOPMENT_ROADMAP.md` Sprint 9–12.

---

## 14. Açık Sorular ve Trade-off'lar

| # | Soru | Trade-off | Sprint |
|---|---|---|---|
| **Q1** | Supabase Pro maliyeti yönetilebilir olmazsa, self-host alternatifi (PocketBase + MinIO) keşfedilmeli mi? | Yönetim kolaylığı vs maliyet kontrolü; PocketBase'in Realtime olgunluğu Supabase kadar değil | Sprint 12+ |
| **Q2** | Community market için Stripe entegrasyonu? | Para akışı = legal complexity; ücretsiz tutmak gönül rahatlığı sağlar | Sprint 12+ |
| **Q3** | DM private notes için **end-to-end encryption** ister miyiz? | Crypto kompleksitesi vs gerçek gizlilik (RLS yeterli mi?) | Sprint 11+ |
| **Q4** | Mobile WebRTC TURN sunucusu için Cloudflare Calls'a güvenelim mi yoksa coturn self-host mu? | Cloudflare = $0 free tier ama beta; coturn = stable ama VPS maliyeti | Sprint 11 |
| **Q5** | Supabase tablo şeması production'da nasıl migrate edilecek? | Manuel SQL migration vs Supabase CLI; backwards-compat zor | Sprint 12 |
| **Q6** | `.dmt` paketleri için versiyonlama nasıl olacak? | Semver mi, schema_version+date mi? | Sprint 10 |
| **Q7** | Player anonymous join'de display_name unique olmalı mı? | UX collision vs ek tablo | Sprint 9 |
| **Q8** | Snapshot capture 500+ entity ile yavaş olursa? | Lazy hydration vs full snapshot; partial sync? | Sprint 10 |

---

## 15. Sözlük

| Terim | Tanım |
|---|---|
| **EventEnvelope** | Wire format — tüm online ve offline event'ler bu Freezed zarfa sarılır. UUID, type, timestamp, payload içerir. |
| **EventTypes** | 24 string sabitten oluşan enum-benzeri sınıf; `EventTypes.entityCreated` gibi. `onlineEvents` set'i bridge'e forward edilecekleri belirler. |
| **NetworkBridge** | Soyut interface. `NoOpNetworkBridge` (offline default) ve `SupabaseNetworkBridge` (online) implementasyonları arasında geçiş yapar. |
| **AppEventBus** | StreamController tabanlı pub/sub. Notifier'lardan event toplar, lokal listener'lara dağıtır, opsiyonel olarak `_networkInterceptor` üzerinden bridge'e forward eder. |
| **DM as Source of Truth** | DM'in lokal `dmt.sqlite` veritabanı tek doğruluk kaynağıdır. Server hiçbir oyun state'ini değiştirmez; sadece relay yapar. |
| **Snapshot** | Tam game state'in tek seferlik fotoğrafı (`GameSnapshot` Freezed class). Player join'de veya >200 event reconnect'te kullanılır. |
| **Delta Sync** | Revision-based artımlı event replay. `event_log` tablosundan kullanıcının son revision'undan sonraki event'ler çekilir. |
| **Worker** | Cloudflare Worker — V8 isolate üzerinde edge function. JWT verify + RLS check + R2 stream yapar. |
| **RLS** | Row Level Security — Postgres feature. Her query otomatik olarak `auth.uid()` filter'ı uygular. |
| **Broadcast Channel** | Supabase Realtime'ın fire-and-forget WebSocket kanalı. Veritabanına yazmaz, sadece relay eder; ucuz ve hızlı. |
| **Trigger Pattern** | Audio'da: dosya pre-cached, sadece JSON command broadcast. Sıfır audio streaming. |
| **Hibrit Online** | Offline-first + opt-in online (her iki mod da tam çalışır). Online katmanı kaldırırsanız uygulama hala fonksiyonel. |
| **Drift** | Reaktif Dart ORM (eski adı moor); SQLite üzerinde tip-güvenli query, transaction, code generation. |
| **state_json blob** | `campaigns` tablosunda TEXT kolon — henüz normalize edilmemiş alanlar (combat_state, map_data, mind_maps) JSON olarak saklanır. |
| **`.dmt` paket** | Tam kampanya snapshot'ı: ZIP arşiv = manifest + MsgPack data + assets. Paylaşım/yedek/market için. |
| **`.dmt-template` paket** | Sadece world schema (kategori + alan tanımları); entity'ler içermez. Yeni kampanya başlangıcı için. |
| **Join code** | 6-char alfanumerik session kodu (örn. "ABC123"). DM session create ederken üretilir, player join için yeterlidir. |
| **SoLoud** | `flutter_soloud` paketi — game audio engine; gapless loop, built-in fade, CPU-side mixing. |

---

## 16. Versiyon Geçmişi

| Versiyon | Tarih | Değişiklikler |
|---|---|---|
| **v2.0** | 2026-04-09 | **Major rewrite** — Drift + Supabase + Cloudflare R2/Worker mimarisine geçiş; profesyonel teknik rapor formatı; Implementation Status, Failure Modes, Open Questions, Glossary bölümleri eklendi. ASCII diyagramlar ve concrete API contract'lar dahil edildi. |
| v1.0 | 2026-03 | İlk vizyon dokümanı (FastAPI + PostgreSQL + Redis + MinIO + python-socketio tabanlı). 67 satır, yüzeysel. |

---

> 💡 **Geri bildirim:** Bu rapor canlı bir dokümandır. Mimari kararlar değiştikçe versiyon arttırılır. Önerileriniz için GitHub issue açın veya `/bug` slash command'ı ile bildirin.
