# Paket İçerik Uygunluk Checklist'i (Stage F0)

**Ne işe yarar.** `open5e_content_audit.md` yol haritası uygulandı, ama içerik çok:
**19 official paket · 21.839 varlık** + **built-in SRD paketi · 2.719 varlık**
(2.350 Tier-1 + 369 Tier-0). Yol haritası kuralları koydu; bu dosya o kuralları
**tek tek bakılabilir maddelere** çeviriyor. Paket paket geçerken sorulacak soru
listesi budur.

**Üç dosya, üç iş:**

| Dosya | İş |
|---|---|
| `pack_conformance_checklist.md` (bu dosya) | **Ölçüt** — neyin doğru sayıldığı |
| `pack_conformance_plan.md` | **Süreç + ilerleme** — hangi paket, hangi sırayla, nasıl okunacak |
| `pack_conformance_findings.md` | **Bulgular** — ne eksik çıktı, ne yapılacak |

**Bu taramanın altın kuralı: hiçbir şey düzeltilmez.** Bulgu bulunur, yazılır,
sonra danışılır. Düzeltme ayrı bir iş kalemidir (bkz. plan dosyası, F4).

---

## Her madde nasıl okunur

Her maddede beş parça var:

- **Kural (teknik)** — tam ölçüt. Alan adları, araç adları, sayılar burada.
- **Nasıl bakılır** — hangi komut / hangi dosya. Kanıt buradan gelir.
- **Ne demek** — aynı şeyin sade anlatımı.
- **Örnek** — ✅ doğru hâli / ❌ yanlış hâli.
- **Kaynak** — yol haritasında bu kuralı koyan faz (§ numarası veya faz kodu).

## Verdict sözlüğü

Yol haritasının §1 işaretleriyle aynı — yeni bir dil uydurulmuyor:

| | Anlam |
|:--:|---|
| ✅ | Uygun |
| 🟡 | Kısmen — bir kısmı uyuyor, gerisi bulgu |
| 🔴 | Uygun değil |
| ⚠ | Dolu ama her satırda **aynı sabit** — mapper kaynağı okumak yerine default yazmış |
| ⚪ | Kaynakta karşılığı yok — doldurulamaz |
| ⛔ | Politika gereği bilerek boş |
| ➖ | Bu pakete uygulanmaz (o kategori paketin içinde yok) |

🔴 ve 🟡 verdict'i **her zaman** bir cause code alır (yol haritası §1):
`S` kaynakta yok · `L` dosya yüklenmiyor · `M` mapper yazmıyor ·
`D` kopya/link olmalı · `P` bilerek atlandı · `N` app alanının karşılığı yok.

---

# A — Kimlik ve yapı

Paketin içindeki kart, "kart" sayılabilecek şekilde mi duruyor?

### A1 — Her kategori slug'ı built-in şemada tanımlı

- **Kural (teknik).** Paketteki her varlığın `category` slug'ı
  `generateBuiltinDnd5eV2Schema()` içindeki bir `EntityCategorySchema`'ya karşılık
  gelmeli. Tanımsız slug import sırasında sessizce düşer.
- **Nasıl bakılır.** `flutter test test/application/services/pack_install_roundtrip_test.dart`
  (V2) zaten bunu iddia ediyor; paket bazında doğrulamak için pakette geçen
  `category` değerlerinin tekil listesini çıkar ve şemayla karşılaştır.
- **Ne demek.** Paket "şu bir büyü" diyor; uygulamanın "büyü" diye bir kutusu
  olmalı ki içine koyabilsin. Kutu yoksa kart yok olur, hata da vermez.
- **Örnek.** ✅ `spell`, `monster`, `creature-action` · ❌ `spell-variant` (şemada
  yok → 0 kart görünür, sessizce).
- **Kaynak.** V2 (`pack_install_roundtrip_test`), §6 Stage V.

### A2 — Kategorinin zorunlu alanları dolu

- **Kural (teknik).** `FieldSchema.required == true` olan her alan, o kategorinin
  **her** varlığında dolu olmalı. `audit_packs` bunu "declared / filled" sütunu
  olarak sayıyor.
- **Nasıl bakılır.** `dart run tool/open5e_import/bin/audit_packs.dart --only <kategori>`
  → filled sütunu entity sayısına eşit mi.
- **Ne demek.** Bir büyünün seviyesi olmak zorunda. Yoksa kart yarım.
- **Örnek.** ✅ `spell.level` 371/371 · ❌ `skill.ability_ref` 0/18 (T2-1'den önceki
  hâli — zorunluydu, hiç yazılmamıştı, sihirbazdaki yetenek çipi hiç render
  olmamıştı).
- **Kaynak.** §3.1 alan sayımı, T2-1.

### A3 — Uydurma değer yok

- **Kural (teknik).** Kaynakta karşılığı olmayan bir alan **boş kalır**; mapper
  makul görünen bir değer türetemez. `verify_packs`'in `unsourced` kovası bunu
  sayar; her `unsourced` alanın `verify.dart`'ta beyan edilmiş bir kuralı olmalı.
- **Nasıl bakılır.** `verify_packs --only <kategori> --examples 10` → `unsourced`
  satırlarının hepsi kuralı olan alanlar mı, yoksa mapper'ın icadı mı.
- **Ne demek.** "Bilmiyorsan boş bırak." Uydurulmuş bir değer, boş bir alandan
  kötüdür: boş alan görünür, uydurma değer doğru sanılır.
- **Örnek.** ❌ B11'in kapattığı `hp_dice`: kaynakta yokken `2d8` gibi bir değer
  üretiliyordu. ❌ B6'nın sildiği 159 `adventuring-gear` stub'ı: `cost_cp` /
  `weight_lb` tamamen uydurmaydı, kategori komple silindi. ✅ `trait.trait_kind`
  = `Other`: kaynak sütunu **8.613 satırın hepsinde null**, o yüzden sabit kalması
  doğru — ve bu gerekçe §3.6'ya yazıldı.
- **Kaynak.** B6, B11, V1, §3.6.

### A4 — Ad ve yazım kuralı

- **Kural (teknik).** Kart adları `normalize.dart`'ın `titleCaseName`'inden geçmeli
  — iç bağlaçlar küçük kalır. `findEntityIdByName` **büyük/küçük harfe duyarlı**;
  yanlış yazım = çözülmeyen ref = düşen içerik.
- **Nasıl bakılır.** Örneklem okumada ada bak; şüphede built-in paketteki yazımla
  karşılaştır.
- **Ne demek.** "Spare The Dying" ile "Spare the Dying" uygulama için **iki ayrı
  şey**. Yanlış yazan taraf hiçbir şeye bağlanamaz.
- **Örnek.** ❌ `toh` paketi `"Spare The Dying"` yazdı → korpüs `"Spare the Dying"`
  yazıyor → soft ref düştü; 198 gate ihlalinin sonuncusu buydu. ✅ L3'ün
  `titleCaseName`'i.
- **Kaynak.** L3, §0.

### A5 — Dolu ama tek sabit olan sütun yok (⚠ tuzağı)

- **Kural (teknik).** Bir sütun %100 dolu ama **her satırda aynı değer** ise, bu
  kapsama değil default'tur. Ya kaynakta gerçekten tek değer vardır (yazılı
  gerekçe gerekir) ya da mapper okumamıştır.
- **Nasıl bakılır.** `audit_packs` çıktısındaki ⚠ işaretli satırlar; şüphede
  o alanın tekil değer sayısını say.
- **Ne demek.** "%100 dolu" yanıltıcı olabilir. Hepsi aynıysa hiçbir şey
  söylemiyordur.
- **Örnek.** ✅ `feat.category_ref` hepsi "General" — ama `Feat.type` sütunuyla
  73/73 uyuşuyor, yani **kaynaklı**; gerekçesi §3.6'da. ❌ Aynı görüntü,
  gerekçesi olmayan bir alanda → bulgu.
- **Kaynak.** §1 status markers, V1, §3.6.

---

# B — Bağlantı (asla kopyalama, bağla)

Yol haritasının en sert kuralı burada: **uygulamanın zaten sahip olduğu içeriği
paket yeniden getirmez.**

### B1 — Built-in paketin birebir getirdiği kart, official pakette olmaz

- **Kural (teknik).** Eşleme kuralı: **aynı `(kategori, ad)` + aynı metin.**
  Yalnız ad yeterli değil. İki taraf da boş metinliyse eşleşme **yok**
  (kanıt yokluğu kanıt değildir). Parantez soyma yok.
- **Nasıl bakılır.** `dart run tool/open5e_import/bin/dupe_census.dart --list-builtin-same`
  → A bölümü "same text" **0** olmalı.
- **Ne demek.** Gömülü SRD zaten her kurulumda var. Aynı kartı paket de
  getirirse kullanıcı listede iki tane görür.
- **Örnek.** ✅ L4'ün sildiği 7 kart (*Nimble Escape* ×2, *Teleport (Blink Dog)*,
  *False Appearance (Gargoyle)*, *Hold Breath (Octopus)*, *Speak with Beasts and
  Plants*). ❌ A5E'nin kendi "Fireball"ını silmek — **adı aynı, metni farklı**:
  1.643 ad çakışmasının 1.636'sının metni farklı çıktı. Ad-bazlı silme
  kullanıcının A5E içeriğini yok ederdi.
- **Kaynak.** L1, L4, §2.1, §2.5.

### B2 — Aynı kart iki official pakette durmaz — **ama sahibi olan satır taşınmaz**

- **Kural (teknik).** B1'in aynı kuralı paketler arasında. **İstisna, ölçülmüş
  bir istisna:** kopyaların neredeyse tamamı bir statblock'un **kendi çocuk
  satırı** (`trait` / `creature-action`); bunlar taşınmaz. L4 ölçümü: 189 addan
  **188'i** çocuk satırı, tam iki paket çiftinde (`tob` ⟷ `tob-2023`: 174,
  `a5e-mm` ⟷ `bfrd`: 13).
- **Nasıl bakılır.** `dupe_census --list-shared` → üç kova; yalnız "unowned
  identical text" kovası gerçek adaydır.
- **Ne demek.** İki canavarın ısırığının metni aynı olabilir; ama her ısırık
  **kendi canavarına** ait. Birini silip diğerine bağlarsan, sahibi olan paket
  kurulu değilken o canavarın ısırığı **kaybolur**.
- **Örnek.** ✅ `tob`'daki "Bite (Amphiptere)" `tob`'da kalır, `tob-2023`'teki
  `tob-2023`'te. ❌ Alfabetik slug ile sahip seçip diğerini bağlamak — L4 bunu
  bilerek **uygulamadı**.
- **Kaynak.** L4, §2.5, `dupe.dart` içindeki `kBundledSharedPolicy`.

### B3 — Düzyazıda duran şey ref olmalı

- **Kural (teknik).** Kaynakta bir varlığa işaret eden metin varsa, o metin
  `*_ref` / `*_refs` alanına **de** yazılmalı — düzyazı korunur, tipli alan
  eklenir.
- **Nasıl bakılır.** `audit_packs --only <kategori>` → ref alanının doluluk oranı;
  0% ise ya kaynak yok (⚪) ya da mapper yazmıyor (`M`).
- **Ne demek.** "Bir wizard büyüsüdür" cümlesi kullanıcıya güzel görünür ama
  uygulama onunla filtre yapamaz. Filtre için tipli alan lazım.
- **Örnek.** ✅ L3: `spell.class_refs` 0 → **1.204 / 1.297 (%92)**. ⚠ Aynı ölçüm
  şunu da gösterdi: 1.297 paketli büyünün **1.212'si yalnız `tags` üzerinden**
  görünüyor, `class_refs` üzerinden 0 — yani `tags` bir yedek değil, **tek yol**du.
- **Kaynak.** L3, U2, §2.3.

### B4 — Her ref çözülür

- **Kural (teknik).** Sert ref (`*_ref` → uuidv5) paket içinde build-time
  çözülür ve **dangle edemez** — `build_packs` düşer. Yumuşak ref (`{slug, name}`)
  okuma anında çözülür; çözülmezse sessizce düşer ve `EffectiveCharacter`'da
  uyarı olarak görünür.
- **Nasıl bakılır.** `dart run tool/open5e_import/bin/gate_packs.dart` → 0 ihlal.
  `dupe_census` C bölümü → "nothing installed" **0**.
- **Ne demek.** Kartın işaret ettiği şey gerçekten var olmalı. Yoksa kullanıcı
  boşluğa dokunur.
- **Örnek.** ✅ Bugünkü hâl: C bölümü 4.074 ref / **0 dangling**. ❌ L3 öncesi:
  1 dangling (`"Spare The Dying"`).
- **Kaynak.** T3, §2.3, §6 "her faz üç kapı miras alır" #1.

### B5 — Paket→paket bağı iki anahtarla beyan edilir

- **Kural (teknik).** Bir paket başka bir paketin içeriğine bağlanıyorsa
  `metadata.links` **ve** `requires` dolu olmalı — ikisi birden, biri değil.
- **Nasıl bakılır.** Paketin `metadata` bloğunu oku (küçük, güvenli okuma).
- **Ne demek.** "Bu paket şu pakete muhtaç" bilgisi yazılı olmazsa, kullanıcı
  eksik paketle kurar ve içerik yarım gelir.
- **Örnek.** ✅ Bugün 19 paketin hepsinde `requires: []` — ve bu **doğru**: L2
  ölçtü, hiçbir paket başka bir pakete bağlanmayı hak etmedi (bağlamak, tek
  satırlık bir dil kartı için 2,9 MB'lık Tome of Beasts'i indirtmek olurdu).
  Kriter "boş olmasın" değil, **"boşsa yazılı bir sebebi olsun"**.
- **Kaynak.** L2, §2.2.

---

# C — Alan doluluğu (kategori kategori)

`audit_packs` bugün **408 beyan edilmiş (kategori, alan) yuvasının 136'sını**
dolu görüyor. Bu bölüm, o 136'nın doğru 136 olup olmadığını sorar.

### C1 — `class` / `subclass`: seviye tablosu var mı

- **Kural (teknik).** `class.features` ve `subclass.features` dolu; her feature
  satırı `granted_at_level` taşıyor. B1 sonrası: `class.features` 2/2,
  `subclass.features` 100/101, 572 seviye satırı.
- **Nasıl bakılır.** `audit_packs --only class,subclass`; ardından pakette varsa
  1–2 subclass'ı tam oku.
- **Ne demek.** Alt sınıf doğru sınıfa bağlanıp **hiçbir şey vermiyorsa** işe
  yaramaz. Bu, denetimin bulduğu en keskin hataydı: 101 subclass, 0 grant.
- **Örnek.** ✅ `granted_at_level: 3` olan bir "Path of the Berserker" özelliği
  3. seviyede sayfada beliriyor. ❌ Feature listesi boş bir subclass.
- **Kaynak.** B1, §5.1, §5.2.

### C2 — `species` / `subspecies` / `background` / `feat` alanları

- **Kural (teknik).** §5.3–§5.5'teki satırların her biri. Bilinen kalıcı boşlar:
  `species.age`, `background.starting_gold_gp`, üç `feat` pick-count anahtarı —
  bunlar §5.8'de 🔴 `M` olarak duruyor, yani **açık iş**, kapanmış değil.
- **Nasıl bakılır.** `audit_packs --only species,subspecies,background,feat`.
- **Ne demek.** Karakter yaratmada kullanılan kategoriler bunlar. Buradaki
  boşluk doğrudan sihirbazda görünür.
- **Örnek.** ✅ `background.equipment_choice_groups` dolu → sihirbaz ekipman
  seçtiriyor. ❌ `species.age` düzyazıda duruyor, alanda yok.
- **Kaynak.** B3, B7, §5.3–§5.5, §5.8.

### C3 — `spell` alanları

- **Kural (teknik).** `level`, `school_ref`, `casting_time`, `range`, `components`,
  `duration`, `class_refs`, `tags`; ayrıca T2-3'ün built-in tarafında açtığı dört
  alan: `area_shape_ref` / `area_size_ft`, `at_higher_levels_text`,
  `reaction_trigger`.
- **Nasıl bakılır.** `audit_packs --only spell` + 5 büyüyü tam oku.
- **Ne demek.** Büyü kartı, DM'in masada bakacağı şey. Alan eksikse düzyazıyı
  okumak zorunda kalır.
- **Örnek.** ⚠ Dikkat edilecek asimetri: `at_higher_levels_text` built-in'de
  109/341, **Open5e mapper'ı bu alanı hiç doldurmuyor** (upcast metnini
  açıklamaya katlıyor). Yani paketli büyülerde bu alan boş olabilir ve bu
  **bilinen** bir fark — bulgu yazılırken bu not edilmeli.
- **Kaynak.** B4, T2-3, §5.6.

### C4 — `monster` + `trait` + `creature-action`

- **Kural (teknik).** Her canavarın **en az bir aksiyonu** olmalı (T3 kuralı);
  `size_ref` çözülmeli; her çocuk satır (`trait`, `creature-action`) **tam bir**
  ebeveyn tarafından `_ref`lenmeli, öksüz olmamalı.
- **Nasıl bakılır.** `gate_packs` → 0 ihlal. `audit_packs --only monster`.
- **Ne demek.** Aksiyonsuz canavar, DM'in kullanamayacağı canavardır.
- **Örnek.** ❌ B8 öncesi: `open5e-tob3`'ün **397 canavarının 396'sının hiç
  aksiyonu yoktu** — alan sayımı bunu göremiyordu, ilişkisel kapı gördü.
  ✅ B8 sonrası: +1.286 aksiyon geri geldi.
- **Kaynak.** B8, B9, T3, §3.5, §3.8.

### C5 — `magic-item`

- **Kural (teknik).** `rarity`, `requires_attunement`, `charges`, `body_slot_ref`,
  `cost_gp`. Bilinen durum: `cost_gp` **1.063 satırın hepsinde 0.00** (kaynakta
  sütun yok → ⚪) ve attunement / charges / body-slot bloğu §5.8'de 🔴 `M`.
- **Nasıl bakılır.** `audit_packs --only magic-item` (`vom` paketi, 1.063 varlık).
- **Ne demek.** Fiyatı 0 görünen 1.063 eşya, "bedava" demek değil "bilmiyoruz"
  demek — ve UI bunu ayırt edemiyor.
- **Örnek.** ❌ `cost_gp: 0.00` her satırda → A5 maddesindeki ⚠ tuzağı.
- **Kaynak.** §5.6, §5.8.

### C6 — Grant bloğu ve `mechanical_notes`

- **Kural (teknik).** Kural taşıyan her kaynak satırı ya tipli bir grant alanına
  ya da `mechanical_notes`'a yönlendirilmiş olmalı. M2 ölçümü: **kural taşıyan
  kaynak satırlarının %100'ü** yönlendirildi, hiçbiri düşürülmedi.
  `class` / `subclass` / `background` grant bloğunu **taşımaz** — grant'ları
  tipli evlerinde durur (CLAUDE.md "one mechanic, one field").
- **Nasıl bakılır.** `flutter test test/domain/services/bundled_pack_resolve_test.dart`
  (M1) — bir alan ya sayfa probe'una düşer, ya `notResolverRead`'de, ya
  `unreadByAnyone`'da olur; başka seçenek yok, aksi hâlde test düşer.
- **Ne demek.** Kartın üstündeki kural ya karakteri gerçekten etkiler ya da
  "bu sadece metin" diye yazılı olarak beyan edilir. Arada kalan yok.
- **Örnek.** ⛔ Beyan edilmiş istisnalar: `spell.effects` /
  `creature-action.effects` (domain'de okuyucusu yok, kaynağı yapısal değil),
  `trait` / `magic-item` üzerindeki `mechanical_notes` (kartın kendisi zaten
  kuraldır, not birebir kopya olurdu).
- **Kaynak.** B5, M1, M2, M3, §5.7.

### C7 — Tier-0 kelime dağarcığı çözülüyor

- **Kural (teknik).** `size_ref`, `language`, `alignment`, `condition` gibi
  Tier-0 satırlar fixture pk üzerinden çözülmeli; serbest metin kalmamalı.
  `unmapped_report.json` bugün **3** satır.
- **Nasıl bakılır.** `assets/open5e_packs/unmapped_report.json` (küçük dosya,
  tam okunabilir).
- **Ne demek.** `thieves-cant` kullanıcıya `Thieves' Cant` diye görünmeli.
  Sadece baş harf büyütmek buna asla ulaşamaz — sözlük satırı gerekir.
- **Örnek.** ✅ B9: unmapped 144 → 70, `monster.size_ref` 2885/2885. ✅ B10:
  bileşik alignment normalize edildi, `verify_packs`'in `absent` kovası
  **ilk kez 0**.
- **Kaynak.** B9, B10, §2, §4 A1.

### C8 — Boş kalan her alanın yazılı bir sebebi var

- **Kural (teknik).** §5'te 🔴 veya 🟡 kalan her satır bir cause code taşır.
  Kod yoksa satır uygunsuzdur — "boş" olduğu için değil, **"hesapsız"** olduğu için.
- **Nasıl bakılır.** §5.8 politika tablosu + `audit_packs` çıktısı.
- **Ne demek.** Boş alan sorun değil; **sebebi yazılmamış** boş alan sorun.
  Çünkü sonraki kişi onu ya gereksiz yere kurcalar ya da hiç fark etmez.
- **Örnek.** ✅ `class.primary_ability_ref` her base class'ta `[]` — kaynakta
  sütun yok, ⚪ olarak yazılı. ❌ Aynı boşluk, tabloda hiç görünmüyorsa → bulgu.
  **Bugünkü açık:** §5'te 37 🔴 satır var; 12'sine §5.8 terminal sebep verdi,
  kalan **25'i 🔴 `M`** — hiçbir fazın sahiplenmediği düzyazı işi.
- **Kaynak.** §1 cause codes, §5.8, "Done when" #1.

---

# D — Doğruluk (kaynakla karşılaştırma)

Alan dolu olması, değerin **doğru** olması demek değil.

### D1 — Değer kaynakla aynı

- **Kural (teknik).** `verify_packs` her varlığın fixture satırını yeniden okuyup
  her alanı yargılar. Kabul çizgisi: **0 `disagree`, 0 `absent`.** Bugünkü hâl:
  68.561 `ok` / 0 / 0.
- **Nasıl bakılır.**
  `dart run tool/open5e_import/bin/verify_packs.dart --data ../open5e-api-staging/data --only <kategori> --doc <belge> --examples 10`
  (snapshot gerekir).
- **Ne demek.** Uygulamadaki değer, Open5e'nin gerçekten yazdığı değer mi.
- **Örnek.** ❌ `disagree` = mapper hatası, build'i düşürür. 🟡 `absent` = kaynakta
  var, pakette yok.
- **Kaynak.** T1, V1, §3.6.

### D2 — `unsourced` / `unverifiable` beyan edilmiş kuralla geliyor

- **Kural (teknik).** Bu iki kovadaki her alan `verify.dart`'ta bir `_Rule`
  taşımalı. Bugün 3.303 `unsourced` + 14.383 `unverifiable`, hepsi kurallı.
- **Nasıl bakılır.** Aynı komut; kovaların alan listesini `verify.dart` ile
  karşılaştır.
- **Ne demek.** "Doğrulayamadım" demek serbest değil — **neden**
  doğrulayamadığın yazılı olmalı.
- **Kaynak.** T1, V1.

### D3 — İlişkisel tutarlılık

- **Kural (teknik).** `gate_packs` kuralları: aksiyonsuz canavar yok, öksüz
  çocuk satır yok, her `parent_class_ref` çözülüyor, dangling soft ref yok.
  Çıkış: **0 ihlal** (198'den geldi).
- **Nasıl bakılır.** `dart run tool/open5e_import/bin/gate_packs.dart --examples 20`
- **Ne demek.** Tek tek her alan doğru olsa bile, parçalar birbirini tutmuyorsa
  içerik bozuk. Alan sayımı bunu **yapısal olarak** göremez.
- **Örnek.** ✅ 905 paylaşılan çocuk satır meşru şekilde paylaşılıyor
  (`_ensureChild` içerik-hash dedupe'u).
- **Kaynak.** T3, §3.8.

---

# E — Mekanik gerçekten iniyor mu

### E1 — Paketin yazdığı her mekanik alan sayfaya iniyor

- **Kural (teknik).** Her (paket, mekanik alan) çifti için ya bir sayfa iddiası,
  ya `notResolverRead` kaydı (okuyucusuyla birlikte), ya `unreadByAnyone` kaydı
  olmalı. Bugün: **73 çift, 247 sayfa iddiası, 1 kısmi.**
- **Nasıl bakılır.** `flutter test test/domain/services/bundled_pack_resolve_test.dart`
- **Ne demek.** Dosyada doğru yazması yetmez; karakter sayfasında **görünmeli**.
- **Örnek.** 🟡 Bilinen tek kısmi: `open5e-tdcs` `background.equipment_choice_groups`
  2/3 — bir grubun hiçbir eşyası çözülmüyor; kural "bir çift en az bir kez
  inmeli" olduğu için düşmüyor, raporlanıyor.
- **Kaynak.** M1, "Done when" #2.

### E2 — Mekanik olmayan, mekanik olmadığı için yazılı

- **Kural (teknik).** M3'ün beyan listesi. Yeni bir alan bu listeye eklenmeden
  mekanik dışı sayılamaz.
- **Ne demek.** "Bu sadece süs metin" demek serbest değil, imzalı olmalı.
- **Kaynak.** M3, §5.6, §5.7.

### E3 — Büyücülük ilerlemesi

- **Kural (teknik).** Kartın `spell_slots_by_level`'ı **override**'dır;
  varsayılan `caster_progression.dart`'ın `caster_kind`'dan hesapladığı SRD
  ilerlemesidir. Öncelik: **override > preset.**
- **Nasıl bakılır.** M4 (yol haritasında hâlâ açık olan tek faz).
- **Ne demek.** Paket kendi tablosunu vermezse SRD tablosu devreye girer; verirse
  onunki kazanır.
- **Örnek.** ✅ Korpüs taraması: tek iki paket sınıfı (`a5e-ag` Marshal,
  `bfrd` Mechanist) `caster_kind: 'None'` taşıyor — yani bugün preset'i sessizce
  miras alan **hiç kimse yok**. Paketli bir büyücü çıkarsa bu madde yeniden
  dosyalanır.
- **Kaynak.** T2-2, M4.

---

# F — İçerik kullanıcıya ulaşıyor mu

Buraya kadarki her kontrol paket JSON'unu **bellekte** okur. Bu bölüm gerçek
kurulum ve gerçek widget yolunu sorar.

### F1 — Kurulum gidiş-dönüşü kayıpsız

- **Kural (teknik).** Paket gerçek `PackagePayloadImporter` ile Drift DB'ye
  girip `PackageRepository.load` ile çıktığında: aynı varlık kümesi, her
  varlıkta aynı ad / tip / attribute, `installed_from` + `catalog_version` +
  kaynak metadata korunmuş, yeniden kurulum idempotent.
- **Nasıl bakılır.** `flutter test test/application/services/pack_install_roundtrip_test.dart`
- **Ne demek.** Dosyada olan şey, kurulduktan sonra da orada mı.
- **Örnek.** ✅ 19 paketin hepsi yeşil, sütun bölmesinde hiçbir şey kaybolmadı.
- **Kaynak.** V2.

### F2 — Her (kategori, alan) çifti çökmeden render oluyor

- **Kural (teknik).** Her çift, gerçek değeriyle, **hem salt-okunur hem
  düzenlenebilir** modda bir kez render edilmeli. Bugün 438 çift / 876 pump.
- **Nasıl bakılır.** `flutter test test/presentation/pack_field_render_test.dart`
- **Ne demek.** Kart açılırken uygulama çökmemeli. Bu test yazılana kadar hiçbir
  widget'a paket verisi hiç verilmemişti.
- **Örnek.** ❌ Bulduğu canlı çökme: `species.granted_senses` —
  `RangedSenseListFieldWidget` `row['sense_ref'] as String?` yapıyordu ama sense
  ref bir **soft ref Map**'i; her Dragonborn / Elf / Dwarf sayfası da çöküyordu,
  yani aslında built-in bir hataydı, paket işi onu sadece ortaya çıkardı.
- **Kaynak.** V2.

### F3 — Sihirbaz paketin satırlarını görüyor

- **Kural (teknik).** Chargen kategorisi taşıyan her paket için: paket built-in
  SRD'nin üstüne kurulur, adım okuyucuları paketin satırlarını listeler, o
  satırlardan bir taslak commit edilir. Bugün 12 paket / 39 vaka.
- **Nasıl bakılır.** `flutter test test/presentation/character_creation/wizard_pack_families_test.dart`
- **Ne demek.** Paketi kurdum, karakter yaratırken içeriğini seçebiliyor muyum.
- **Örnek.** ⚠ Aynı test şunu da ölçtü: 1.297 paketli büyünün **85'i bugün
  hiçbir yoldan görünmüyor**.
- **Kaynak.** U2, "Done when" #4.

### F4 — Karttaki her ref tıklanabilir link

- **Kural (teknik).** Salt-okunur ilişki değerleri `entityLinkTarget` →
  `resolveEntityRef` üzerinden geçmeli; **çözülmeyen ref link olmaz**, düz metin
  kalır (boş dialog açan link, linksizden kötüdür).
- **Nasıl bakılır.** `flutter test test/presentation/entity_link_navigation_test.dart`
- **Ne demek.** Büyü listesinde bir büyüye dokununca kartı açılmalı.
- **Örnek.** ❌ U3 öncesi: paketlenmiş büyü tıklanamaz değil, **görünmez**di —
  sunum katmanının okuyucuları `{slug, name}` zarfını tanımıyordu.
- **Kaynak.** U1, U3.

---

# G — Paketleme ve dağıtım

### G1 — Katalog metadata'sı güncel

- **Kural (teknik).** `emit.packVersion` (bugün `1.1.0`), `counts`, `size_bytes`,
  `r2_path` — hepsi son build ile aynı olmalı. `r2_path` **değişmez**, o yüzden
  içerik değiştiyse sürüm de ilerlemeli.
- **Nasıl bakılır.** `dart run tool/catalog_publish/bin/build_catalog.dart` →
  drift var mı.
- **Ne demek.** Kullanıcı "Güncelle" düğmesini ancak sürüm ilerlerse görür.
- **Kaynak.** D1, D2, §3.3.

### G2 — Lisans, yayıncı, kaynak metadata'sı doğru

- **Kural (teknik).** `publisher`, `license`, `game_system`, `is_srd_overlap`
  manifest'te ve paket `metadata`'sında tutarlı.
- **Ne demek.** OGL / CC-BY yükümlülüğü. Yanlış lisans etiketi hukuki sorun,
  teknik sorun değil.
- **Örnek.** `open5e-a5e-ag` → EN Publishing / `ogl-10a` / `a5e`.
- **Kaynak.** §3.3, §4 A2.

### G3 — SRD örtüşme politikası uygulanmış

- **Kural (teknik).** SRD-overlap atlaması **yayıncı geneli**, iki belge değil.
  `game_system` etiketleri (`5e-2014`, `a5e`, `5e-2024`) kartın hangi kurala göre
  yazıldığını taşır.
- **Ne demek.** WotC'nin kendi SRD'sini yeniden paketlemiyoruz; gömülü paket
  zaten o.
- **Kaynak.** §4 A2, §2.1.

---

## Checklist özeti (tek bakışta)

| # | Madde | Kanıt |
|:--|---|---|
| A1 | Kategori slug'ı şemada var | `pack_install_roundtrip_test` |
| A2 | Zorunlu alanlar dolu | `audit_packs --only` |
| A3 | Uydurma değer yok | `verify_packs` unsourced |
| A4 | Ad yazımı doğru | örneklem + built-in karşılaştırma |
| A5 | Tek-sabit sütun yok (⚠) | `audit_packs` ⚠ satırları |
| B1 | Built-in kopyası yok | `dupe_census --list-builtin-same` = 0 |
| B2 | Paketler arası kopya kart yok (çocuk satır hariç) | `dupe_census --list-shared` |
| B3 | Düzyazı yerine ref | `audit_packs` ref doluluğu |
| B4 | Her ref çözülür | `gate_packs` = 0, census C "nothing installed" = 0 |
| B5 | `links` + `requires` yazılı gerekçeli | paket `metadata` |
| C1 | class/subclass seviye tablosu | `audit_packs --only class,subclass` |
| C2 | species/background/feat alanları | `audit_packs --only …` |
| C3 | spell alanları | `audit_packs --only spell` |
| C4 | monster + çocuk satırlar | `gate_packs` |
| C5 | magic-item alanları | `audit_packs --only magic-item` |
| C6 | grant bloğu / `mechanical_notes` | `bundled_pack_resolve_test` |
| C7 | Tier-0 sözlüğü çözülüyor | `unmapped_report.json` |
| C8 | Her boşluğun cause code'u var | §5.8 |
| D1 | Değer kaynakla aynı | `verify_packs` 0 disagree / 0 absent |
| D2 | unsourced/unverifiable kurallı | `verify.dart` |
| D3 | İlişkisel tutarlılık | `gate_packs` |
| E1 | Mekanik sayfaya iniyor | `bundled_pack_resolve_test` |
| E2 | Mekanik olmayan beyan edilmiş | M3 listesi |
| E3 | Büyücülük ilerlemesi | M4 (açık) |
| F1 | Kurulum kayıpsız | `pack_install_roundtrip_test` |
| F2 | Render çökmüyor | `pack_field_render_test` |
| F3 | Sihirbaz görüyor | `wizard_pack_families_test` |
| F4 | Ref tıklanabilir | `entity_link_navigation_test` |
| G1 | Katalog metadata güncel | `build_catalog` |
| G2 | Lisans/yayıncı doğru | `manifest.json` |
| G3 | SRD örtüşme politikası | §4 A2 |

---

**Checklist onaylanmadan paket taramasına başlanmaz.** Onay geldiğinde
`pack_conformance_plan.md`'deki sıraya göre başlanır.
