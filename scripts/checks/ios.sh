#!/usr/bin/env bash
# iOS güvenlik kontrolleri — Info.plist, ATS, izinler, URL Schemes

PROJECT_DIR="${1:-$PROJECT_DIR}"

pass() { echo -e "${GREEN}  [GEÇTI]${NC} $1"; echo "PASS:$1" >> /tmp/rn_audit_results; }
warn() { echo -e "${YELLOW}  [UYARI]${NC} $1"; echo "WARN:$1" >> /tmp/rn_audit_results; }
fail() { echo -e "${RED}  [KRITIK]${NC} $1"; echo -e "  ${YELLOW}  → Öneri:${NC} $2"; echo "FAIL:$1" >> /tmp/rn_audit_results; }

IOS_DIR="$PROJECT_DIR/ios"

if [[ ! -d "$IOS_DIR" ]]; then
  warn "ios/ dizini bulunamadı — iOS kontrolleri atlandı (sadece Android projesi olabilir)"
  exit 0
fi

# Info.plist dosyalarını bul (genelde ios/<AppName>/Info.plist)
PLISTS=$(find "$IOS_DIR" -name "Info.plist" -not -path "*/Pods/*" -not -path "*/build/*" 2>/dev/null)

if [[ -z "$PLISTS" ]]; then
  fail "Info.plist bulunamadı" "ios/<AppName>/Info.plist dosyasının var olduğundan emin olun."
  exit 0
fi

for PLIST in $PLISTS; do
  REL_PATH="${PLIST#$PROJECT_DIR/}"

  # 1. App Transport Security (ATS) - NSAllowsArbitraryLoads
  if grep -A1 'NSAllowsArbitraryLoads' "$PLIST" 2>/dev/null | grep -q '<true/>'; then
    fail "ATS devre dışı — NSAllowsArbitraryLoads=true ($REL_PATH)" \
         "NSAllowsArbitraryLoads'ı kaldırın veya false yapın. Belirli domain'ler için NSExceptionDomains kullanın."
  elif grep -q 'NSAllowsArbitraryLoads' "$PLIST" 2>/dev/null; then
    pass "ATS aktif — NSAllowsArbitraryLoads false ($REL_PATH)"
  else
    pass "ATS varsayılan ayarlarda aktif ($REL_PATH)"
  fi

  # 2. NSAllowsArbitraryLoadsInWebContent
  if grep -A1 'NSAllowsArbitraryLoadsInWebContent' "$PLIST" 2>/dev/null | grep -q '<true/>'; then
    warn "NSAllowsArbitraryLoadsInWebContent=true — WebView'da HTTP içeriğe izin veriliyor ($REL_PATH)"
  fi

  # 3. NSExceptionAllowsInsecureHTTPLoads
  if grep -q 'NSExceptionAllowsInsecureHTTPLoads.*true\|NSExceptionAllowsInsecureHTTPLoads' "$PLIST" 2>/dev/null; then
    if grep -A1 'NSExceptionAllowsInsecureHTTPLoads' "$PLIST" | grep -q '<true/>'; then
      warn "NSExceptionAllowsInsecureHTTPLoads=true bir domain için HTTP'ye izin veriyor ($REL_PATH)"
    fi
  fi

  # 4. İzin açıklamaları (Usage Description) — boş veya generic olmamalı
  PERMISSION_KEYS=(
    "NSCameraUsageDescription:Kamera"
    "NSMicrophoneUsageDescription:Mikrofon"
    "NSPhotoLibraryUsageDescription:Fotoğraf Galerisi"
    "NSPhotoLibraryAddUsageDescription:Fotoğraf Ekleme"
    "NSLocationWhenInUseUsageDescription:Konum (kullanımda)"
    "NSLocationAlwaysAndWhenInUseUsageDescription:Konum (her zaman)"
    "NSContactsUsageDescription:Rehber"
    "NSCalendarsUsageDescription:Takvim"
    "NSRemindersUsageDescription:Hatırlatıcılar"
    "NSBluetoothAlwaysUsageDescription:Bluetooth"
    "NSFaceIDUsageDescription:Face ID"
    "NSAppleMusicUsageDescription:Apple Music"
    "NSMotionUsageDescription:Hareket sensörü"
    "NSSpeechRecognitionUsageDescription:Konuşma tanıma"
    "NSHealthShareUsageDescription:Sağlık verisi"
  )

  for entry in "${PERMISSION_KEYS[@]}"; do
    KEY="${entry%%:*}"
    LABEL="${entry##*:}"
    if grep -q "$KEY" "$PLIST" 2>/dev/null; then
      DESC=$(grep -A1 "$KEY" "$PLIST" | tail -1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
      if [[ -z "$DESC" || "$DESC" =~ ^\ *$ ]]; then
        fail "$LABEL izni var ama açıklama boş ($KEY)" \
             "Kullanıcıya neden bu izne ihtiyaç duyduğunuzu açıklayan bir metin ekleyin."
      elif [[ ${#DESC} -lt 15 ]]; then
        warn "$LABEL izin açıklaması çok kısa: \"$DESC\" — Apple reddedebilir"
      fi
    fi
  done

  # 5. URL Schemes — custom scheme tanımlı mı, validasyon var mı?
  if grep -q 'CFBundleURLSchemes' "$PLIST" 2>/dev/null; then
    warn "Custom URL Scheme tanımlı — deep link açıldığında kaynak doğrulaması yapıldığından emin olun ($REL_PATH)"
  fi

  # 6. UIFileSharingEnabled — iTunes File Sharing
  if grep -A1 'UIFileSharingEnabled' "$PLIST" 2>/dev/null | grep -q '<true/>'; then
    fail "UIFileSharingEnabled=true — uygulama dosyaları iTunes/Finder ile dışarı çıkarılabilir ($REL_PATH)" \
         "Hassas veri tutuyorsanız bu özelliği false yapın veya kaldırın."
  fi

  # 7. LSSupportsOpeningDocumentsInPlace
  if grep -A1 'LSSupportsOpeningDocumentsInPlace' "$PLIST" 2>/dev/null | grep -q '<true/>'; then
    warn "LSSupportsOpeningDocumentsInPlace=true — Files uygulamasından dosya erişimine izin veriliyor"
  fi
done

# 8. AppDelegate'te WebView güvenliği
APPDELEGATE=$(find "$IOS_DIR" -name "AppDelegate.m" -o -name "AppDelegate.mm" -o -name "AppDelegate.swift" 2>/dev/null | head -1)
if [[ -n "$APPDELEGATE" ]]; then
  if grep -q 'allowFileAccessFromFileURLs\|allowUniversalAccessFromFileURLs' "$APPDELEGATE" 2>/dev/null; then
    fail "WebView'da file URL erişimi açık ($APPDELEGATE)" \
         "allowFileAccessFromFileURLs ve allowUniversalAccessFromFileURLs ayarlarını kapatın."
  fi
fi

# 9. Keychain kullanımı (hassas veri AsyncStorage yerine Keychain'de olmalı)
KEYCHAIN_USE=$(grep -r "react-native-keychain\|RNSecureStorage\|react-native-encrypted-storage" "$PROJECT_DIR/package.json" 2>/dev/null || true)
ASYNC_TOKEN=$(grep -r "AsyncStorage.setItem.*token\|AsyncStorage.setItem.*password\|AsyncStorage.setItem.*secret" "$PROJECT_DIR/src" 2>/dev/null | head -3 || true)

if [[ -n "$ASYNC_TOKEN" && -z "$KEYCHAIN_USE" ]]; then
  fail "AsyncStorage'da token/şifre saklanıyor ama Keychain kütüphanesi yok" \
       "react-native-keychain veya react-native-encrypted-storage kullanın. AsyncStorage şifrelenmez."
elif [[ -n "$KEYCHAIN_USE" ]]; then
  pass "Güvenli depolama kütüphanesi kurulu (Keychain/EncryptedStorage)"
fi

# 10. Provisioning profile / bundle identifier kontrolü
PBXPROJ=$(find "$IOS_DIR" -name "project.pbxproj" -not -path "*/Pods/*" 2>/dev/null | head -1)
if [[ -n "$PBXPROJ" ]]; then
  if grep -q 'CODE_SIGN_IDENTITY = "iPhone Developer"' "$PBXPROJ" 2>/dev/null; then
    warn "Release config'de development imzası kullanılıyor olabilir — production için Distribution sertifikası kullanın"
  fi

  # Debug log'ları release'te bırakma
  if grep -A2 'name = Release' "$PBXPROJ" 2>/dev/null | grep -q 'GCC_PREPROCESSOR_DEFINITIONS.*DEBUG=1'; then
    fail "Release build'de DEBUG=1 tanımlı" \
         "Release configuration'dan DEBUG=1 makrosunu kaldırın."
  fi
fi

# 11. Hermes / JS bundle koruması (iOS tarafı)
if [[ -f "$PROJECT_DIR/ios/Podfile" ]]; then
  if grep -q ":hermes_enabled => true\|hermes_enabled.*true" "$PROJECT_DIR/ios/Podfile" 2>/dev/null; then
    pass "Hermes iOS'ta etkin — JS bytecode olarak derleniyor (tersine mühendislik zorlaşır)"
  else
    warn "Hermes iOS'ta etkin değil — JS bundle düz metin olarak okunabilir"
  fi
fi
