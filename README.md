# RN Security Audit

React Native mobil uygulamalarda güvenlik açıklarını otomatik olarak tespit eden araç.

Projenin dizinini ver, çalıştır — sana ne eksik, ne tehlikeli, nasıl düzeltirsin söyler.

---

## Kurulum (Bir kez yapılır)

### Node.js kurulu olmalı

Node.js yoksa: [nodejs.org](https://nodejs.org) adresinden **LTS** sürümü indir ve kur.

### Paketi global olarak yükle

```bash
npm install -g rn-security-audit
```

Bu kadar. Artık bilgisayarında her yerden kullanılabilir.

---

## Kullanım (Her yeni proje için)

Terminal'i aç ve şunu yaz:

```bash
rn-security-audit /PROJE/DIZINI
```

**Örnek:**
```bash
rn-security-audit ~/Documents/benim-uygulama
```

> Proje dizini = `package.json` dosyasının bulunduğu klasör.

**Dizini bilmiyorsan:** Terminalde projenin içindeyken `pwd` yaz, çıkan yolu kopyala.

---

## Tek seferlik çalıştırmak için (yükleme yapmadan)

```bash
npx rn-security-audit /PROJE/DIZINI
```

---

## Sonuçları Okuma

Çalıştırınca şuna benzer bir çıktı göreceksin:

```
━━━ 1. AndroidManifest Güvenlik Kontrolleri
  [GEÇTİ]    usesCleartextTraffic kapalı
  [KRİTİK]   allowBackup eksik
             → Öneri: android:allowBackup="false" ekleyin.
  [UYARI]    dataExtractionRules tanımlanmamış

━━━ 2. Hardcoded Credential & Email Sızıntısı
  [KRİTİK]   Hardcoded şifre tespit edildi
             src/slices/token.slice.ts:74: password: 'sifre123'
             → Öneri: Şifreyi .env dosyasına taşıyın.

=================================================
   ÖZET
=================================================
  GEÇTİ    : 24
  UYARI    : 3
  BAŞARISIZ: 2
```

### Ne anlama geliyor?

| Etiket | Anlamı | Ne yapmalısın? |
|--------|--------|----------------|
| `[GEÇTİ]` | Bu kontrol tamam, sorun yok | Bir şey yapma |
| `[UYARI]` | Sorun olabilir, dikkat et | İnce, gerekiyorsa düzelt |
| `[KRİTİK]` | Güvenlik açığı var | Mutlaka düzelt, altındaki öneriyi uygula |

Her `[KRİTİK]` satırının hemen altında `→ Öneri:` yazar — tam olarak ne yapman gerektiğini söyler.

---

## Ne Kontrol Eder?

### 1. AndroidManifest Güvenlik Kontrolleri
Uygulamanın temel Android güvenlik ayarlarını kontrol eder.
- HTTP trafiğine izin veriliyor mu?
- Yedekleme (backup) açık mı?
- Debug modu production'da aktif mi?

### 2. iOS Info.plist & ATS Kontrolleri
iOS tarafında güvenlik ayarlarını ve izin açıklamalarını kontrol eder.
- App Transport Security (ATS) kapatılmış mı? (`NSAllowsArbitraryLoads`)
- İzin açıklamaları (`NSCameraUsageDescription` vb.) eksik veya boş mu?
- iTunes File Sharing açık mı? (`UIFileSharingEnabled`)
- WebView'da file URL erişimi açık mı?
- Hassas veri AsyncStorage yerine Keychain'de mi saklanıyor?
- Hermes iOS'ta etkin mi?
- Release build'de DEBUG makrosu kalmış mı?

### 3. Hardcoded Credential & Email Sızıntısı
Kaynak koduna gömülmüş şifre, email, API anahtarı arar.
- Şifre doğrudan koda yazılmış mı?
- Çalışan email adresleri bundle'a sızmış mı?
- `.env` dosyası yanlışlıkla git'e atılmış mı?

### 4. Ağ Güvenliği Yapılandırması
Uygulamanın sunucuyla güvenli konuşup konuşmadığını kontrol eder.
- Certificate pinning var mı?
- HTTP (şifresiz) bağlantıya izin veriliyor mu?
- Ağ güvenlik config dosyası doğru yapılandırılmış mı?

### 5. İzin (Permission) Analizi
Uygulamanın istediği Android izinlerini inceler.
- Gereksiz izin var mı? (GPS, depolama, mikrofon vb.)
- Kullanıcıya izin neden istendiği açıklanıyor mu?

### 6. Obfuscation & Build Güvenliği
Uygulamanın tersine mühendisliğe karşı korunup korunmadığını kontrol eder.
- ProGuard/R8 açık mı? (kod karmaşıklaştırma)
- Source map production APK'ya gömülmüş mü?
- Root/jailbreak tespiti var mı?
- APK imza doğrulaması var mı?

### 7. Bağımlılık Güvenliği
Kullandığın kütüphanelerde bilinen açık olup olmadığını kontrol eder.
- `npm audit` çalıştırır, kritik açıkları raporlar
- Riskli paket kullanımı var mı?
- Versiyon kilidi (lock dosyası) var mı?

---

## CI/CD'ye Eklemek (GitHub Actions)

Her PR açıldığında otomatik çalışmasını istersen, hazır GitHub Action'ı kullan:

```yaml
# .github/workflows/security-audit.yml
name: Security Audit
on: [push, pull_request]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: frk101/rn-security-audit@v1
        with:
          project-dir: '.'         # opsiyonel, varsayılan repo kökü
          fail-on: 'critical'      # critical | warning | none
```

### Inputs

| Input | Varsayılan | Açıklama |
|-------|-----------|----------|
| `project-dir` | `.` | Taranacak proje dizini |
| `fail-on` | `critical` | `critical`: sadece kritik varsa build düşer, `warning`: uyarı bile olsa düşer, `none`: hiç düşmez |

### Outputs

| Output | Açıklama |
|--------|----------|
| `pass-count` | Geçen kontrol sayısı |
| `warn-count` | Uyarı sayısı |
| `fail-count` | Kritik bulgu sayısı |

Her run sonunda GitHub Actions sekmesindeki **Summary**'de özet tablo otomatik gösterilir.

---

## Sık Sorulan Sorular

**Proje dizinini nasıl bulurum?**
Terminal'de projenin içindeyken `pwd` yaz, dizini kopyala.

**"Permission denied" hatası alıyorum.**
```bash
chmod +x ~/Documents/rn-security-audit/scripts/audit.sh
chmod +x ~/Documents/rn-security-audit/scripts/checks/*.sh
```

**"No such file or directory" hatası alıyorum.**
Proje dizinini yanlış yazmış olabilirsin. Dizinin doğru olduğunu kontrol et:
```bash
ls /PROJE/DIZINI/package.json
```
Bu komut dosyayı listeliyorsa dizin doğrudur.

**Tek bir kontrolü çalıştırabilir miyim?**
Evet:
```bash
bash ~/Documents/rn-security-audit/scripts/checks/credentials.sh /PROJE/DIZINI
```
