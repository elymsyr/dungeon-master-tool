# Tier 0/1 içeriğinin otomatik paylaşımı

`updated: 2026-09-12`

## Problem

Bir oyuncu online dünyaya katıldığında `WorldJoinService` ona boş bir dünya
kabuğu + SRD core paketi bootstrap ediyor. DM'in **kendi yazdığı** kural
içeriği (homebrew sınıf, tür, geçmiş, feat, büyü, eşya) ise hiç gitmiyor —
`entity_shares`'te satırı yoksa oyuncunun cihazında yok.

Sonuç: DM "bu dünyada Tiefling yok, onun yerine şu var" dediyse oyuncu o kartı
göremiyor ve karakterini yanlış yaratıyor. 088 migration'ının kendi yorumu da
bu modeli bekliyor ("karakter yaratım kategorilerinin otomatik paylaşımı").

Bu bir sürpriz/spoiler problemi değil, **karakter yaratılabilirlik** problemi.

## Çözüm

DM dünyayı online'a aldığı anda, homebrew Tier 0 + Tier 1 kartları tek seferde
oyunculara paylaşılır. DM bir kez bilgilendirilir.

### Kapsam

Paylaşılan set: `linked == false` **ve** `categorySlug ∈ (tier0Slugs ∪ seedTier1Slugs)`.

- **`linked == true` kartlar kapsam dışı.** SRD ve kurulu add-on paketlerin
  kartları oyuncuda zaten var ve `visibleEntityProvider` kurulu paketin linked
  kartlarını zaten otomatik gösteriyor. Onlar için satır yazmak gereksiz olurdu
  ve 4000 satır/dünya tavanını (088) tek başına yakabilirdi.
- **`tier0Slugs`** (40 slug, `builtin/lookups.dart`) tamamen dahil — Tier 1'in
  relation alanlarının hedefi bunlar; eksik kalırlarsa kartlar yarım görünür.
- **`seedTier1Slugs`** = `tier1Slugs` eksi dört kategori:

  | çıkarılan | neden |
  |---|---|
  | `monster` | kampanyanın boss'u; oyuncunun karakter yaratmak için ihtiyacı yok |
  | `animal` | aynı |
  | `creature-action` | canavar stat block'unun parçası |
  | `magic-item` | loot spoiler'ı; DM verdiğinde paylaşır |

  Kalan 18: `class`, `subclass`, `species`, `subspecies`, `background`, `feat`,
  `spell`, `weapon`, `armor`, `tool`, `adventuring-gear`, `ammunition`, `pack`,
  `mount`, `vehicle`, `trinket`, `trait`, `starter-bundle`.

  Bu dört kategori bugünkü tekil "Paylaş" akışında kalır. Sabit adı
  `seedExcludedSlugs`, aşağıdaki yaratma-diyaloğu hizalaması da onu kullanır.

### Yaratma diyaloğunun hizalanması

`entity_sidebar._showCreateDialog` bugün yeni kartın "Share with players"
kutusunu Tier 0/1'de varsayılan **açık** getiriyor
(`shareOverride ?? _tierFor(selectedSlug) != 2`). Yani publish sonrası
yaratılan bir homebrew canavar veya büyülü eşya, seed'den çıkardığımız hâlde
kendiliğinden paylaşılıyordu.

Varsayılan aynı hizaya çekilir:

```dart
bool shareChecked() => shareOverride ??
    (_tierFor(selectedSlug) != 2 && !seedExcludedSlugs.contains(selectedSlug));
```

DM kutuyu elle işaretleyip yine paylaşabilir; değişen sadece varsayılan.
Kural tek cümleye iner: **canavar ve loot asla kendiliğinden gitmez.**

### Transitive closure istisnası

`shareEntityWithPlayers` relation alanları üzerinden transitive closure
yürütüyor ve closure'a giren her non-linked kartı paylaşıyor. Seed yolunda bu,
dışarıda bıraktığımız dört kategoriyi arka kapıdan içeri sokar (örn. homebrew
bir `species` kartı bir `monster`'a referans veriyorsa).

Seed yolu closure sonucuna da aynı kategori filtresini uygular. Sonuç: o
relation oyuncuda çözülmez, soft-ref olarak düşer ve `EffectiveCharacter`'a
warning yazılır — bu **doğru** davranış, oyuncu o canavarı görmemeli.

Tekil paylaşım yolunun closure davranışı **değişmez** (DM bir NPC'yi
paylaştığında bağlı her şey gitmeye devam eder).

### Tetikleyici ve idempotency

Tek tetikleyici: `online_world_section.dart` → `_publish()`, `pushOwnedCharacters`
çağrısının hemen ardından.

Bayrak gerekmiyor. `unpublishWorld` bulut dünyasını cascade ile siliyor
(`entity_shares` dahil), yani tekrar online olmak zaten sıfırdan başlıyor ve
seed'in tekrar çalışması doğru semantik. Online kalırken DM bir kartı unshare
ederse hiçbir şey onu geri diriltmez.

### DM bildirimi

Publish başarılı olduktan sonra tek `AlertDialog`:

> **Dünya içeriği oyuncularla paylaşıldı**
>
> Kendi yazdığın kural kartları (sınıflar, türler, geçmişler, feat'ler,
> büyüler, eşyalar ve bunların referans tabloları) oyuncularla paylaşıldı —
> karakterlerini doğru yaratabilmeleri için bunlara erişmeleri gerekiyor.
>
> Canavarlar, büyülü eşyalar, NPC'ler, sahneler ve görevler paylaşılmadı.
> İstediğin kartın paylaşımını kartın menüsünden tek tek geri alabilirsin.

`app_{en,tr,de,fr}.arb`'ye iki anahtar.

## Değişen dosyalar

| Dosya | Ne |
|---|---|
| `lib/application/services/entity_share_prepare.dart` | `shareEntityWithPlayers` imzası `entityId` → `Set<String> entityIds`; kuyruk set ile tohumlanır, `id != entityId` kontrolü `!entityIds.contains(id)` olur. Opsiyonel `allowedSlugs` filtresi (seed yolunda dolu, tekil yolda null). Yeni `seedTierContentToPlayers(ref, worldId)` giriş noktası. |
| `lib/domain/entities/schema/builtin/content.dart` | `seedExcludedSlugs` (dört slug) + `seedTier1Slugs` (= tier1Slugs eksi seedExcludedSlugs) sabitleri |
| `lib/presentation/widgets/entity_sidebar.dart` | `shareChecked()` varsayılanı `seedExcludedSlugs`'u dışlar |
| `lib/presentation/widgets/online_world_section.dart` | `_publish()` içinde seed çağrısı + bildirim diyaloğu |
| `lib/presentation/l10n/app_{en,tr,de,fr}.arb` | 2 anahtar |
| `test/application/services/entity_share_tier_seed_test.dart` | yeni |

Mevcut çağrı yerleri (`entity_card.dart:1670`, `entity_provider.dart:788`,
`entity_sidebar.dart:1267`) tek elemanlı set'e çevrilir — davranış aynı.

## Test

`entity_share_tier_seed_test.dart`:

1. Seçilen set homebrew Tier 0 + 18 Tier-1 kategorisini içerir.
2. `linked == true` kart seçilmez.
3. `monster` / `animal` / `creature-action` / `magic-item` seçilmez — **ne
   doğrudan ne de closure yoluyla** (bir `species`'ten `monster`'a relation
   veren fixture ile).
4. Tier 2 (`npc`, `scene`, `quest`) seçilmez.
5. Tekil paylaşım yolunun closure davranışı değişmemiştir (regresyon guard'ı).
6. Yaratma diyaloğu varsayılanı: Tier 0/1 açık, `seedExcludedSlugs` kapalı,
   Tier 2 kapalı; `shareOverride` her durumda varsayılanı ezer.

## Bilinen kabuller

- **Medya dalgası.** Homebrew kartların görselleri `missing_shas` üzerinden
  DM'den çekilir; publish anında bir yükleme dalgası olur. Tier 1 çoğunlukla
  metin olduğu için ucuz, ama homebrew tür/sınıf portreleri varsa hissedilir.
- **4000 satır tavanı.** Homebrew'a kısıldığı için pratikte birkaç düzine satır;
  aşırı büyük bir homebrew dünyada tavan görülebilir ve o durumda publish
  `check_violation` ile kısmen başarısız olur (hatalar `debugPrint` ile yutulur,
  publish'i düşürmez).
- **Yasaklama yok.** DM SRD içeriğini ("bu dünyada Fireball yok") gizleyemez —
  ayrı bir iş.
