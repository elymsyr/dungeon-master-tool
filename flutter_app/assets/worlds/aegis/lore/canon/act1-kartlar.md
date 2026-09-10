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
| **Goodbarrel'ın Ocak Başı** | Gümüşsu | ✅ | §3.4 — mekan, fiyat, ne verdiği yazıldı |
| **Gizli Liman** | — | ✅ | §7 |
| **Rıhtım** | Gizli Liman | ✅ | §7.6 — ayrı kart (KARAR): liman bir *durum*, rıhtım bir *yer* |

## 2. `npc` — 12

| Kart | Yer | Durum | Not |
|---|---|---|---|
| **Duran** · **Umay** · **Corvin** · **Milo** | Gümüşsu | ✅ | act1.md §3 tablosu — üç satır hazır |
| **Alton Leagallow** · **Merla Tealeaf** · **Kromanna** | Kulübe | ✅ | §3.1 — karı koca halfling + tiefling kadın hizmetli-koruyucu, Vorstrand'dan gelen zengin bir hane. İki halflingin adı sahte, tieflinginki değil. *1. gün hali*; her biri `monster` ikizli, `species_ref` SRD'ye |
| **Sicim** · **Fare** · **Kaptan Caelynn** · **Kaptan Holg** · **Mine** | Gizli Liman | ✅ | §7.4 — lakaplılar kayıtsız, Caelynn kayıtlı olduğu için lakapsız. **Mine** (cüce kuyumcu) yüzüğü eğeleyen el — ⚠️ *işi yüzük kararına bağlı (§3.3, 4. tur); kişi durur, gizlediği değişebilir* |
| **Kadife** — konsey aracısı | Rıhtım | ✅ | §7.4 — rıhtımın en iyi giyimlisi; lonca hattından PC **zarsız** tanır, diğerleri Insight DC 13. Defterdeki adı **Halet Custar** — yani Askeri Hukuk koltuğunun limanda parası var |

**İki taşıyıcı açığı kapandı:** *kaydı kim sildirdi* artık iki yerde — **Sicim**
(defter) ve **Mine** (tezgah). Kuyumcu bir `npc` kartı oldu: klan adını söylemeyen
bir cüce, yani kayıtsız değil *kendini kayıttan düşürmüş* biri (act1.md §7.4).

*Yüzüğün kendisinin taşıyıcı açığı yok:* Investigation DC 15 · Jeweler's Tools ·
mühür taşıyan herhangi bir PC — üç kapı (act1.md §3.3).

## 3. `monster` — 3

| Kart | Durum | Not |
|---|---|---|
| **Dönüşmüş Alton** (halfling, CR 1/2) · **Dönüşmüş Merla** (halfling, CR 1/2) · **Dönüşmüş Kromanna** (tiefling, CR 1) | ✅ | act1.md **§5.1 — statblock'lar yazıldı.** Aynı üç kişinin 2. gün hali; `npc` ikizine linkli |

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
| **Mühürsüz Yüzük** *(ad geçici)* | `trinket` | ⚠️ | act1.md §3.3 iz 3 — **gizli cepte**, Investigation DC 15. Nesnenin var olduğu ve saklandığı kanon; **ne olduğu askıda (4. tur).** Yedek içerik: mühür yüzü eğelenmiş, ayar damgası taze Meridia. Karar verilince kart adı da değişebilir |

Background eşyaları (13 kart) act'a özgü değil → [`genel-kartlar.md` §4](genel-kartlar.md).

## 8. `curse` — 1

| Kart | Durum | Not |
|---|---|---|
| **Blight — Enfeksiyon** | ✅ | act1.md §4 — Hastalık Puanı, beş aşama, DC'ler, tedavi yazıldı. Perdenin **tek** kural sapması. Act'a özgü değil ama ilk burada masaya çıkıyor; sayım genel listede |

---

## Yazılmayacaklar (bilerek)

- **Karantina doktoru** (README §4.5) — act1.md §3 karantinayı kaldırdı, köyün kendi
  kararı var.
- **Mızrak parçası** — README §1: Act 1'de yok.
- **Cerrahi iğne** — act1.md §3.2'de **kaldırıldı.** Yerine `Mühürsüz Yüzük`.
- **Üçlünün gerçek adları** — act1.md §3.1: köyde yazılmıyor. Karşılığını Meclis'te
  buluyorlar ([`lonca-sehir.md` §6.3](lonca-sehir.md)), ayrı bir kart gerektirmiyor.
- **Altın kesesi ve boş parşömenler** (act1.md §3.3 iz 2) — SRD `Pouch` + `Paper`;
  evrene özel anlamı **bağlamda**, nesnede değil. Kart açmak boş kart açmak olurdu.
- **Hastalığın kaynağı** (act1.md §4.6) — Act 1'de adlandırılmıyor, kartı da yok.
  Arcana izi `curse` kartının `mechanical_notes` alanında duruyor.
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
| `npc` | 13 | — | — | 13 |
| `monster` | 3 | — | — | 3 |
| `scene` | 5 | — | — | 5 |
| `encounter` | 1 | — | — | 1 |
| `quest` | 2 | — | — | 2 |
| eşya/prop | 1 | — | — | 1 |
| `curse` | 1 | — | — | 1 |
| **Toplam** | **31** | **0** | **0** | **31** |

**Act 1 listesinde bekleyen kart kalmadı — otuz birinin hepsi bugün yazılabilir.**
Kuyumcu boşluğu da kapandı: **Mine**, otuz birinci kart.

---

## Sonraki bölümler için planlama

Yazılmayacak, sadece unutulmasın diye duruyor. Sırası geldiğinde kart olur.

**Lonca ve Lucid Triton** — artık plan değil, yazılmış kanon:
[`lonca-sehir.md`](lonca-sehir.md). Yedi lonca (`lore`), Konsey/Meclis ayrımı,
şehir tarifi, altı NPC ve 19 kartlık yazım listesi orada. Kalan engeller:
şehir **Lucid Triton**, lonca ve hane adları onaylandı. *Kim ödedi* cevabı da
oraya düştü — iki taşıyıcıyla (**Corin Sancar** + **Kildrak Ferrun**), yani zincir
kilitlenmiyor.

**Resmi liman / Elymsyr** — Gizli Liman'ın alternatif yolu. İki liman gerçekten
gerekli mi, yoksa Gizli Liman tek mi kalsın → karar.

**Gemi** — `location` Gemi (kapalı mekan) · `scene` Gemi bölümü (kim hasta, kim ne
biliyor) · `environmental-effect` Gemi ambarı · `encounter` Deniz karşılaşması
(M0.6'ya bağlı: abluka ne zaman).

**Perde kapanışı** — `scene` Ufuk / ikinci kıta görüntüsü (06 #12). Kart mı sahne mi
belirsiz.

**Votumar (Paladin Şatosu)** ve **Ravenhall Avlusu** — README §2 güzergahında var ama
act1.md'de hiç geçmiyor. Act 1'de yer alıyorlar mı → karar.

**Cinervik · Argenfon** — yazıldı: [`bolgeler.md`](bolgeler.md) §5 (yol köyü ·
kıyı köyü). Gümüşsu'dan ayrı yerler (`AE` §5'in üç köyü).

**Tier 3 — `blueprint.json`** — dört pre-gen (Jaonos · Bızdır · Aly · Will), rol
yuvası başına bir tane. Faz 6; serbest yaratım kararından sonra zorunlu değil, örnek.
