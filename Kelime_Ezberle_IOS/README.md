# YDS Kelimelerim — iOS

[ydskelimelerim.com](https://ydskelimelerim.com) sitesindeki kelime ezberleme sınavının native iOS uygulaması. SwiftUI ile yazıldı, tamamen çevrimdışı çalışır, AdMob ile gelir üretir.

Bu belge **baştan sona** her adımı içerir: kodun mimarisi, Mac olmadan derleme, App Store Connect kurulumu, AdMob bağlama, gizlilik beyanı, inceleme süreci ve yayın sonrası güncelleme.

---

## İçindekiler

1. [Ne yapıldı](#1-ne-yapıldı)
2. [Mimari](#2-mimari)
3. [Proje yapısı](#3-proje-yapısı)
4. [Veri akışı ve web ile ilişki](#4-veri-akışı-ve-web-ile-ilişki)
5. [Yapılandırma — tek dosya](#5-yapılandırma--tek-dosya)
6. [Mac varsa: yerel geliştirme](#6-mac-varsa-yerel-geliştirme)
7. [Mac yoksa: bulutta derleme](#7-mac-yoksa-bulutta-derleme)
8. [Apple Developer hesabı ve kimlikler](#8-apple-developer-hesabı-ve-kimlikler)
9. [App Store Connect kurulumu](#9-app-store-connect-kurulumu)
10. [AdMob kurulumu](#10-admob-kurulumu)
11. [Gizlilik beyanı — App Privacy](#11-gizlilik-beyanı--app-privacy)
12. [Yayınlama adımları](#12-yayınlama-adımları)
13. [İnceleme (review) için hazırlık](#13-i̇nceleme-review-için-hazırlık)
14. [Yayın sonrası: güncelleme ve bakım](#14-yayın-sonrası-güncelleme-ve-bakım)
15. [Testler](#15-testler)
16. [Sık karşılaşılan hatalar](#16-sık-karşılaşılan-hatalar)
17. [Bilinçli olarak yapılmayanlar](#17-bilinçli-olarak-yapılmayanlar)

---

## 1. Ne yapıldı

Sitedeki sınavın tüm davranışı Swift'e taşındı — arayüz yeniden çizildi ama **motor birebir aynı**:

| Özellik | Web | iOS |
|---|---|---|
| SM-2 aralıklı tekrar | ✓ | ✓ (aynı formül, aynı sabitler) |
| 4 şıklı test, üç kademeli çeldirici | ✓ | ✓ |
| EN→TR / TR→EN / karışık yön | ✓ | ✓ |
| İpucu (cümlede kullanım) | ✓ | ✓ |
| TR→EN'de boşluk doldurma | ✓ | ✓ |
| Yanlışların oturum sonunda tekrarı | ✓ | ✓ |
| İstatistik, seri, öğrenme dağılımı | ✓ | ✓ |
| Kelime listesi + arama | ✓ | ✓ (+ süzgeçler, detay ekranı) |
| İlerleme dışa/içe aktarma | ✓ | ✓ (**dosya biçimi uyumlu**) |
| Reklam | AdSense | AdMob |
| Günlük hatırlatma | — | ✓ |
| Ana ekran / kilit ekranı widget'ı | — | ✓ |
| Çevrimdışı çalışma | kısmen (PWA) | tam |

**781 kart** paketin içinde: 622 kelime + 159 phrasal verb. Ağ bağlantısı yalnızca reklam için kullanılır; internet yokken uygulama eksiksiz çalışır.

---

## 2. Mimari

Üç katman, tek yönlü bağımlılık. Alt katman üstünü hiç bilmez:

```
┌─────────────────────────────────────────────┐
│  Features/  — SwiftUI ekranları             │  ← yalnız görüntüler
├─────────────────────────────────────────────┤
│  Services/  — AdMob, bildirim               │  ← dış dünya
├─────────────────────────────────────────────┤
│  Core/      — SM-2, kuyruk, çeldirici,      │  ← saf mantık
│               eşleştirici, depo             │     (SwiftUI bilmez)
└─────────────────────────────────────────────┘
```

**Core neden SwiftUI'siz:** Bütün iş kuralları burada ve hepsi birim testiyle doğrulanabiliyor. `SM2Scheduler.apply(record, quality:today:)` saf bir fonksiyon — girdiyi ver, çıktıyı denetle. Aynı mantık bir görünüm modelinin içine gömülseydi, test etmek için ekran kurmak gerekirdi.

**Widget aynı Core'u kullanır.** Widget hedefi `Sources/Core/Models`, `Core/Data` ve `Core/SpacedRepetition` klasörlerini paylaşır. İki yerde iki farklı "kaç kart tekrar bekliyor" hesabı olsaydı, er geç farklı sayılar gösterirlerdi.

### Veri akışı

```
deck.json (paket, salt okunur)
        │
        ▼
   DeckLoader ──► Deck ──────────┐
                                 ├──► QuizSession ──► QuizView
   ProgressStore ────────────────┘         │
        │  (App Group / progress.json)     │
        │                                  ▼
        └──────────────────────► ProgressStore.apply(...)
                                           │
                                           ▼
                            widget-snapshot.json ──► Widget
```

`ProgressStore` tek yazma noktası. Kart kaydının değiştiği başka hiçbir yer yok; bu yüzden "ilerleme neden kayboldu" sınıfı hatalar tek dosyada aranır.

### Neden Core Data / SwiftData yok

Veri 781 kayıtlık düz bir sözlük, toplam birkaç yüz kilobayt, ilişkisel sorgu ihtiyacı sıfır. Bir veritabanı katmanı burada yalnızca migration derdi, thread yönetimi ve daha yavaş bir açılış getirirdi. Atomik yazılan tek bir JSON dosyası hem daha hızlı hem de web'den gelen yedek dosyasıyla doğrudan uyumlu.

---

## 3. Proje yapısı

```
Kelime_Ezberle_IOS/
├── README.md                     ← bu dosya
├── project.yml                   ← XcodeGen proje tanımı
├── codemagic.yaml                ← bulutta derleme (birincil yol)
├── .github/workflows/ios.yml     ← GitHub Actions alternatifi
│
├── Config/
│   ├── App.xcconfig              ← TÜM ayarlar burada
│   └── ExportOptions.plist
│
├── App/
│   ├── Info.plist
│   └── YDSKelimelerim.entitlements
│
├── Sources/
│   ├── App/                      YDSKelimelerimApp, RootView, AppEnvironment
│   ├── Core/
│   │   ├── Models/               Card, ReviewRecord
│   │   ├── SpacedRepetition/     SM2Scheduler, QueueBuilder
│   │   ├── Quiz/                 QuizSession, DistractorGenerator, SentenceMatcher
│   │   └── Data/                 Deck, ProgressStore, SharedContainer, StatsCalculator
│   ├── Services/                 AdsManager, NotificationService
│   ├── DesignSystem/             Theme, Components
│   └── Features/                 Home, Quiz, Result, WordList, Stats, Settings, Ads
│
├── Widget/                       YDSWidgetBundle, DueWidget, Info.plist
│
├── Resources/
│   ├── Data/deck.json            ← üretilen veri (781 kart)
│   └── Assets.xcassets/
│
├── Tests/                        SM2, QueueBuilder, SentenceMatcher,
│                                 ProgressStore, QuizSession, DeckIntegrity
└── tools/
    ├── sync_web_data.ps1         web verisini çeker ve dönüştürür
    ├── prepare_data.py           JSON birleştirme + doğrulama
    └── make_appicon.py           1024px uygulama simgesi
```

### Neden `.xcodeproj` depoda yok

`project.pbxproj` makine tarafından üretilen, birleştirilemeyen dev bir dosyadır. Depoda tutulunca:

- her dal değişiminde çakışır ve çakışmayı elle çözmek pratikte imkânsızdır,
- Windows'ta okunamaz/düzenlenemez,
- kim neyi neden değiştirdi görünmez.

`project.yml` ise 150 satırlık okunabilir bir YAML. `xcodegen generate` komutu `.xcodeproj` dosyasını saniyeler içinde üretir. **Xcode'da yaptığınız proje ayarı değişiklikleri `project.yml`'e yazılmadıkça kaybolur** — bu bilinçli: yapılandırma tek yerde kalsın.

---

## 4. Veri akışı ve web ile ilişki

Kelime listesinin tek kaynağı **web projesidir** (`C:\Kelime_Ezberle\src`). iOS projesi onu türetir.

```
C:\Kelime_Ezberle\src\           tools\rawdata\        Resources\Data\
  words_1..4.json         ──►    (geçici kopya)  ──►    deck.json
  phrasals_1.json                                       (781 kart)
  examples2_*.json
  irregular.json
```

Yeni kelime eklemek:

```powershell
# 1. Web projesinde kelimeyi ekleyin ve derle.bat ile testleri geçirin
# 2. Sonra burada:
.\tools\sync_web_data.ps1
# 3. deck.json güncellenir; işleyip (commit) etiketleyin
```

`prepare_data.py`, web'deki `build.py` ile **aynı doğrulamaları** uygular: boş alan, eksik ikinci cümle, hedef kelimenin cümlede geçip geçmediği, seviye aralığı, yinelenen terim. Hata varsa çıkış kodu 1 döner ve `deck.json` yine de yazılır ama sorunlar ekrana basılır.

### Kart kimlikleri neden web ile aynı

`w0`, `w1`, …, `p0`, `p1` … sırası web'dekiyle birebir aynı üretiliyor. Sebebi: kullanıcı sitedeki "İlerlemeyi dışa aktar" dosyasını uygulamaya aktardığında tekrar takvimi bozulmadan taşınsın. Aynısı tersine de çalışır.

> **Dikkat:** Kelime listesinin ortasına kelime eklerseniz sonraki tüm kimlikler kayar ve iki platform arasındaki uyum bozulur. **Yeni kelimeleri her zaman dosyanın sonuna ekleyin.**

---

## 5. Yapılandırma — tek dosya

Değiştirmeniz gereken her şey `Config/App.xcconfig` içinde. Kaynak kodda hiçbir kimlik gömülü değil.

```
APP_BUNDLE_ID = com.ustuner.ydskelimelerim
APP_DISPLAY_NAME = YDS Kelimelerim
APP_GROUP_ID = group.com.ustuner.ydskelimelerim

MARKETING_VERSION = 1.0.0          ← App Store'da görünen sürüm
CURRENT_PROJECT_VERSION = 1        ← her yüklemede artmalı (CI otomatik artırır)

DEVELOPMENT_TEAM =                 ← 10 haneli Apple Team ID
CODE_SIGN_IDENTITY_APP = Apple Distribution
APP_PROVISIONING_PROFILE = YDSKelimelerim AppStore
WIDGET_PROVISIONING_PROFILE = YDSKelimelerim Widget AppStore

ADMOB_APP_ID = ca-app-pub-3940256099942544~1458002511      ← Google TEST kimliği
ADMOB_BANNER_QUIZ = ca-app-pub-3940256099942544/2435281174 ← Google TEST kimliği
ADMOB_BANNER_RESULT = ...
ADMOB_BANNER_LIST = ...

ADS_ENABLED = YES                  ← NO yaparsanız SDK hiç başlatılmaz
```

**Şu an test reklam kimlikleri yüklü.** Bu bilinçli: kendi kimliğinizle geliştirme yaparken reklam istemek AdMob'un *geçersiz trafik* politikasını ihlal eder ve hesabınız askıya alınabilir. Yayına çıkmadan önce dördünü de değiştirin — nasıl alınacağı [10. bölümde](#10-admob-kurulumu).

> `.xcconfig` dosyalarında `//` yorum başlatır. Reklam birimi kimliklerindeki tek `/` sorun değildir, ama buraya URL yazmanız gerekirse `//` dizisini kaçırmalısınız.

---

## 6. Mac varsa: yerel geliştirme

```bash
brew install xcodegen
python3 -m pip install pillow

python3 tools/prepare_data.py       # deck.json üret (yalnız veri değiştiyse)
python3 tools/make_appicon.py       # simge üret (yalnız tasarım değiştiyse)
xcodegen generate
open YDSKelimelerim.xcodeproj
```

Xcode ilk açılışta Swift Package'ları (Google Mobile Ads) indirir — birkaç dakika sürer.

Testler:

```bash
xcodebuild test \
  -project YDSKelimelerim.xcodeproj \
  -scheme YDSKelimelerim \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

Simülatörde reklam **görünmez** (test reklamı gelir ama boş çerçeve olabilir); reklamları gerçekten görmek için fiziksel cihaz gerekir.

---

## 7. Mac yoksa: bulutta derleme

Sizin durumunuz bu. Kodu Windows'ta yazıp, derlemeyi ve App Store'a göndermeyi bulutta bir macOS makinesine yaptırıyoruz.

**Neden Mac gerekiyor:** Apple, iOS uygulamalarının yalnızca macOS üzerinde imzalanıp arşivlenmesine izin veriyor. Bu bir araç eksikliği değil, Apple'ın lisans kısıtı — etrafından dolaşmanın yasal bir yolu yok. Bulut macOS makineleri bu işi sizin adınıza yapar.

### Seçenek A — Codemagic (önerilen)

Aylık 500 dakika ücretsiz; bu proje için derleme başına ~8 dakika, yani ayda ~60 derleme.

**Adımlar:**

1. **Kodu bir Git deposuna koyun.**
   ```powershell
   cd C:\Kelime_Ezberle_IOS
   git init
   git add .
   git commit -m "iOS uygulaması ilk sürüm"
   git branch -M main
   git remote add origin https://github.com/KULLANICI/yds-kelimelerim-ios.git
   git push -u origin main
   ```
   Depo **özel (private)** olsun — `App.xcconfig` içinde AdMob kimlikleriniz duruyor.

2. **[codemagic.io](https://codemagic.io)** hesabı açın, GitHub ile bağlanın, depoyu ekleyin. Codemagic kökteki `codemagic.yaml` dosyasını kendiliğinden bulur.

3. **App Store Connect API anahtarı üretin.**
   [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Kullanıcılar ve Erişim** → **Integrations** → **App Store Connect API** → **+**
   - Ad: `Codemagic`
   - Erişim: **App Manager**
   - Üretilen `.p8` dosyasını indirin. **Bir kez indirilir, ikinci şansınız yok.**
   - Aynı ekrandaki **Issuer ID** ve anahtarın **Key ID** değerini not alın.

4. **Codemagic'e tanıtın.**
   Codemagic → **Teams** → **Integrations** → **Developer Portal** → **Connect**
   - Issuer ID, Key ID ve `.p8` dosyasını yükleyin.
   - Bu bağlantı, `codemagic.yaml` içindeki `ios_signing` bölümünün sertifika ve profilleri **otomatik oluşturmasını** sağlar. Elle sertifika üretmenize gerek kalmaz.

5. **Takım kimliğini ortam değişkeni yapın.**
   Codemagic → uygulamanız → **Environment variables**
   - `APPLE_TEAM_ID` = 10 haneli Team ID → grup: `app_store_credentials`

6. **`codemagic.yaml` içinde tek satır düzeltin:**
   ```yaml
   APP_STORE_APPLE_ID: "0000000000"   # ← App Store Connect'teki sayısal uygulama kimliği
   ```
   Bu numarayı [9. bölümde](#9-app-store-connect-kurulumu) uygulamayı oluşturduktan sonra alacaksınız (App Store Connect → Uygulama → App Information → Apple ID).

7. **Derlemeyi başlatın:**
   ```powershell
   git tag v1.0.0
   git push origin v1.0.0
   ```
   `v` ile başlayan etiket `release` iş akışını tetikler: test → arşiv → TestFlight.

### Seçenek B — GitHub Actions

`.github/workflows/ios.yml` hazır. Özel depolarda macOS dakikaları **10 katsayıyla** sayılır (ücretsiz 2000 dakika → pratikte 200 macOS dakikası), bu yüzden Codemagic genelde daha ekonomik. Genel (public) bir depoysa ücretsizdir.

Bu yolda sertifikaları elle üretip depo gizli anahtarlarına eklemeniz gerekir:

| Secret | Nedir |
|---|---|
| `CERTIFICATE_P12` | Dağıtım sertifikası, base64 |
| `CERTIFICATE_PASSWORD` | `.p12` parolası |
| `APP_PROVISIONING_PROFILE` | Uygulama profili, base64 |
| `WIDGET_PROVISIONING_PROFILE` | Widget profili, base64 |
| `APPLE_TEAM_ID` | 10 haneli takım kimliği |
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` | App Store Connect API anahtarı |

Base64'e çevirme (PowerShell):
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("sertifika.p12")) | Set-Clipboard
```

---

## 8. Apple Developer hesabı ve kimlikler

### 8.1 Hesap

[developer.apple.com/programs](https://developer.apple.com/programs/) → **Enroll**. Yıllık **99 USD**. Bireysel kayıt genelde 24-48 saatte onaylanır; şirket kaydı D-U-N-S numarası ister ve haftalar sürebilir.

Onay geldikten sonra **Membership Details** sayfasındaki **Team ID**'yi (10 karakter) not alın.

### 8.2 App ID'ler

[developer.apple.com/account](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → **Identifiers** → **+**

**İki tane** oluşturun:

| Açıklama | Bundle ID | Capabilities |
|---|---|---|
| YDS Kelimelerim | `com.ustuner.ydskelimelerim` | App Groups |
| YDS Kelimelerim Widget | `com.ustuner.ydskelimelerim.widget` | App Groups |

### 8.3 App Group

**Identifiers** → sağ üstteki açılır menüden **App Groups** → **+**

- Kimlik: `group.com.ustuner.ydskelimelerim`

Sonra **her iki App ID'yi** düzenleyip App Groups yeteneğinde bu grubu işaretleyin.

> **Bu adım atlanırsa:** Uygulama çalışır ama widget hep boş görünür. Uygulama ilerlemeyi kendi kutusuna yazar, widget okuyamaz. Sessiz bir hatadır, uzun süre fark edilmez — `SharedContainer.directory` bilerek çökmek yerine yedek klasöre düşer.

---

## 9. App Store Connect kurulumu

[appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Uygulamalarım** → **+** → **Yeni Uygulama**

| Alan | Değer |
|---|---|
| Platform | iOS |
| Ad | YDS Kelimelerim |
| Birincil dil | Türkçe |
| Paket kimliği | `com.ustuner.ydskelimelerim` |
| SKU | `ydskelimelerim-ios` (yalnız sizin göreceğiniz iç kod) |
| Kullanıcı erişimi | Tam Erişim |

Oluştuktan sonra **App Information** sayfasındaki **Apple ID** (sayısal, ör. `6740000000`) değerini `codemagic.yaml` içine yazın.

### Mağaza sayfası

**Kategori:** Eğitim (birincil) · Referans (ikincil)

**Yaş sınırı:** 4+ — uygulamada kısıtlayıcı içerik yok. Anketi doldururken tüm sorulara "Yok/Hayır" yeterli.

**Fiyat:** Ücretsiz.

**Ekran görüntüleri (zorunlu):**

| Cihaz | Boyut | Adet |
|---|---|---|
| 6.9" iPhone (16 Pro Max) | 1320×2868 | en az 3 |
| 6.5" iPhone (11 Pro Max) | 1242×2688 | en az 3 |
| 13" iPad Pro | 2064×2752 | en az 3 (iPad destekliyorsanız) |

Simülatörde `Cmd+S` ile alınır. **Reklamları kapatarak alın** — `ADS_ENABLED = NO` yapıp yeniden derleyin; Apple, ekran görüntüsünde üçüncü taraf reklamı görmekten hoşlanmaz ve zaten reklam görselleri ürününüzü anlatmaz.

Önerilen üç ekran: ana ekran (sayaçlar), test ekranı (soru + şıklar), sonuç ekranı (halka).

**Açıklama taslağı:**

```
YDS, YÖKDİL ve YDT sınavlarında en sık çıkan 780 kelime ve phrasal verb.
Aralıklı tekrar (spaced repetition) algoritmasıyla, unutmadan hemen önce
tekrar karşınıza çıkar.

• 622 kelime + 159 phrasal verb, her biri iki örnek cümleyle
• SM-2 algoritması: bildiğiniz kelimeyi seyrek, zorlandığınızı sık sorar
• İngilizce→Türkçe, Türkçe→İngilizce veya karışık yön
• Takıldığınızda örnek cümlede kullanımını gösteren ipucu
• Yanlış bildikleriniz oturumun sonunda tekrar sorulur
• Öğrenme dağılımı, doğruluk oranı ve çalışma serisi istatistikleri
• Günlük tekrar hatırlatması ve ana ekran widget'ı
• Tamamen çevrimdışı — internet gerekmez
• Kayıt yok, hesap yok
```

**Anahtar kelimeler** (100 karakter): `yds,yökdil,ydt,kelime,ingilizce,phrasal verb,sınav,ezber,tekrar,kpds,üds`

**Destek URL'si** zorunlu: `https://ydskelimelerim.com/iletisim/`
**Gizlilik politikası URL'si** zorunlu: `https://ydskelimelerim.com/gizlilik/`

> Gizlilik politikanız şu an **web sitesini** anlatıyor. Uygulama için AdMob, App Group ve bildirim kullanımını da eklemeniz gerekiyor — detaylar [11. bölümde](#11-gizlilik-beyanı--app-privacy).

---

## 10. AdMob kurulumu

AdMob ile AdSense **ayrı ürünlerdir**. Sitedeki AdSense hesabınız (`ca-pub-1046330097095043`) uygulamada çalışmaz; uygulama için AdMob'da ayrı bir uygulama kaydı gerekir. İyi haber: **aynı Google hesabıyla** girersiniz ve ödemeler tek yerde toplanır.

### 10.1 Uygulamayı kaydedin

[apps.admob.com](https://apps.admob.com) → **Uygulamalar** → **Uygulama ekle**

- Platform: **iOS**
- "Uygulamanız uygulama mağazalarında listeleniyor mu?" → **Hayır** (henüz yayınlanmadı)
- Ad: `YDS Kelimelerim`

Verilen **Uygulama Kimliği**ni (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` — tilde işaretli) `ADMOB_APP_ID` alanına yazın.

### 10.2 Üç reklam birimi oluşturun

**Reklam birimleri** → **Reklam birimi ekle** → **Banner**

| Birim adı | xcconfig alanı | Nerede görünür |
|---|---|---|
| Quiz Banner | `ADMOB_BANNER_QUIZ` | Test ekranı, şıkların altında |
| Result Banner | `ADMOB_BANNER_RESULT` | Oturum sonu ekranı |
| List Banner | `ADMOB_BANNER_LIST` | Kelime listesi, altta sabit |

Her birim `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ` biçiminde (eğik çizgili) bir kimlik verir.

**Otomatik yenilemeyi 60 saniyeye ayarlayın.** Google'ın izin verdiği en kısa süre 30 saniye ama 60 saniye daha güvenli: bir soru ortalama 8 saniyede cevaplanıyor, 30 saniyelik yenileme dakikada 2 gösterim demek ve tıklanma oranı çok düşük olduğu için geçersiz trafik denetimini tetikleyebiliyor.

### 10.3 Boş bırakılan alan çizilmez

`AdsManager.adUnitID(for:)` boş bir kimlik görürse `nil` döner ve o alan hiç oluşturulmaz. Yani üç birimden yalnız birini doldurursanız diğer iki ekranda boş kutu belirmez. Reklamı tamamen kapatmak için `ADS_ENABLED = NO` yeterli — SDK bile başlatılmaz.

### 10.4 Reklam yerleşimi neden böyle

| Nerede | Neden orada |
|---|---|
| Test ekranı, **şıkların altında** | Şıkların üstünde olsaydı, kullanıcı cevaba basarken reklama denk gelirdi. Bu "kazara tıklama" AdMob'un en sık uyguladığı yaptırım sebebidir. |
| Oturum boyunca **yenilenmez** | Web tarafında da konuştuğumuz konu: her soruda yeni reklam yüklemek dakikada 7-8 yenileme demek, bu doğrudan geçersiz trafik. |
| Sonuç ekranında **oturum başına bir kez** | Doğal bir mola anı; kullanıcıyı bölmez. |
| Kelime listesinde **altta sabit** | Kaydırılan içerikte gezinmeyi bozmaz. |

### 10.5 Onay (UMP) ve ATT

`AdsManager.prepare()` şu sırayı izler ve **sıra bilinçlidir**:

1. **UMP onay formu** — Google'ın onay çerçevesi. AB/İngiltere kullanıcılarına form gösterir, Türkiye'de genelde hiçbir şey göstermez.
2. **ATT izni** — Apple'ın "izlemeye izin ver" diyaloğu.
3. **Ancak sonra** `MobileAds.shared.start()`.

SDK başlatıldığı anda reklam ön yüklemeye başlar. Onaydan önce başlatmak hem GDPR ihlali hem AdMob politikası ihlali; Google bu durumda AB trafiğinde reklam yayınını durdurur.

ATT'nin UMP'den *sonra* gelmesi de kural: Apple, izleme diyaloğunun kendi açıklamanızdan sonra gösterilmesini istiyor. Ters sırada kabul oranı belirgin biçimde düşüyor.

ATT reddedilirse uygulama aynen çalışır; reklamlar kişiselleştirilmeden gösterilir. İzni zorlayan bir ekran **koymadık** — Apple bunu da reddediyor.

### 10.6 app-ads.txt

AdMob → **Uygulamalar** → **app-ads.txt** bölümündeki satırı sitenizin köküne, `https://ydskelimelerim.com/app-ads.txt` adresine koyun.

> Sitede zaten `ads.txt` var; **`app-ads.txt` ayrı bir dosyadır**, içeriği benzer ama Google uygulama envanterini doğrulamak için özellikle bu adı arar. Eksikse uygulama reklamlarınızın CPM'i belirgin biçimde düşer.

Uygulama App Store'da yayınlandıktan sonra AdMob'daki uygulama kaydını mağaza listesiyle **eşleştirmeyi unutmayın** (Uygulama ayarları → "Uygulama mağazasında ara"). Eşleşmeyen uygulamalar app-ads.txt doğrulamasından geçemez.

---

## 11. Gizlilik beyanı — App Privacy

App Store Connect → uygulamanız → **Uygulama Gizliliği** → **Başla**

AdMob kullandığınız için şunları beyan etmelisiniz:

| Veri türü | Toplanıyor | Amaç | Kimliğe bağlı |
|---|---|---|---|
| **Tanımlayıcılar** → Cihaz kimliği | Evet | Üçüncü taraf reklamcılığı | Evet |
| **Kullanım verileri** → Reklam verileri | Evet | Üçüncü taraf reklamcılığı, analiz | Evet |
| **Tanılama** → Çökme/performans verisi | Evet | Uygulama işlevselliği | Hayır |

**"Bu veriler kullanıcıyı izlemek için kullanılıyor mu?"** → **Evet** (AdMob için).

Öğrenme ilerlemesi cihazda kalıyor ve hiçbir sunucuya gitmiyor — bunu beyan etmenize gerek yok; Apple yalnızca **toplanan** veriyi soruyor.

Ayrıntılar için: [AdMob veri açıklama rehberi](https://developers.google.com/admob/ios/privacy/data-disclosure).

### Gizlilik politikasına eklenecekler

Sitedeki `/gizlilik/` sayfası şu an yalnızca web'i anlatıyor. Uygulama için şu başlıkları eklemelisiniz:

- **Reklamlar:** Google AdMob kullanıldığı, AdMob'un cihaz tanımlayıcısı ve reklam verisi topladığı, kişiselleştirmenin ATT ve UMP onayına bağlı olduğu.
- **Öğrenme verisi:** Cihazda saklandığı, sunucuya gönderilmediği, uygulama silinince kaybolduğu.
- **Bildirimler:** Yalnız kullanıcı açtığında, cihazda planlandığı, hiçbir sunucu bildirimi kullanılmadığı.
- **Yaş:** Uygulamanın çocuklara yönelik olmadığı (13 yaş altı beyanı reklam politikasını kökten değiştirir).

> Politika ile beyan arasındaki tutarsızlık, inceleme reddinin en sık sebeplerinden biri. Web tarafında da yaşadığımız aynı ilke: izin verdiğiniz her şeyi politikada da anlatın.

---

## 12. Yayınlama adımları

Sıralı kontrol listesi. Her madde önceki maddeye bağlı:

- [ ] **1.** Apple Developer hesabı onaylandı, Team ID alındı → [8.1](#81-hesap)
- [ ] **2.** İki App ID ve bir App Group oluşturuldu → [8.2](#82-app-idler)
- [ ] **3.** App Store Connect'te uygulama kaydı açıldı, Apple ID alındı → [9](#9-app-store-connect-kurulumu)
- [ ] **4.** AdMob'da uygulama ve üç reklam birimi oluşturuldu → [10](#10-admob-kurulumu)
- [ ] **5.** `Config/App.xcconfig` dolduruldu (Team ID + 4 AdMob kimliği)
- [ ] **6.** `codemagic.yaml` içindeki `APP_STORE_APPLE_ID` yazıldı
- [ ] **7.** Kod özel bir Git deposuna itildi
- [ ] **8.** Codemagic bağlandı, API anahtarı tanıtıldı, `APPLE_TEAM_ID` eklendi
- [ ] **9.** `git tag v1.0.0 && git push origin v1.0.0` → derleme başlar
- [ ] **10.** TestFlight'ta uygulama göründü, kendi cihazınızda denendi
- [ ] **11.** Ekran görüntüleri alındı (reklamlar kapalıyken)
- [ ] **12.** Mağaza sayfası metinleri dolduruldu
- [ ] **13.** Uygulama Gizliliği anketi tamamlandı → [11](#11-gizlilik-beyanı--app-privacy)
- [ ] **14.** Sitedeki gizlilik politikası güncellendi
- [ ] **15.** `app-ads.txt` siteye yüklendi
- [ ] **16.** App Store Connect → **İncelemeye gönder**

**Sonrası:** Apple incelemesi genelde 24-48 saat sürer. İlk gönderim biraz daha uzayabilir.

### Sürüm çıkarma döngüsü

```powershell
# Sürüm numarasını güncelleyin
# Config/App.xcconfig → MARKETING_VERSION = 1.1.0
git add .
git commit -m "1.1.0: kelime listesi süzgeçleri"
git tag v1.1.0
git push origin main --tags
```

Derleme numarası (`CURRENT_PROJECT_VERSION`) CI tarafından otomatik artırılır — TestFlight aynı numarayı iki kez kabul etmez, elle takip etmek er geç unutulur.

---

## 13. İnceleme (review) için hazırlık

Bu uygulamanın reddedilme riski düşük ama şu üç nokta doğrudan sizi ilgilendiriyor:

**Guideline 4.2 — Minimum Functionality.** Web sitesini WebView içine koyan uygulamalar reddediliyor. Bizimki native SwiftUI, çevrimdışı çalışıyor, widget ve bildirim gibi platforma özgü özellikler içeriyor — bu maddeye takılmaz. **Bu yüzden Capacitor/WebView yolunu seçmedik.**

**Guideline 5.1.1 — Veri toplama.** ATT açıklama metni `Info.plist` içindeki `NSUserTrackingUsageDescription` alanında ve Türkçe. Metin, izin verilmezse uygulamanın yine de çalışacağını açıkça söylüyor; Apple bunu arıyor.

**Guideline 2.1 — App Completeness.** İnceleme notlarına şunu yazın:

```
Uygulama tamamen çevrimdışı çalışır, hesap veya giriş gerektirmez.
Tüm özellikler ilk açılışta erişilebilir durumdadır.

Reklamlar Google AdMob üzerinden gösterilir. İzleme izni (ATT)
reddedilirse uygulama aynı şekilde çalışır; reklamlar yalnızca
kişiselleştirilmeden yayınlanır.

Ana ekran widget'ını denemek için: önce uygulamada bir çalışma
oturumu tamamlayın, ardından ana ekrana widget'ı ekleyin.
```

Widget notunu eklemek önemli: inceleyen kişi widget'ı boş görürse bunu hata sayabilir. Widget, uygulama en az bir kez veri yazana kadar örnek değerlerle görünür.

---

## 14. Yayın sonrası: güncelleme ve bakım

### Kelime eklemek

```powershell
# 1. Web projesinde words_4.json'un SONUNA ekleyin (ortasına değil!)
# 2. Web projesinde derle.bat çalıştırın, testler geçsin
# 3. .\tools\sync_web_data.ps1
# 4. Config/App.xcconfig → MARKETING_VERSION artırın
# 5. git commit && git tag v1.1.0 && git push --tags
```

### Google Mobile Ads SDK yükseltme

Şu an **12.x** sürümüne sabitli (`project.yml` → `majorVersion: 12.0.0`). Sürüm 13.0.0 (Şubat 2026) kırıcı değişiklikler içeriyor.

Yükseltmek isterseniz:
1. [Sürüm geçiş rehberini](https://developers.google.com/admob/ios/migration) okuyun.
2. `project.yml` içinde `majorVersion: 13.0.0` yapın.
3. `AdsManager.swift` ve `AdBannerSlot.swift` dosyalarını rehbere göre uyarlayın.
4. Testleri çalıştırın, sonra **mutlaka** gerçek cihazda reklamın yüklendiğini görün — SDK değişikliklerinde birim testleri reklam yüklemeyi yakalamaz.

Acele etmeyin: eski ana sürüm genelde bir yıl daha destekleniyor. Google sunset takvimini [buradan](https://developers.google.com/admob/ios/deprecation) duyuruyor.

### iOS ana sürüm çıktığında

Deployment target **iOS 17.0**. Yeni bir iOS çıktığında hemen yükseltmeyin: hedefi yükseltmek eski cihazlardaki kullanıcıları uygulamadan koparır. Kural olarak, en son iki ana sürümü desteklemek yeterlidir.

### Çökme raporları

App Store Connect → uygulamanız → **Metrikler** → **Çökmeler**. `ExportOptions.plist` içinde `uploadSymbols` açık olduğu için raporlarda satır numaralarını görürsünüz.

---

## 15. Testler

```bash
xcodebuild test -project YDSKelimelerim.xcodeproj -scheme YDSKelimelerim \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

| Dosya | Neyi koruyor |
|---|---|
| `SM2SchedulerTests` | Aralık ilerlemesi, kolaylık katsayısı tabanı, kalite notu türetme, gün indeksinin web formülüyle aynılığı |
| `QueueBuilderTests` | Tekrarların yenilerden önce gelmesi, vade sıralaması, deste süzgeci, boş destede davranış |
| `SentenceMatcherTests` | Çekimli hâllerin yakalanması, düzensiz fiiller, phrasal verb araya nesne alması, **yanlış eşleşme olmaması**, boşluk doldurmanın cevabı ele vermemesi |
| `ProgressStoreTests` | Sayaçlar, kalıcılık, web biçimindeki yedeğin okunabilmesi, bozuk dosyanın çökertmemesi |
| `QuizSessionTests` | Oturum akışı, cevap kilidi, ipucunun aralığı sınırlaması, yanlışların tekrar kuyruğa alınması |
| `DeckIntegrityTests` | 781 kartın tamamında boş alan, eksik ikinci cümle, yinelenen terim, **her kartın 3 çeldirici bulabilmesi**, örnek cümlelerde hedef kelimenin geçmesi |

`DeckIntegrityTests` özellikle değerli: `deck.json` üretilen bir dosya ve üretim betiği bozulursa hata sessizce uygulamaya sızar. Bu testler paketteki gerçek veriyi her derlemede denetler.

---

## 16. Sık karşılaşılan hatalar

**`xcodegen: command not found`**
`brew install xcodegen`. CI'da zaten kuruluyor.

**`No such module 'GoogleMobileAds'`**
Xcode paketleri indirmemiş. **File → Packages → Resolve Package Versions**. CI'da `xcodebuild` bunu kendisi yapar.

**Widget hep boş / örnek veri gösteriyor**
App Group eksik veya yanlış. Kontrol: her iki App ID'de de App Groups yeteneği işaretli mi, `App.xcconfig` içindeki `APP_GROUP_ID` ile Apple Developer portalındaki kimlik birebir aynı mı. Ayrıca widget, uygulama en az bir oturum tamamlayana kadar örnek değerlerle görünür — bu beklenen davranış.

**Reklam görünmüyor**
Sırayla bakın: `ADS_ENABLED = YES` mi · reklam birimi kimliği boş mu · yeni oluşturulan birimler ilk birkaç saat reklam döndürmez · simülatörde banner sık sık boş gelir, fiziksel cihazda deneyin.

**`Invalid Bundle. The bundle contains an invalid implementation of WidgetKit`**
Widget'ın `CFBundlePackageType` değeri `XPC!` olmalı ve `NSExtensionPointIdentifier` `com.apple.widgetkit-extension` olmalı. İkisi de `Widget/Info.plist` içinde doğru; bu hatayı görüyorsanız XcodeGen projeyi yeniden üretmemiş demektir.

**`ITMS-90713: Missing Info.plist value` (CFBundleIconName)**
Asset katalogda `AppIcon` yok ya da `ASSETCATALOG_COMPILER_APPICON_NAME` boş. `python3 tools/make_appicon.py` çalıştırıp yeniden derleyin.

**`The provided entity includes an attribute with a value that has already been used` (TestFlight)**
Aynı derleme numarası ikinci kez yüklendi. CI numarayı otomatik artırıyor; elle derliyorsanız `CURRENT_PROJECT_VERSION` değerini artırın.

**`Missing compliance` (TestFlight'ta uygulama "İşleniyor"da takılı)**
`ITSAppUsesNonExemptEncryption` anahtarı `Info.plist` içinde `false` olarak var; bu hatayı görüyorsanız Info.plist derlemeye girmemiş demektir.

**AdMob "Uygulamanız bulunamadı" uyarısı**
Uygulama App Store'da yayınlandıktan sonra AdMob'daki kaydı mağaza listesiyle eşleştirin. Eşleşmeden app-ads.txt doğrulanmaz.

---

## 17. Bilinçli olarak yapılmayanlar

Yapılmayan her şey bir tercih; sebebi de burada duruyor ki ileride yeniden tartışmak zorunda kalmayın.

**Her soruda yeni reklam.** Web tarafında da konuşmuştuk: bir soru ~8 saniyede cevaplanıyor, her soruda yenileme dakikada 7-8 gösterim demek. AdMob'un geçersiz trafik politikasının en net ihlali ve olağan sonucu hesabın askıya alınıp birikmiş kazancın iade edilmemesi. Gelir kaybı sandığınızdan az: AdMob yenileme sayısına değil gösterim kalitesine göre ödüyor.

**Geçiş reklamı (interstitial).** Oturum bitişinde tam ekran reklam gelir gibi görünüyor ama bu ekran kullanıcının başarısını gördüğü an — motivasyonun en yüksek olduğu yer. Oraya tam ekran reklam koymak elde tutma oranını doğrudan düşürüyor. Banner aynı yerde, bölmeden duruyor.

**iCloud senkronizasyon.** İstemediniz ve şu hâliyle gerek de yok: veri cihazda küçük ve tek cihazda çalışılıyor. Eklenmek istenirse `ProgressStore` tek yazma noktası olduğu için CloudKit'i oraya bağlamak yeterli — mimari buna hazır.

**Sesli okuma (TTS).** İstemediniz. `AVSpeechSynthesizer` ile eklemek yarım saatlik iş; `RevealCard` içine bir düğme yeter.

**Capacitor / WebView sarmalayıcı.** En hızlı yol olurdu ama Apple Guideline 4.2 gereği "ince web sarmalayıcı" uygulamaları reddediyor. Native yazmak hem bu riski kaldırdı hem çevrimdışı çalışma, widget ve bildirim gibi platform özelliklerini mümkün kıldı.

**Otomatik imzalama (Automatic signing).** CI'da otomatik imzalama, Xcode'un Apple hesabınıza etkileşimli olarak bağlanmasını gerektirir; başsız (headless) bir makinede güvenilir çalışmaz. Manuel imzalama + `xcode-project use-profiles` daha uzun bir kurulum ama tekrarlanabilir.

**`.xcodeproj` dosyasının depoda tutulması.** Birleştirilemez, Windows'ta düzenlenemez, kim ne değiştirdi görünmez. `project.yml` okunabilir ve gözden geçirilebilir.

---

## Lisans ve içerik

Kelime listesi, örnek cümleler ve çevirileri **Doğa ve Eren ÜSTÜNER**'e ait; web sitesiyle aynı içerik.

---

*Son güncelleme: 29 Temmuz 2026 · Veri sürümü: 781 kart (622 kelime + 159 phrasal verb)*
