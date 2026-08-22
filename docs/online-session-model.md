# Online Session Model — Tasarım Notu

> **Durum:** fikir aşaması. Kod değişikliği yok; tartışma notu.
> **Tarih:** 2026-08-22

Bu doküman "make online / persistent online mirror" modelini **oturum (session) bazlı**
canlı oyun modeliyle değiştirme fikrini anlatır. Mevcut sistemin ve önerinin ne olduğunu,
çelişkileri ve açık kararları kaydeder.

---

## 1. Bugün ne var (kısaca)

- **"Make online"** kalıcı bir bulut yansıması yaratır: `publish_world` → `world_members`
  üyelik satırı → CDC → her cihazda `world_mirror_applier`. Dünya kalıcı olarak sunucuda
  yaşar, üyeler yazar, herkesin ekranına yansır.
- **Beta gate'i** yalnızca *publish* tarafında: oyuncular dünyaya beta'sız katılabiliyor
  (`redeem_world_invite`, `claim_character` herkese açık). Beta = 90 slot, admin onayı,
  100 MB cloud kota, 14 gün inaktivitede slot düşer.
- **Transient medya** (oturumda paylaşılan görseller/haritalar) zaten kotaya sayılmıyor
  (R2 LRU, `per-session_id`).
- **Marketplace** zaten snapshot tabanlı (`MarketplacePanel` → "Share to Marketplace");
  tek engel `marketplace_panel.dart:41`'deki beta check'i.
- **Yazma modeli:** bugün online bir dünyada üye *her şeyi* değiştirebiliyor (DM otoriter
  değil). Oyuncu kendi karakteri dışında kısıtlanmış değil.

## 2. Önerilen model

1. **Oturum açık değilken:** herkes kendi yerel verisini düzenler (karakter, mind map,
   dünya — hepsi). Senkronizasyon yoktur, "online" yoktur.
2. **DM oturum başlatır:** dünya/karakter/mind map/harita içeriği katılan oyunculara
   **live aktarılır**. Oturum boyunca DM'in değişiklikleri masaya canlı akar.
3. **Oturum bittiğinde:** kalıcı bulut kopyası yoktur. Oyuncular oturumda aldıkları
   durumu yerel olarak tutar; sonraki oturumda yeniden eşlenir.
4. **Yazma modeli tek-master:** oturumda dünyayı yalnızca DM değiştirir; oyuncular
   kendi karakterini oynar. (Bugünkünden **farklı** — bugün üye dünyayı da düzenler.)
5. **Beta'sız:** oyuncular ve DM, beta şartı olmadan oturum kurabilir/katılabilir.
6. **"Make online" ve online sync kaldırılır:** lokal sync kalır. Cloud kota (100 MB)
   ve cloud yedekleme kavramı tamamen biter — ya da ayrı bir karara bağlanır (bkz. §4).

### Marketplace değişiklikleri

- "Make online" adımı yok: dünya/paket/karakter vs. ne paylaşılacaksa **doğrudan**
  marketplace'e konur (beta gate'i kaldırılır).
- **Misafir (oturum açmamış) kullanıcılar marketplace'e girebilir** ama yalnızca
  **official** içerikleri indirebilir; kullanıcıların paylaştığı içerikleri göremez/indiremez.
- Yeni filtreler: **official** filtresi ve **18+ içerik** etiketi (bkz. roadmap).

## 3. Mevcut sistemle uyum (yapılabilirlik)

Önerinin büyük bölümü mevcut altyapının parçası veya kolayca türevi:

| Bileşen | Durum |
|---|---|
| Oyuncuların beta'sız katılımı | Zaten çalışıyor (invite + character claim açık) |
| Oturum medyası (görsel/harita) kotasız | Zaten çalışıyor (transient tier) |
| Marketplace direkt paylaşım | Snapshot altyapısı var; sadece beta check'i kaldırılacak |
| Oturum canlı aktarımı | CDC + mirror var ama **kalıcı üyelik** üzerine kurulu — ephemeral yapmak iş |
| Misafir + official-only RLS | Yeni; "official" tanımı netleşmeli |

## 4. Açık kararlar / çelişkiler

1. **"Session" ne demek?** Ephemeral mirror mu, yoksa presence + patch stream gibi ayrı
   bir canlı kanal mı? İkincisi projection/transient ile daha uyumlu ve daha basit.
2. **Cloud backup ne olacak?** "Online sync tamamen kalkar" derseniz kullanıcı verisi
   yalnızca cihazda kalır (telefon kaybı = veri kaybı). Öneri: "make online/publish"
   kavramını kaldır ama otomatik cloud yedeği ayrı değerlendir. Bu, 100 MB kaldırma
   isteğiyle çelişir — depolama maliyeti var.
3. **Upload tarafında abuse engeli:** kota ve beta onayı şu an spam filtresi görevi
   görüyor. Guest yalnız official indirebilir — iyi bir okuma filtresi, ama *yükleme*
   tarafına engel ne olacak?
4. **"Official" tanımı:** first-party catalog pack'leri mi, kurulabilir paketler mi?
   Guest RLS buna bağlı.
5. **Oturum dışı düzenleme + eşlenme:** oturum açılmadan yapılan yerel değişiklikler
   sonraki oturumda nasıl birleşir? DM-authoritative olduğundan çakışma yok, ama
   "oyuncu oturumda aldığı durumu yerelde değiştirdiyse" ne kazanır?