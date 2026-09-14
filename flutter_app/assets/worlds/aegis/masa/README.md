# `masa/` — oynanan oyunun kaydı

Aegis tasarlanırken **aynı anda oynanıyor.** Bu klasör o masanın kaydıdır:
hangi oturumda ne oldu, oyuncular neyi seçti, hangi olasılık gerçekleşti,
hangisi rafta kaldı.

> **Bu klasör kanon değil ve kart olmaz.**
> Ana [`README.md`](../README.md) §0'ın kanon hiyerarşisi bu klasörü hiç saymaz.
> `lore/canon/` dünyanın ne *olabileceğini* yazar; `masa/` bir masada ne
> *olduğunu* yazar. İkisi çelişirse kanon kazanır — çünkü kanon bir sonraki
> masaya da hizmet etmek zorunda.

Bu ayrım yeni değil: arşivdeki `Oyun_Durumu_Güncel` da oynanmış bir masanın
kaydıydı ve Proje Yönergesi §2 onu kanon saymadı — *"Eski oyun geçmişi, kitabın
kaynağı değil; kitabın test edilmiş bir örneğidir."* Aynı kural burada da
geçerli.

## Akış tek yönlü, bir istisnayla

```
lore/canon/  →  kartlar  →  masa       (her zaman)
masa         →  "Öneri / Fikir:"  →  lore/canon/   (onaydan sonra)
```

Masada doğan bir şey (bir ad, bir NPC, bir mekan, bir bağlantı) kanona
**doğrudan** geçmez. Ana README §6.7'nin uydurma yasağı burada da işler:
oturum kaydına yazılır, işe yaradığı görülürse ilgili kanon notuna
**"Öneri / Fikir:"** başlığıyla taşınır, onay gelince kanon olur.

Ters yön yok: masada bir sahne atlandı diye kart silinmez, masada bir NPC
öldü diye kart "ölü" yazılmaz. Kart bir olasılığı tarif eder; masa o
olasılığın bir örneğidir.

## Dosyalar

| Dosya | Ne |
|---|---|
| [`oturum-gunlugu.md`](oturum-gunlugu.md) | Masanın şu anki hali + oturum oturum kayıt + şablon |

## Neyi yazmaya değer

- **Ne oldu** — sırayla, kısa. Diyalog değil, olay.
- **Hangi olasılık kapandı** — kart üç yol açıyorsa masa hangisini yürüdü.
- **Kart ne söylemedi** — DM'in doğaçlamak zorunda kaldığı her yer bir
  tasarım geri bildirimidir; en değerli satır budur.
- **Ne tuttu** — oyuncuların üstüne atladığı ad, nesne, NPC.

## Neyi yazmaya değmez

Savaş tur tur, zar zar. Kim kaç hasar verdi. Bunlar bir daha okunmaz.
