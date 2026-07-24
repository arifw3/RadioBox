# Play Console — "Veri Güvenliği" (Data Safety) Formu Referansı

Bu, Play Console'daki **Uygulama içeriği → Veri güvenliği** formunu doldururken kullanacağınız
referans. Form İngilizce sorular sorar ama Türkçe arayüzde de doldurulabilir — aşağıda hangi
kutucuğu işaretleyeceğiniz net şekilde yazıyor.

## 1. Uygulamanız veri topluyor mu / paylaşıyor mu?
**Evet** — topluyor (aşağıdaki kategoriler için), ama **satmıyor**.

## 2. Toplanan Veri Kategorileri

| Kategori | Toplanıyor mu? | Neden | Paylaşılıyor mu? | Şifreli mi? | Silinebilir mi? |
|---|---|---|---|---|---|
| **Konum — Yaklaşık konum** | Hayır | — | — | — | — |
| **Konum — Kesin konum** | **Evet** | Uygulama işlevi (Sürüş Modu'nun otomatik algılanması) | Hayır, paylaşılmıyor | Aktarımda şifreli (HTTPS) | Cihazdan hiç ayrılmıyor, sunucuya gönderilmiyor |
| **Kişisel bilgiler (isim, e-posta vb.)** | Hayır | — | — | — | — |
| **Cihaz veya diğer kimlikler (Advertising ID)** | **Evet** | Reklamlar (Google AdMob) | **Evet, Google AdMob ile paylaşılıyor** | Google'ın kendi altyapısı | Kullanıcı reklam kimliğini cihaz ayarlarından sıfırlayabilir |
| **Uygulama etkinliği / çökme günlükleri (Crash logs)** | **Evet** | Analitik (hata ayıklama — Firebase Crashlytics) | **Evet, Firebase/Google ile paylaşılıyor** | Aktarımda şifreli | Firebase Console üzerinden silinebilir |
| **Ses (mikrofon kaydı)** | **Evet ama geçici** | Uygulama işlevi (sesli arama — konuşma metne çevirme) | Hayır, uygulamamız tarafından saklanmıyor (Android'in kendi konuşma tanıma servisine gidiyor) | — | Kaydedilmiyor ki silinsin — anlık işleniyor |
| Finansal bilgiler | Hayır | — | — | — | — |
| Sağlık ve fitness | Hayır | — | — | — | — |
| Mesajlar | Hayır | — | — | — | — |
| Fotoğraf/video | Hayır | — | — | — | — |
| Kişi/rehber bilgileri | Hayır | — | — | — | — |
| Arama geçmişi (web/tarayıcı) | Hayır | — | — | — | — |

## 3. "Veriler isteğe bağlı olarak paylaşılıyor mu?" gibi ek sorular
- **Konum**: "Bu veri toplanması zorunlu mu, isteğe bağlı mı?" → **İsteğe bağlı** (kullanıcı izin vermeyebilir, Sürüş Modu'nu elle de açabilir).
- **Mikrofon**: **İsteğe bağlı** (sesli arama kullanılmazsa hiç erişilmez, klavye ile de aranabilir).
- **Advertising ID / Crash data**: Bu ikisi teknik olarak uygulamanın çalışması için "gerekli" sayılabilir (reklam gösterimi ve kararlılık için), ama kullanıcı bunları doğrudan kapatamaz — formda "Bu veri toplama zorunludur" seçebilirsiniz.

## 4. "Verileriniz endüstri standardı güvenlik uygulamalarıyla şifreleniyor mu?"
**Evet** — tüm ağ trafiği HTTPS üzerinden.

## 5. "Kullanıcılar verilerinin silinmesini isteyebilir mi?"
- Cihazda tutulan veriler (favoriler, geçmiş) için: **Evet, uygulamayı kaldırarak** (uninstall) siliniyor.
- Crashlytics/AdMob verisi için: Google'ın kendi araçları üzerinden (kullanıcı kendi reklam kimliğini sıfırlayabilir).

## 6. Gizlilik Politikası URL'si
```
https://arifw3.github.io/RadioBox/privacy-policy.html
```

## 7. İçerik Derecelendirme (IARC Anketi) — Beklenen Cevaplar
- Şiddet: Yok
- Cinsel içerik: Yok
- Küfür: Yok (radyo içeriği bizim kontrolümüzde değil ama uygulamanın kendisi filtre sağlamıyor — genelde "Radyo/müzik yayın uygulaması" kategorisinde standart, düşük yaş sınırı çıkar, örn. PEGI 3 / Everyone)
- Kumar: Yok
- Kullanıcı tarafından oluşturulan içerik: Yok (istasyon listesi bizim/radio-browser.info tarafından derleniyor, kullanıcı içerik eklemiyor)
- Konum paylaşımı: Var ama üçüncü kişilerle paylaşılmıyor, sadece cihaz içi
