# Kendi Karakter Kağıdın

[Kendi şablonundaki](help:templates) karakterler nasıl çalışır. Uygulama senin kurallarını bilmez; kartları ve sayıları şablonun dediği gibi taşır, gerisini oyuncular okur.

## Oluşturmak

Böyle bir şablonla **Yeni karakter** önce bir not gösterir, sonra oyuncu kartının düzeninde 1. seviyede **boş bir kağıt** açar. Şablonda **Rehber** varsa adım adım götürür: alana kaydırır, vurgular ve adımın yazısını gösterir. **Geri**, **Kapat** (duraklatır; başlıktaki **Rehber** kaldığı yerden sürdürür), **Tamam**. Hiçbir şey zorunlu değil; bütün alanlar düzenlenebilir kalır.

Rehber editörde yazılır: her adım isteğe bağlı bir alan ve Markdown bir yazıdır. [Şablon editörü](help:template-editor)

## Seviyeler

- **Seviye**: karakterin ana seviyesi, oyuncu kartında.
- **Seviye tablolu** kategoriler (Sınıf, Alt sınıf…) satır satır bir şeyler verir. Her birinin bir modu var:
  - **Ayrı**: her kartın kendi seviyesi olur. **Seviye atla**'da böyle her kategoriden bir kart seçersin (ya da 1'den başlayan yeni bir kart eklersin). Multiclass böyle çalışır.
  - **Beraber**: kartlar ana seviyeyi izler; sonradan eklenen kart bütün satırlardan geçerek yetişir.
- **Seviye atla**: ana seviye +1, seçilen kartlar +1, yeni ulaşılan satırlar uygulanır, sonra bir **özet**: eklenen kartlar, Havuz'a gelenler, okunacak yazılar, değişen kaynaklar.

## Verilenler ve Havuz

- Bir kartın **Verilenler**'i (ve seviye tablosu satırları), kart taşıyıcının listelerinden birine girdiği anda, seviyeden bağımsız işler. Verilen kartlar kategorilerini alan listeye girer; verilen kartın kendi verilenleri de işler.
- Hiçbir listenin almadığı her şey **Havuz**'a düşer: önce kaynaklar (harcamak için kutucuğa dokun), sonra diğer öğeler, veren kartın adı altında. Havuz her seferinde kartlardan yeniden kurulur; saklanmaz.
- Aynı adlı kaynaklar: aynı karttan gelirse ulaşılan en yüksek satırınki geçer; farklı kartlardan gelirse maksimumu büyük olan geçer.

## Dinlenmeler

**Kısa dinlenme** ve **Uzun dinlenme**, oyuncu kartındaki Kaynak alanlarına, Savaş değerleri'ndeki HP'ye ve Havuz'daki her kaynağa o kaynağın ayarını uygular (doldur, boşalt, dokunma). Başka hiçbir şey değişmez; "hit dice harcayıp iyileş" gibi kuralları elle uygularsın.

## Savaşta

Karşılaşma kolonları şablonun Savaş değerleri'nden gelir. Her savaşçı değerlerin kendi kopyasını alır; oyuncu karakterine verilen hasar kağıda geri yazılır. [Oturum ve savaş](help:session)
