# Act 1 — Kart Listesi

> **Durum: çalışma listesi.** [`act1.md`](act1.md)'nin yazım listesinin (§8) açılmış hali:
> uygulamada **hangi kartların** oluşturulacağı. İçerik burada yazılmaz, sadece sayılır.
> Act'tan bağımsız kartlar (giriş kartı, background, evren lore'u) →
> [`genel-kartlar.md`](genel-kartlar.md).

> ⚠️ **Paketle senkron değil.** `aegis-act1/world-blueprint.json` (0.1.0, 38 entity)
> **2026-09-09 revizyonlarından önce** üretildi: içinde hâlâ `trinket/Cerrahi İğne`
> var, üçlü "sivil yolcu" olarak yazılı, background · eşya · `curse` kartı yok.
> Bu listeler kanonu gösteriyor, paketi değil — blueprint bir sonraki üretimde bu
> kanona göre yeniden yazılacak.

**Kapsam:** şimdilik yalnız **Gümüşsu** ve **Gizli Liman**. Perdenin geri kalanı
(lonca, merkezi şehir, gemi, ufuk) en alttaki *Sonraki bölümler için planlama*
başlığında duruyor — orada kart yok, plan var.

**Ayrım kuralı:** bir kart yalnız Act 1'de anlamlıysa burada; her perdede geçerliyse
genel listede.

**Durum kodları:**
`✅` kanon var, yazılabilir · `🟡` kanon kısmi, bir karar eksik · `⬜` kanon yok —
önce README §4.2 kural 2 (karar al, sonra yaz).

**Kategori notu:** blueprint sözleşmesinde `item` diye bir kategori **yok**
(`world-blueprint.md` §3.25–3.33). Eşyalar `adventuring-gear` · `trinket` ·
`tool` · `weapon` · `magic-item` olarak yazılır.

---

## 0. İki yazım kuralı

**Adlar geçici.** Buradaki her özel ad değişebilir; hiçbiri kanon kilidi değil.
Bu yüzden ad, karttan başka **hiçbir yerde düz metin olarak geçmez.**

**Her ad bir link.** Kart gövdesinde (markdown alanlarında) başka bir karttan söz
ediyorsan entity linki kullan:

```
@[Sicim](entity:npc/Sicim)          @[Gizli Liman](entity:location/Gizli Liman)
@[Kulübe](entity:location/Kulübe)   @[Mühürsüz Yüzük](entity:trinket/Mühürsüz Yüzük)
```

Kural, ad değişimini ucuza indirmek için: link hedefi kartın adı olduğundan,
yeniden adlandırma tek bir string'in grep'i olur. Düz metinde geçen ad kaçar.

Asgari linkleme:

| Kart | Neyi linkler |
|---|---|
| `location` | üstünü (`parent_location_ref`) + içindeki NPC'ler |
| `npc` | bulunduğu yer + açtığı kapının kartı |
| `scene` | geçtiği yer + sahnedeki NPC'ler + tetiklediği `encounter`/`quest` |
| `quest` | zincirdeki her sahne ve her taşıyıcı NPC |
| `monster` | insan hali (`npc` ikizi) |

---

## 1. `location` — 5

| Kart | Üst (`parent_location_ref`) | Durum | Dayanak |
|---|---|---|---|
| **Gümüşsu** | — | ✅ | act1.md §3 |
| **Kulübe** | Gümüşsu | ✅ | §3 — karantina değil, köyün kendi kararı |
| **Bulut'un Hanı** | Gümüşsu | ✅ | §3.4 — mekan, fiyat, ne verdiği yazıldı |
| **Gizli Liman** | — | ✅ | §7 |
| **Rıhtım** | Gizli Liman | ✅ | §7.6 — ayrı kart (KARAR): liman bir *durum*, rıhtım bir *yer* |

## 2. `npc` — 12

| Kart | Yer | Durum | Not |
|---|---|---|---|
| **Duran** · **Umay** · **Karaca** · **Bulut** | Gümüşsu | ✅ | act1.md §3 tablosu — üç satır hazır |
| **Toygar** · **Selvi** · **Demir** | Kulübe | ✅ | §3.1 — iki halfling + bir tiefling, zengin yolcular, adları sahte. *1. gün hali*; her biri `monster` ikizli, `species_ref` SRD'ye |
| **Sicim** · **Fare** · **Kaptan Vela** · **Kaptan Halim** | Gizli Liman | ✅ | §7.4 |
| **Konsey Aracısı** | Rıhtım | ✅ | §7.4 — rıhtımın en iyi giyimlisi; lonca hattından PC **zarsız** tanır, diğerleri Insight DC 13. Adı sonra girer (M5), kart başlıkla yazılır |

**İki taşıyıcı açığı:** *kaydı kim sildirdi* şu an yalnız **Sicim**'de. İkinci
taşıyıcı için yer artık belli — **yüzüğü eğeleyen kuyumcu** (act1.md §3.3, §9 açık 4);
kart yazılmadı, adı yok. Ya o kuyumcu bir `npc` kartı olur, ya bilgi bu iki bölümün
kapanışına taşınmaz. **Karar gerek.**

*Yüzüğün kendisinin taşıyıcı açığı yok:* Investigation DC 15 · Jeweler's Tools ·
mühür taşıyan herhangi bir PC — üç kapı (act1.md §3.3).

## 3. `monster` — 3

| Kart | Durum | Not |
|---|---|---|
| **Dönüşmüş Toygar** (halfling, CR 1/2) · **Dönüşmüş Selvi** (halfling, CR 1/2) · **Dönüşmüş Demir** (tiefling, CR 1) | ✅ | act1.md **§5.1 — statblock'lar yazıldı.** Aynı üç kişinin 2. gün hali; `npc` ikizine linkli |

Üçü de jenerik **Dönüşmüş** gövdesinden türer (act üstü, genel-kartlar §7);
o kart yazıldığında bu üçü ondan `derived` sayılır, tersi değil.

## 4. `scene` — 5

| Kart | Yer | Durum | Dayanak |
|---|---|---|---|
| **Köye varış** | Gümüşsu | ✅ | §3 |
| **Kulübe sorgusu** | Kulübe | ✅ | §5 — son konuşabilen hal |
| **Şafak dönüşümü** | Kulübe | ✅ | §5 |
| **Limana kabul** | Gizli Liman | ✅ | §7.1 — kefil / iş / yük |
| **Geçiş pazarlığı** | Rıhtım | ✅ | §7.2 — yazı ya da para |

## 5. `encounter` — 1

| Kart | Durum | Not |
|---|---|---|
| **Şafak çatışması** | ✅ | §5 — perdenin ilk savaşı; statblock'lar §5.1, toplam 400 XP |

## 6. `quest` — 2

| Kart | Durum | Not |
|---|---|---|
| **Söylentinin peşinde** | ✅ | giriş kancası — §1 sözleşmesinin karşılığı |
| **Nereden geldiler** | ✅ | ana hat: **yüzük** → kayıtsız giriş → kaydı kim sildirdi (act1.md §3.3 zinciri) |

## 7. Act 1'e özgü eşya / prop — 1

| Kart | Kategori | Durum | Not |
|---|---|---|---|
| **Mühürsüz Yüzük** | `trinket` | ✅ | act1.md §3.3 — perdenin kanıtı; üç kapının (bedensel/belgesel/kültürel) ortak nesnesi. *Cerrahi iğne'nin yerine geçti (§3.2)* |

Background eşyaları (13 kart) act'a özgü değil → [`genel-kartlar.md` §4](genel-kartlar.md).

## 8. `curse` — 1

| Kart | Durum | Not |
|---|---|---|
| **Blight — Enfeksiyon** | ✅ | act1.md §4 — evreler, DC'ler, tedavi yazıldı. Perdenin **tek** kural sapması. Act'a özgü değil ama ilk burada masaya çıkıyor; sayım genel listede |

---

## Yazılmayacaklar (bilerek)

- **Karantina doktoru** (README §4.5) — act1.md §3 karantinayı kaldırdı, köyün kendi
  kararı var.
- **Mızrak parçası** — README §1: Act 1'de yok.
- **Cerrahi iğne** — act1.md §3.2'de **kaldırıldı.** Yerine `Mühürsüz Yüzük`.
- **Üçlünün gerçek adları** — act1.md §3.1: bilerek yazılmıyor.
- **Sicim'in defteri** (KARAR 2026-09-09, 2. tur) — sahnede duran prop; ayrı karta
  ihtiyacı yok, §7.5'in metni yetiyor.
- **Kolye (pusula)** (KARAR) — Act 1'de **yok.** Karar verilene kadar yokmuş gibi
  davranılır; kart yazılmaz.
- **Liman kaçışı** `encounter` (act1.md §7.3) — doğaçlanır, üç sabit doğru kartın
  yerine geçiyor.
- **Yol hakkı** `quest` (act1.md §7.2) — yol serbest; fiyatı olan tek şey gemiye
  binmek, o da `scene/Geçiş pazarlığı`.

## Sayım

| Kategori | ✅ | 🟡 | ⬜ | Toplam |
|---|---|---|---|---|
| `location` | 5 | — | — | 5 |
| `npc` | 12 | — | — | 12 |
| `monster` | 3 | — | — | 3 |
| `scene` | 5 | — | — | 5 |
| `encounter` | 1 | — | — | 1 |
| `quest` | 2 | — | — | 2 |
| eşya/prop | 1 | — | — | 1 |
| `curse` | 1 | — | — | 1 |
| **Toplam** | **30** | **0** | **0** | **30** |

**Act 1 listesinde bekleyen kart kalmadı — otuzu da bugün yazılabilir.** Açık kalan
tek şey kart değil, bir NPC boşluğu: yüzüğü eğeleyen kuyumcu (yukarı bak).

---

## Sonraki bölümler için planlama

Yazılmayacak, sadece unutulmasın diye duruyor. Sırası geldiğinde kart olur.

**Lonca bölümü** — `location` Lonca · 4 `npc` (yetkili · kayıt memuru · ajan ·
borçlu esnaf) · `scene` Lonca kapısı. Engel: "iyi yazı" nedir (act1.md §9 açık 3).
Buraya *kim ödedi* cevabı düşüyor — zincirin ucu (act1.md §3.3).

**Merkezi şehir** — `location` + 4 `npc` (meclis üyesi · muhafız · söylenti taşıyan ·
bastırılan tanık) · `scene` Meclis oturumu (kurumsal sessizlik). Engel: **şehrin adı
yok** (M0.5 Latin listesi).

**Resmi liman / Elymsyr** — Gizli Liman'ın alternatif yolu. İki liman gerçekten
gerekli mi, yoksa Gizli Liman tek mi kalsın → karar.

**Gemi** — `location` Gemi (kapalı mekan) · `scene` Gemi bölümü (kim hasta, kim ne
biliyor) · `environmental-effect` Gemi ambarı · `encounter` Deniz karşılaşması
(M0.6'ya bağlı: abluka ne zaman).

**Perde kapanışı** — `scene` Ufuk / ikinci kıta görüntüsü (06 #12). Kart mı sahne mi
belirsiz.

**Votumar (Paladin Şatosu)** ve **Ravenhall Avlusu** — README §2 güzergahında var ama
act1.md'de hiç geçmiyor. Act 1'de yer alıyorlar mı → karar.

**Cinervik · Argenfon** — README §2 güzergah adları, içerik yok. *Argenfon*
(argentum + fons) ile *Gümüşsu* aynı anlama geliyor: aynı yerin iki adı mı, iki ayrı
yer mi → **ad kararı.** (Dil ayrımı kanon olmaktan çıktı, act1.md §3; bu artık bir
doktrin sorusu değil, tek bir yer sorusu.)

**Tier 3 — `blueprint.json`** — dört pre-gen (Jaonos · Bızdır · Aly · Will), rol
yuvası başına bir tane. Faz 6; serbest yaratım kararından sonra zorunlu değil, örnek.
