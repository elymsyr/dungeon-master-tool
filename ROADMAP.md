# Roadmap

Tracked work for upcoming releases — bugs to fix and features to add. Items are grouped by type, not strictly ordered.

## Bugs

### `publish_listing_snapshot` RPC imzası uyumsuz
`publishSnapshot` çağrısı `p_lineage_id` parametresi olmadan yapılıyor ama DB'deki fonksiyon hâlâ `p_lineage_id` bekliyor. Sonuç: PostgREST `PGRST202` — "Could not find the function ... in the schema cache".

```
PostgrestException(message: Could not find the function public.publish_listing_snapshot(p_changelog, p_content_hash, p_description, p_item_type, p_language, p_listing_id, p_payload_path, p_size_bytes, p_tags, p_title) in the schema cache, code: PGRST202, hint: Perhaps you meant to call the function public.publish_listing_snapshot(..., p_lineage_id, ...))
```

Cloud sync overhaul kapsamında lineage tamamen kaldırılacağı için RPC imzasını yeni (lineage'sız) forma hizalamak gerekiyor — migration + client çağrısı birlikte güncellenmeli.

### `LandingScreen.dispose` sonrası `ref` kullanımı
Android'de `_LandingScreenState.dispose` içinde widget dispose edildikten sonra `ref.read` çağrılıyor ve Riverpod patlıyor:

```
Bad state: Cannot use "ref" after the widget was disposed.
#2 _LandingScreenState.dispose (landing_screen.dart:54)
```

`dispose` içindeki `ref` erişimini kaldır ya da dispose öncesinde snapshot'ını al.

### Mesajlaşma: `conversations` RLS ihlali
Yeni bir chat açılmaya çalışıldığında:

```
Could not open chat: PostgrestException(message: new row violates row-level security policy for table "conversations", code: 42501)
```

`conversations` tablosunun insert policy'si yeni konuşma oluşturan kullanıcıyı kapsamıyor. In-app messaging entegrasyonundan önce RLS policy'leri gözden geçirilmeli.

### Media gallery cloud senkronizasyonu eksik
- Bir entity'ye eklenen fotoğraflar world cloud'a atılıp başka cihazda indirildiğinde ne entity'de ne de media gallery'de görünüyor.
- World local'den silindiğinde cloud'dan da siliniyor — silinmemeli.
- Media gallery yedeklemesi otomatik olmamalı; sadece world yedeklenirken birlikte yedeklenmeli.
- World yedeklemesi media gallery'yi de kapsamalı.
- Silinen fotoğraflar cloud'dan geri indirilebilmeli (restore).

## Features

### Tutorial metinlerinin detaylandırılması
Uygulamanın her yerindeki tutorial/bilgilendirme metinleri tek tek gözden geçirilip her bölümü açıklayan, gerekirse detaylandıran şekilde genişletilecek. **Tüm uygulama dillerinde** eşdeğer içerik sunulmalı. Beta bilgilendirme yazısı da detaylandırılacak. Eklenecek temel kavram açıklamaları:

- **Worlds** — bir dünyanın tamamı; her şeyin buluştuğu ve tüm içeriği barındırabilecek yer. Sadece temel bir dünya yapısı indirip üstüne karakter/NPC ekleyerek oyun haline getirilebilir, ya da doğrudan bir oyun olarak kurgulanabilir. Worlds konusunda her şey serbest.
- **Templates** — oyunun en temel yapısını oluşturur. Amaç: farklı setting'leri oyuncuyla buluşturmak ve oyunculara custom setting design yapma ve paylaşma fırsatı sağlamak.
- **Packages** — bir setting/template üzerine, dünyaya direkt eklemek için oluşturulmuş kartlar. Örneğin hazır bir büyü paketi ya da şifalı bitki paketi oyuna direkt eklenip kullanılabilir.
- **Marketplace** — oyuncuların oluşturduğu içerikleri paylaşabilmesi için ücretsiz bir platform.

### Versiyon ekranında Markdown desteği
Sağ üstteki versiyon yazısına tıklandığında açılan içerik Markdown formatında render edilsin (changelog, release notes vb. düzgün görünsün).

### Uygulama içi bug report sistemi (Supabase)
Kullanıcıların doğrudan uygulama üzerinden bug report gönderebileceği bir akış. Supabase'e bağlanacak. Kurallar:

- Resim gönderme yok; sadece metin.
- Gönderilen bug raporları admin panelden görüntülenebilsin.
- Admin panelden gönderen kullanıcıya mesaj atılabilsin.
- Admin panelde her kullanıcının ne kadar depolama alanı harcadığı görünsün.
- Her kullanıcının en son ne zaman uygulamaya girdiği relative format ile gösterilsin (`1h`, `6h`, `1w`, `1mo`, `1y`...).

### Feed paylaşımlarına marketplace item eklenebilmesi
Feed bölümünde yapılan paylaşımlara, resim gibi, marketplace item'ları da eklenebilsin. Böylece bir paylaşım hem marketplace item'ını hem de içerik yazısını birlikte taşıyabilsin.

### Feed'de "Discover People" tab'ı
Feed'de marketplace kısmının yanına yeni bir tab eklenecek. Bu tab kullanıcı listesi gösterecek — amacı discover people / find new people tarzında bir sayfa ile insanların birbirini bulmasını sağlamak.

### Cloud sync overhaul
Replace the current snapshot/lineage flow with a simpler model:

- **Drop "Start fresh lineage" toggle** and version chaining entirely — every publish creates a fresh, independent snapshot. Users can manually delete old ones.
- **Multi-device change badge:** when an item that exists locally has been edited from another device, show a notification dot on the Settings icon. The intent is "you have cloud changes to pull," not version conflict resolution.
- Replace `marketplace_listings.lineage_id` / `is_current` / `superseded_by` columns and the related "update prompt / mute / dismiss" UI with this lighter flow.

### Package types
Today there is one generic package type. Split it into two distinct kinds:

- **Entity Card Pack** — current behavior (schema + entities).
- **Sound Pack** — opens directly into the Soundpad sidebar as the landing view. Users can add tracks from the pack straight into their personal library.

### In-app messaging integration
Wire the existing `messages_remote_ds` + Realtime channels into the actual Messages tab end-to-end: conversation list, unread state, real-time updates, send/receive, mobile layout.

### Profile pictures
Avatar upload + display across the app: profile screen, post author, message thread header, players list. Storage in the existing avatar bucket.

### In-app notification system
A unified in-app notification surface (badge + drawer/list). **First integration: messages** — unread DM count + per-message notifications. Designed so future sources (marketplace updates, follows, replies) can plug in.

### Global tag system
Tags entered in one place (e.g., a Game Listing) should be discoverable when other users create their own listings. Provide an autocomplete / suggestion list of existing tags so the same tag is reused instead of slight variants.

### World share includes bundled packages
When sharing a world, also snapshot any packages that have been imported into the template/world and ship them together as a single bundle, so the recipient gets a self-contained world without having to chase down dependencies.

### Template rule propagation into worlds
When a template's rules change, entering a world based on that template should detect the change and apply the updated rules to the world automatically.

### Online data cache layer
Cache online-side data (marketplace listings, shared content, etc.) locally instead of refetching from scratch every time. Invalidate on meaningful changes rather than on every view.

### Slot field type
A new field type: **slot**. Renders as a row of centered, theme-styled checkboxes with no inline text. The player can add as many slot checkboxes as they want to a given slot field. Include a refill button in the top-right of the field to reset all checkboxes at once. Intended for spell slots, ammo, charges, hit dice, etc.

### Rules system overhaul
The rules engine is the single most important upcoming work. Today's implementation is partial, inconsistent across field kinds, and not dynamic enough to express the situations players actually want to model. This section collects everything that needs to change.

**Current bugs**
- Rules do not fire uniformly across field types. Example: a rule that pushes spells from an item into the spell-slot field of an NPC who owns that item works. The analogous rule targeting the **actions** field does not fire, or only fires after a significant delay when the template is updated.
- Template updates are not reliably picked up by existing worlds/entities — rule re-evaluation after a template edit is lagging or missing entirely.

**New rule modes: `to be equipped` and `when equipped`**
Introduce two explicit rule phases so equipment logic can be modeled properly:
- **`to be equipped`** — predicates that gate *whether* an item can be equipped at all. Must be dynamic and composable. Examples:
  - Spell can only be equipped if caster level ≥ spell level.
  - Sword/staff can only be wielded if a given attribute (STR, INT, …) meets a threshold.
  - A spell requires Intelligence ≥ X to be prepared.
- **`when equipped`** — effects that apply *while* an item is equipped. Examples:
  - Cursed items that apply a condition while worn.
  - Items that grant +/- to an attribute, or add/remove conditions, only while equipped.
  - Items whose spells are injected into the owner's spell list only while held.

**Dynamic cross-field predicates**
Rules must be able to compare the contents of one field against another and drive presentation based on the result. Concrete target example:
- An NPC has an `Equipment` list field and a `Spell` list field.
- A spell entity has a `Necessary Items` field.
- Rule: *"In the NPC's spell list, render each spell in faded grey if any item in its `Necessary Items` is missing from the NPC's `Equipment` list."*

This generalizes to: "show items in list field A with style S if field B on each item is [subset of / equal to / disjoint from] field C on the containing entity." The rule builder needs to express set relationships between fields on different entities, not just flat value checks.

**Design goal**
The rule system should be fully dynamic — users compose predicates and effects from primitives (field references, set operations, comparisons, entity relationships) rather than picking from a fixed list of hard-coded rule templates. Treat this as a ground-up redesign of the rule builder, not an incremental patch.