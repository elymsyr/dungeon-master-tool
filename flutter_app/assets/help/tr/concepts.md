# Parçalar Nasıl Birleşir

## Yapı taşları

- **Şablon**: bir oyun sisteminin iskeleti. Hangi **kategorilerin** (Canavar, Büyü, Mekan…) olduğunu, her kategorinin **alanlarını** ve düzenini belirler. [Şablonlar](help:templates)
- **Kart**: bir kategorideki tek kayıt; bir NPC, bir büyü, bir kılıç. Kart yalnızca alan değerlerini tutar; ne anlama geldiklerini ve nasıl görüneceklerini şablon belirler.
- **Dünya**: bir kampanya. Kartlarını ve kampanyanın kullandığı her şeyi tutar: haritalar, zihin haritaları, karşılaşmalar, PDF'ler, sesler. [Dünyalar](help:worlds)
- **Paket**: etrafında kampanya olmayan bir kart paketi, örneğin bir canavar kitabı. Dünyalara aktarılır. [Paketler](help:packages)
- **Karakter**: şablonun oyuncu kategorisiyle kurulan oyuncu karakteri. Bir dünyaya ait olabilir. [Karakterler](help:characters)

## Nasıl bağlanırlar

- Her dünya ve paket bir şablonla kurulur ve şablonun **kendi kopyasını taşır**. Şablonu silmek ya da değiştirmek onları bozmaz. Kendi şablonundaki değişiklikler, dünya bir sonraki açılışta güncelleme teklifi olarak gelir.
- Paket aktarınca kartları dünyaya gelir. Paketten gelen kart, dünyada düzenlenene kadar paketin güncellemelerini izler.
- Kartlar birbirine metindeki `@` bahsetmeleriyle ve kart bağlantısı alanlarıyla bağlanır (karakterin sınıfı, canavarın aksiyonları).

## Kurallar nereden gelir

Yerleşik **D&D 5e (SRD 5.2.1)** şablonu SRD içeriğiyle (büyüler, canavarlar, eşyalar, sınıflar, türler…) ve kural mantığıyla gelir: adım adım karakter oluşturucu, seviye atlama, dinlenmeler, kağıttan zar atma.

Bu şablonda karakter kağıdı **her açılışta hesaplanır**, karakterin bağlı olduğu kartlardan: tür, sınıf, alt sınıf, geçmiş, feat'ler, ekipman. Bir feat kartını değiştirirsen o feat'e sahip her karakter de değişir. Karakterin ihtiyaç duyduğu bir kart yoksa (paketi kaldırıldıysa) kağıt yine açılır ve bir uyarı gösterir.

Kendi şablonlarında kural motoru yoktur. Boş bir kağıt, rehber, seviye tabloları, verilenler ve senin kurduğun dinlenmeler gelir. [Kendi karakter kağıdın](help:free-sheet)

## Veriler nerede durur

Asıl kaynak bu cihazdaki yerel veritabanıdır. Bir dünyayı ya da paketi çevrimiçi yapınca senkron tutulan bir bulut kopyası eklenir; başka hiçbir şey cihazdan çıkmaz. [Kayıt ve verilerin](help:saving) · [Çevrimiçi oynamak](help:online-play)
