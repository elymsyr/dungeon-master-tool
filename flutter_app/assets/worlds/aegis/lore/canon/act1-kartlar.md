# Act 1 — Kart Listesi

> **Durum: çalışma listesi.** [`act1.md`](act1.md)'nin yazım listesinin (§8) açılmış hali:
> uygulamada **hangi kartların** oluşturulacağı. İçerik burada yazılmaz, sadece sayılır.
> Act'tan bağımsız kartlar (giriş kartı, background, evren lore'u) →
> [`genel-kartlar.md`](genel-kartlar.md).

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
@[Kulübe](entity:location/Kulübe)   @[Cerrahi iğne](entity:trinket/Cerrahi İğne)
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
| **Bulut'un Hanı** | Gümüşsu | 🟡 | §3 — sadece hancı yazılı, mekan değil |
| **Gizli Liman** | — | ✅ | §7 |
| **Rıhtım** | Gizli Liman | 🟡 | §7.4 — Fare'nin alanı; ayrı kart olmayabilir |

## 2. `npc` — 12

| Kart | Yer | Durum | Not |
|---|---|---|---|
| **Duran** · **Umay** · **Karaca** · **Bulut** | Gümüşsu | ✅ | act1.md §3 tablosu — üç satır hazır |
| **Toygar** · **Selvi** · **Demir** | Kulübe | ✅ | §5 — *1. gün hali*; her biri `monster` ikizli |
| **Sicim** · **Fare** · **Kaptan Vela** · **Kaptan Halim** | Gizli Liman | ✅ | §7.4 |
| **Konsey aracısı** | Gizli Liman | 🟡 | §7.4 — **adı yok** (M5 dağarcığı) |

**İki taşıyıcı açığı:** *kaydı kim sildirdi* şu an yalnız **Sicim**'de. İkinci
taşıyıcı olarak düşünülen lonca kadrosu bu kapsamın dışında kaldı → ya bu bilgiye
Gümüşsu/Gizli Liman içinden ikinci bir ağız bulunur, ya da bilgi bu iki bölümün
kapanışına taşınmaz. **Karar gerek.**

## 3. `monster` — 3

| Kart | Durum | Not |
|---|---|---|
| **Dönüşmüş Toygar** · **Dönüşmüş Selvi** · **Dönüşmüş Demir** | ✅ | act1.md §5 — aynı üç kişinin 2. gün hali; `npc` ikizine linkli |

Jenerik Blight yaratıkları act üstü → [`genel-kartlar.md`](genel-kartlar.md).

## 4. `scene` — 5

| Kart | Yer | Durum | Dayanak |
|---|---|---|---|
| **Köye varış** | Gümüşsu | ✅ | §3 |
| **Kulübe sorgusu** | Kulübe | ✅ | §5 — son konuşabilen hal |
| **Şafak dönüşümü** | Kulübe | ✅ | §5 |
| **Limana kabul** | Gizli Liman | ✅ | §7.1 — kefil / iş / yük |
| **Geçiş pazarlığı** | Rıhtım | ✅ | §7.2 — yazı ya da para |

## 5. `encounter` — 2

| Kart | Durum | Not |
|---|---|---|
| **Şafak çatışması** | ✅ | §5 — perdenin ilk savaşı |
| **Liman kaçışı** | ⬜ | tehdit ilan edilirse (§7.3) çıkabilecek sonuç |

## 6. `quest` — 3

| Kart | Durum | Not |
|---|---|---|
| **Söylentinin peşinde** | ✅ | giriş kancası — §1 sözleşmesinin karşılığı |
| **Nereden geldiler** | ✅ | ana hat: iğne → kayıtsız giriş → kaydı kim sildirdi |
| **Yol hakkı** | 🟡 | iyi yazı / iyi para (§9 açık 3–4) |

## 7. Act 1'e özgü eşya / prop — 3

| Kart | Kategori | Durum | Not |
|---|---|---|---|
| **Cerrahi iğne** | `trinket` | ✅ | §3 — üç kapının (bedensel/belgesel/kültürel) ortak nesnesi |
| **Sicim'in defteri** | `trinket` | 🟡 | §7.5 — prop mu kart mı belirsiz |
| **Kolye (pusula)** | `magic-item` | ⬜ | **act1.md'de geçmiyor**; 07 + README §1'de kanon. *Act 1'de var mı?* → karar gerek |

---

## Yazılmayacaklar (bilerek)

- **Karantina doktoru** (README §4.5) — act1.md §3 karantinayı kaldırdı, köyün kendi
  kararı var.
- **Mızrak parçası** — README §1: Act 1'de yok.

## Sayım

| Kategori | ✅ | 🟡 | ⬜ | Toplam |
|---|---|---|---|---|
| `location` | 3 | 2 | — | 5 |
| `npc` | 11 | 1 | — | 12 |
| `monster` | 3 | — | — | 3 |
| `scene` | 5 | — | — | 5 |
| `encounter` | 1 | — | 1 | 2 |
| `quest` | 2 | 1 | — | 3 |
| eşya/prop | 1 | 1 | 1 | 3 |
| **Toplam** | **26** | **5** | **2** | **33** |

Bugün yazılabilir olan: **26 kart.** Kalan yedinin önündeki engel içerik değil, karar.

---

## Sonraki bölümler için planlama

Yazılmayacak, sadece unutulmasın diye duruyor. Sırası geldiğinde kart olur.

**Lonca bölümü** — `location` Lonca · 4 `npc` (yetkili · kayıt memuru · ajan ·
borçlu esnaf) · `scene` Lonca kapısı. Engel: "iyi yazı" nedir (act1.md §9 açık 3).
Buraya *kaydı kim sildirdi*'nin ikinci taşıyıcısı düşecekti.

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

**Cinervik · Argenfon** — README §2 güzergah adları, içerik yok. Ayrıca *Argenfon*
(argentum + fons) ile *Gümüşsu* aynı anlama geliyor: aynı yerin iki dildeki adı mı,
iki ayrı yer mi → **ad kararı**, Adlandırma Doktrini'ne bakılacak.

**Tier 3 — `blueprint.json`** — dört pre-gen (Jaonos · Bızdır · Aly · Will), rol
yuvası başına bir tane. Faz 6; serbest yaratım kararından sonra zorunlu değil, örnek.
