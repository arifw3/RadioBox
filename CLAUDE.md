# PROJE ADI: DialWave (Sıfır Maliyetli, Otonom ve Akıllı Radyo Platformu)

## 1. Proje Özeti ve Geliştirme Yaklaşımı
Bu projenin amacı; arka planda kapanma, kırık linkler ve hantal arayüz gibi klasik radyo uygulaması sorunlarını tamamen çözen, modern ve akıllı bir mobil uygulama geliştirmektir. 
Sistem, aylık sunucu faturası oluşturmayacak "Sıfır Maliyetli (Serverless)" bir mimariyle kurgulanacaktır. Abonelik (SaaS) modeli iptal edilmiş olup, uygulama tamamen ücretsiz olacak ve sadece alt banner reklam ile gelir elde edecektir.
Geliştirme sürecinde "Vibe Coding" mantığı benimsenecek, parçalar halinde ilerlenecek ve Basecamp gibi proje yönetim mantığına uygun olarak fazlandırılmış bir mimari kurulacaktır.

---

## 2. Teknoloji Yığını (Tech Stack)
* **Mobil Uygulama (Client):** Flutter (Sürüm 3.x), `just_audio`, `audio_service`, `geolocator`, `google_mobile_ads`
* **Otopilot Arka Plan (Zero-Cost Backend):** GitHub Actions, Python, GitHub Pages
* **Veritabanı Mantığı:** API'den çekilip doğrulanan statik `radios.json` dosyası.
* **Veri Kaynağı:** `radio-browser.info` API (Dinamik ve global radyo dizini).
* **Şarkı Yakalama API'si:** ACRCloud (veya muadili) ses tanıma entegrasyonu.

---

## 3. Otopilot Veri Santrali (Sıfır Maliyetli Backend)
Sunucu masrafını sıfırlamak için statik JSON ve otomasyon mantığı kullanılacaktır.
* **Python Cron Job:** GitHub Actions üzerinde her gece 03:00'te çalışacak bir Python scripti yazılacaktır.
* **Ping ve Temizlik:** Bu script `radio-browser.info`'dan Türkiye (ve seçili) ülke radyolarını çekecek, her linke HTTP isteği (ping) atarak sadece `200 OK` veren çalışan kanalları ayıklayacaktır.
* **Statik Yayın:** Temizlenmiş liste `radios.json` olarak GitHub deposuna kaydedilecek ve GitHub Pages üzerinden ücretsiz olarak mobil uygulamaya servis edilecektir. Uygulama sadece bu JSON dosyasını okuyacaktır.

---

## 4. Temel Sistem ve Kesintisiz Ses Mimarisi
* **Kapanmayan Arka Plan Servisi:** `just_audio` ve `audio_service` kullanılarak Foreground Service ve MediaSession API'leri eksiksiz entegre edilecektir. Ekran kilitliyken veya kulaklıktayken kontroller aktif kalacaktır.
* **Akıllı Ses Odağı (Audio Focus):** Navigasyon uyarılarında ses kısılacak (ducking), telefon çaldığında yayın duracak ve görüşme bitince otomatik devam edecektir.
* **Otomatik Yeniden Bağlanma (Auto-Reconnect):** İnternet zayıfladığında dinamik tamponlama (buffering) yapılacak.
* **Zaman Yolculuğu (Time Shift):** Canlı radyo yayını cihaz belleğinde 10-15 dakikalık bir tampon (buffer) ile tutulacak, kullanıcı yayını geriye sarabilecektir.
* **Tünel/Kör Nokta Kurtarıcısı (Çevrimdışı Mod):** İnternet kesildiği an "Yükleniyor" döngüsü yerine, cihaz içine gömülü 2-3 adet telifsiz rahatlatıcı müzik (Ambient/Lo-Fi) otomatik devreye girecek, internet gelince radyoya dönülecektir.

---

## 5. Sıfır Maliyetli Cihaz İçi "Yapay Zeka" (On-Device Logic)
Bulut AI maliyetlerini sıfırlamak için akıllı deneyim doğrudan cihazın sensörleri ve saati ile kurgulanacaktır.
* **Zaman ve Bağlam Algoritması:** Cihazın saati okunacak; örneğin 07:00-09:00 arası ana ekranda "Güne Başlarken" (Haber radyoları), 23:00 sonrası "Gece Ritmi" kategorileri otomatik öne çıkacaktır.
* **Otomatik Sürüş Modu Geçişi:** Cihazın GPS hızı (`geolocator`) 20 km/s'yi aştığında, uygulama buluta sormadan kullanıcının araca bindiğini anlayacak ve arayüzü doğrudan "Sürüş Modu"na çevirecektir.

---

## 6. Sürüş Güvenliği ve Araç İçi Deneyim (Drive Mode)
* **Kusursuz Sürüş Modu:** Hız 20 km/s'yi geçince veya manuel tetiklenince ekran tamamen değişecektir. Küçük butonlar kalkacak; ekranın tamamı dokunmatik alana dönüşecektir (sağa kaydırarak kanal değiştirme, yukarı/aşağı ses açma, çift tıklayarak durdurma).
* **Devasa Kontroller:** İnce ayar gerektirmeyen dev ve kalın slider'lar kullanılacaktır. (Örn: VW T-Roc gibi araçların multimedya ekranlarında native gibi duracak devasa UI).
* **Araç Entegrasyonu:** Apple CarPlay ve Android Auto için native destek sağlanacaktır.

---

## 7. Kullanıcı Deneyimi (UX/UI) ve Görsel Tasarım
* **Akıllı Onboarding:** Sistem dilinden/saatinden ülkeyi bulup anında o ülkenin radyolarını listeleyecek, dileyen "Dünya Turu" sekmesinden ülke değiştirebilecektir.
* **Winamp Tarzı Görselleştirici (Visualizer):** Oynatıcı ekranında dairesel stereo grafik görselleştiriciler (EQ dalgaları) bulunacak, kullanıcı dokunarak farklı dalga formları arasında geçiş yapabilecektir.
* **Dinamik Renk Paleti:** Uygulamanın renkleri, çalan radyonun logosuna veya albüm kapağının baskın renklerine göre dinamik değişecektir.
* **Standart Araçlar:** Uyku Zamanlayıcısı (Sleep Timer), Radyo ile uyanma (Alarm), Favoriler sekmesi eksiksiz olacaktır.
* **Entegre Şarkı Yakalayıcı:** Radyonun metadata'sı yoksa tek butonla şarkıyı dinleyip bulma (ACRCloud) özelliği eklenecektir.

---

## 8. Büyüme (Growth) ve Sosyal Etkileşim
* **Görsel Sosyal Paylaşım:** Winamp ses dalgalarını barındıran, Instagram/WhatsApp için şık hikaye (story) kartları oluşturma özelliği.
* **Birlikte Dinle (Social Sync):** Kullanıcı bir "Oda Linki" oluşturup arkadaşına atacak ve iki kişi milisaniyesine kadar aynı radyoyu senkronize dinleyecektir (Emoji desteğiyle).
* **Canlı Dinleyici Sayacı:** Oynatıcı ekranında "Şu an seninle birlikte X kişi dinliyor" şeklinde anonim sayaç bulunacaktır.
* **Veri Tasarrufu Uyarısı:** Wi-Fi'dan mobil veriye geçildiğinde bildirim çıkacaktır.

---

## 9. Gelir Modeli
* **Sadece Alt Banner Reklam:** Kullanıcı deneyimini bölen sesli veya tam ekran reklamlar ASLA olmayacaktır. Ekranın en altına, tasarımı bozmayacak ince bir `google_mobile_ads` banner'ı eklenecektir. Uygulamanın diğer tüm premium özellikleri tamamen ücretsiz olacaktır.

---

## Geliştiriciye (Claude) Talimat:
Sen kıdemli bir Full-Stack Mobil (Flutter) ve Python mimarısın. Ben bu projenin yöneticisiyim. Bu "DialWave" proje belgesini tamamen anladığını teyit et. İlk adım olarak "Vibe Coding" yaklaşımıyla bana şu 2 maddeyi doğrudan kodla:
1. GitHub Actions'da her gece çalışacak olan ve radio-browser.info'dan çalışan linkleri süzüp 'radios.json' oluşturan Python scriptini (Faz 1).
2. Flutter klasör yapısını ve `audio_service` tabanlı ana müzik oynatıcısının temel state yapısını.
Bana proje hakkında soru sorma, doğrudan bu teknik kodları ve kurulum adımlarını üreterek projeyi başlat.