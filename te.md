## Özellik Soundpad

Soundmap sistemini entegre etmeye başlayabiliriz. Soundmap themes, structured musics and intensity slider ekleyeceğiz. Tek basımlık sesler ve arka plan seslerini de entegre edeceğiz. Arayüz üzerinden custom müzik ekleme getireceğiz. Ayrıca, md dosyalarını ve qt sistemindeki soundmap özelliklerini iyi analiz et.

---

## Second Screen

Artık Player Screen bölümüne başlayabiliriz. Bu bölümde amacımız, DM tarafından ikinci bir ekran açılabilmesi ve bu ekranda session'dan resim/entity card/battle map paylaşılabilmesidir. Kullanıcı uygulamadki herhangi bir resme/entity card'a sağ tıklayarak project seçeneği ile projection yapabilecek. Aynı anda birden fazla resim/card ya da battlemap paylaşılabilmeli. Bu paylaşımlar arasında geçiş yapılabilmeli. Önce seçilen bu itemlerin ikinci ekranda nasıl efficient ve optimize bir şekilde gösterebileceğimizi hesapla. Sistem şuan yeterince hızlı çalışmıyor. Tab'lar arası geçişler hala yavaş. Yeni ekran sistemi hızlı çalışmalı.

İkinci ekran sistemi offline oyun öncelikli bir sistem. Online tarafta, her oyuncunun kendi arayüzünde tab'lar ile ekranlara bakılabilecek. Online tarafta bu kısımlar aynı anda paylaşılabileceği için sistemi buna göre düzenleyelim.

---

## Özellik Paket

Yeni bir özellik getiriyoruz: Paket. World ya da template gibi eklenecek. Paketler bir template üzerine oluşturulmuş entity card'ların tamamına deniyor. Örneğin bir dünya kurduğumuzda bu paketleri ekleyerek, dünyamıza hazır entity card'ları import edebileceğiz.

Bunun için önce her bir template için iki aşamalı hash sistemine geçmemiz lazım. Yani template'leri birbirine uygun olup olmadıklarına göre karşılaştırabilmeliyiz. Bazen template'ler birebir aynı olmasa da, bir paket bir dünyaya eklenebilir olabilir. Bu durumda karşılaştırmayı hızlıca yapıp, paketleri dünya içine aktarabilmeliyiz. Örneğin eklemek istediğimiz bir paketin orjinal template'inde bir kategoride fazladan bir field var. Bu durumda uyarı çıkararak bunu kullanıcıya söyleriz. Kullanıcı yine de paketi import etmek isterse, bu field eksik olarak kalan kısımlar import edilebilir. Kullanıcıların paket oluşturması için world ve template seçeneklerinin arkasına, paket bölümü ekleyeceğiz. Burada yine tmeplate seçenek girecek. Yalnızca Database Tab olacak. Database Tab'da değişiklik yapmamaıza gerek yok. Burada istediği gibi entity oluşturacak. undo redo operasyonları vs. aynı kalabilir. worlds kısmında ise, bir world'ü açtığında switch ve tema butonlarının yanına import package butonu ekleyeceğiz. Buradan packages içindeki paketleri seçip import edebilecek. Uygun olmayan paketleri ve neden uygun olmadıklarını görebilecek. Veya paket import edilebiliyor ama bazı field'ların eksik ya da fazla olma durumu var ise, yine bu kısımların neler olduğunu görebilecek. Paket sistemi kurallara bağlı değil. Template kısmındaki kurallar, paket sistemini ve import sistemini etkilemez. Bir paketi sildiğimizde yine trash kısmına gidecek.

---

## Online Tech Stack

Önemli bir konu var, oluşturduğumuz dünya, template vs. gibi bir çok şeyi yakında online'da tutmamız gerekecek. Şöyle bir şey yapalım, verilerin tutulma şeklini buna uygun olacak şekilde düzenleyelim. Bir dünyayı/templatei/paketi local'e tek bir dosya ya da klasör şeklinde export/import edebileceğiz. Gelecekte authentication ve veri senkronizasyonu için firebase kuracağız. Şimdilik plan şu, başlangıçta kullanıcılar büyük dosyaları (görsel, pdf vb) local'de tutacak, dünyaları ise online olarak kaydedebilecek. Daha sonraki planda, tüm veriler online olarak kaydedilebilecek ve senkronizasyon sağlanacak. Daha ileri aşamada artık bu verilein sosyal bir şekilde uygulama içinde paylaşılabilmesi sağlanacak. Öncelikle, bunun için nasıl bir sistem ve teknoloji stack kullanabiliriz, bunu tartışalım. Ardından uygun olacak şekilde, sistemi nasıl local'de kaydettiğimizi, trah klasörü yönetme vs. gibi kısımları düzenleyeceğiz. Şuan için sistem offline kalacak. Bunlar gelecek planlar yalnızca.

Tech stack seçerken şunlara dikkat etmeliyiz:

Social Media Feature: Oyuncular paket/world/template ya da durum paylaşabilecek. Birbirlerini arkadaş olarak ekleyebilecek. Birbirlerine mesaj atabilecek ya da session içinde grup mesajı yazabilecek.

Online Play Feature: Soundmap DM tarafından kontrol edilecek ve tüm oyuncularda ve DM'de senkron çalışacak. Ayrıca second screen oyuncularda tab'da görüntülenebilecek. Yani DM live screen paylaşabilecek oyunculara.

Şimdi, önce nasıl bir tech stack kullanacağımızı tartışalım. Olabildiğince maaliyetten kaçınmak istiyorum, özellikle başlarda. Ayrıca, önerdiğin farklı bir sistem varsa, tartışabiliriz. MD plan dosyalarını da oku, yeni bir sisteme geçiş yaparsak bu dosyalarda daha sonra güncellemeye gideceğiz.

---


,
