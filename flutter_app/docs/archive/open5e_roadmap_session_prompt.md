# Oturum prompt'u — Open5e yol haritasını bitir

Her yeni chat'te aşağıdaki bloğu **olduğu gibi** yapıştır. Öncesinde modeli
**Opus 5 / high** yap (`/model` → Opus 5, reasoning effort: high) ve izin modunu
müdahalesiz çalışacak seviyeye al (`--permission-mode acceptEdits` / bypass).

---

Bu repoda tek hedefin var: `flutter_app/docs/open5e_content_audit.md` §6 yol
haritasını bitirmek. **Tam otonom çalış** — soru sorma, onay bekleme, plan modu
açma. Bu oturumda sıradaki **bir** açık fazı baştan sona bitir ve commit'le;
yarım iş bırakma.

## 0. Bağlam ve sınırlar

- Branch **`new-system-win`**. Yeni branch yok, PR yok, push yok, rebase/force yok.
  Tüm commit'ler doğrudan bu branch'e.
- `CLAUDE.md`'deki her kural geçerli. **Tek istisna:** bu görevde
  `codebase-memory` MCP'sini kullanma — kodu bulmak/anlamak için `vault/`
  kullan: `vault/Home.md` → `vault/00-Maps/_Architecture-Overview.md` →
  `vault/10-Files/<domain>/<basename>.md`. Not yoksa/bayatsa Read/Grep/Glob'a düş
  ve notu güncelle (vault SOP: `vault/90-Meta/SOP.md`).
- Komutlar `flutter_app/` içinden çalışır. Open5e snapshot'ı repo kökünde:
  `open5e-api-staging/` (yani `flutter_app`'ten `../open5e-api-staging/data`),
  pinned rev `d4276c586d79f2a27bf2b814aed151cf57605283`.

## 1. İlk iş: ne yapacağını seç

1. `flutter_app/docs/open5e_content_audit.md` — §0 "Start here" ve §6 Roadmap'i oku.
2. Açık kutulardan (`- [ ]`) **sıradaki tek fazı** seç. Sıra:
   **M4 → O1 → O2 → O3 → O4 → F0 → F1 → F2 → F3 → F4.**
   Stage F terminal adımdır; O bitmeden F'ye geçme.
3. Stage F fazlarındaysan bağlayıcı dosyalar: `pack_conformance_plan.md`
   ("Sonraki adım" bloğu + dalga sırası), `pack_conformance_checklist.md`,
   `pack_conformance_findings.md`. Altın kurallar orada — özellikle **K1: tarama
   sırasında hiçbir şey düzeltilmez**, bulgu yazılır; **K2: paket dosyası baştan
   sona okunmaz.** F0'ın "onay" çıkışını insan onayı bekleyerek kilitleme:
   checklist'i tamamla, dokümana gerekçeli kabul kaydı düş, ilerle.
4. Hiç açık kutu kalmadıysa: §6 "Done when"deki 4 çıktıyı **ölç** (tahmin etme).
   Yeşil olmayan her madde için §6'ya yeni bir `- [ ]` faz kutusu aç, çıkış
   kriterini yaz, sonra o fazı çalış.
5. Seçtiğin fazı ilk mesajında tek cümleyle bildir, sonra durmadan uygula.

## 2. Her fazın devraldığı üç kapı (§6 — pazarlık yok)

1. **Ref gate** — `dupe_census`'un "nothing installed" sayısı artamaz (baseline **0**);
   yazdığın her `_ref` mevcut içeriğe çözünmeli. §2'nin linkleme sözleşmesi her
   doldurma hedefinden üstündür: **kopya kart üreterek %100'e çıkmak regresyondur.**
2. **Reader gate** — doldurduğun her `_ref` alanının okuyucuları
   `resolveEntityRef` / `resolveEntityRefList` üzerinden gitmeli; gitmiyorsa faz
   ship edilmez (§2.3.1).
3. **Repo gate** — `flutter analyze` temiz, dokunduğun alanın testleri yeşil,
   ilgili `vault/10-Files/...` notu güncel ve `vault/90-Meta/Vault-Changelog.md`'ye
   bir satır eklenmiş.

## 3. Build / test / analyze — her fazda

`flutter` bu makinede PATH'te **değil**; SDK `C:\src\flutter\bin`. PowerShell'de
her oturumda bir kez:
`$env:PATH = "C:\src\flutter\bin;C:\src\flutter\bin\cache\dart-sdk\bin;$env:PATH"`

```sh
cd flutter_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # zorunlu: üretilen dosyalar gitignore'da
flutter analyze
flutter test <dokunduğun test dosyaları>
```

Mapper/asset/içerik dokunduysan ek olarak:

```sh
dart run tool/open5e_import/bin/audit_packs.dart
dart run tool/open5e_import/bin/gate_packs.dart
dart run tool/open5e_import/bin/dupe_census.dart
dart run tool/open5e_import/bin/verify_packs.dart --data ../open5e-api-staging/data
# rebuild ASLA assets/ üstüne değil — scratch dizine:
dart run tool/open5e_import/bin/build_packs.dart \
    --data ../open5e-api-staging/data --out ../.tmp/packs-rebuild \
    --rev d4276c586d79f2a27bf2b814aed151cf57605283
dart run tool/open5e_import/bin/diff_packs.dart --new ../.tmp/packs-rebuild
```

`build_packs` arg parser'ı yalnız `--k v` biçimini alır; `--out=X` sessizce yok
sayılır ve `assets/open5e_packs`'e yazar — dikkat.

**Test caveat (CLAUDE.md):** tam `flutter test` koşusunda değişikliğinle ilgisiz,
tabana ait çevresel hatalar var. Bir hatanın sana ait olup olmadığından emin
değilsen `git stash` ile temiz ağaçta aynı dosyayı koştur, **farkı** regresyon
say. Hedefli koşular tek güvenilir sinyaldir.

## 4. Hatalı kod bırakma

- `flutter analyze` hatasızsa **ve** dokunduğun testler yeşilse commit et; değilse
  ya düzelt ya değişikliği geri al ve dokümana "denendi, şu sebeple geri alındı"
  satırı yaz. Derlenmeyen/yarım kod ağaçta kalmaz.
- Geçici çıktı `.tmp/` altına veya sistem temp'ine. `assets/open5e_packs/` yalnızca
  faz kasıtlı olarak promote ediyorsa değişir; değişiyorsa `manifest.json`'ı da
  yeniden üret ve neyin değiştiğini `diff_packs` çıktısıyla dokümana yaz.
- Kullanıcıya görünen her string lokalize (`app_en.arb` → `tr`/`de`/`fr`).

## 5. Dokümanı güncelle — fazın parçası, ayrı iş değil

- İlgili kutuyu `- [x]` yap; yanına **"done YYYY-AA-GG"** ve **ölçülen** sayıları
  yaz (araç çıktısı, tahmin değil).
- Ölçüm bir varsayımı çürüttüyse onu da yaz — bu dosyanın üslubu budur:
  başarısızlıklar ve ters çıkan tahminler gizlenmez.
- Sayılar değiştiyse §0 "Start here" özetini ve etkilenen §3/§5 tablolarını güncelle.
- Stage F'deysen `pack_conformance_plan.md`'nin "Sonraki adım" bloğunu bir sonraki
  oturum için güncelle; bulgular `pack_conformance_findings.md`'ye.
- Faz tek oturumda kapanmayacak kadar büyükse: kutuyu **açık bırak**, fazın altına
  "bitti / kaldı" satırlarını yaz ki bir sonraki oturum tam oradan devam etsin.

## 6. Commit

- Sadece `new-system-win` üzerinde. Mesaj: `<faz kodu>: <ne yapıldı>`
  (örn. `M4: spell-slot table lands on the sheet`), gövdede ölçülen sayılar ve
  yeşil koşan komutlar.
- Mesajın sonuna:
  `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`
- Push yok, PR yok, branch değiştirme yok. `git status` temiz bırakılır
  (ürettiğin geçici dosyaları sil).

## 7. Kapanış çıktısı (kısa)

Hangi faz · ne ölçüldü/değişti · hangi komutlar yeşil · commit SHA · sıradaki faz.
