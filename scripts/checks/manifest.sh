#!/usr/bin/env bash
# AndroidManifest.xml güvenlik kontrolleri

PROJECT_DIR="${1:-$PROJECT_DIR}"
MANIFEST="$PROJECT_DIR/android/app/src/main/AndroidManifest.xml"

pass() { echo -e "${GREEN}  [GEÇTI]${NC} $1"; echo "PASS:$1" >> /tmp/rn_audit_results; }
warn() { echo -e "${YELLOW}  [UYARI]${NC} $1"; echo "WARN:$1" >> /tmp/rn_audit_results; }
fail() { echo -e "${RED}  [KRITIK]${NC} $1"; echo -e "  ${YELLOW}  → Öneri:${NC} $2"; echo "FAIL:$1" >> /tmp/rn_audit_results; }

if [[ ! -f "$MANIFEST" ]]; then
  fail "AndroidManifest.xml bulunamadı" "android/app/src/main/AndroidManifest.xml dosyasını kontrol edin."
  exit 0
fi

# 1. usesCleartextTraffic
if grep -q 'usesCleartextTraffic="false"' "$MANIFEST"; then
  pass "usesCleartextTraffic false olarak ayarlanmış"
elif grep -q 'usesCleartextTraffic="true"' "$MANIFEST"; then
  fail "usesCleartextTraffic=true — HTTP trafiğine izin veriliyor" \
       "android:usesCleartextTraffic=\"false\" olarak değiştirin."
else
  warn "usesCleartextTraffic açıkça tanımlanmamış — varsayılan davranış platforma göre değişir"
fi

# 2. networkSecurityConfig
if grep -q 'networkSecurityConfig' "$MANIFEST"; then
  pass "networkSecurityConfig tanımlanmış"
else
  fail "networkSecurityConfig eksik" \
       "res/xml/network_security_config.xml oluşturun ve manifest'e android:networkSecurityConfig=\"@xml/network_security_config\" ekleyin."
fi

# 3. allowBackup
if grep -q 'allowBackup="false"' "$MANIFEST"; then
  pass "allowBackup=false — yedekleme devre dışı"
else
  fail "allowBackup=false eksik — uygulama verisi ADB/cloud backup ile çekilebilir" \
       "android:allowBackup=\"false\" ekleyin."
fi

# 4. debuggable
if grep -q 'android:debuggable="true"' "$MANIFEST"; then
  fail "debuggable=true production manifest'te — ADB debug bağlantısına açık" \
       "android:debuggable=\"true\" satırını kaldırın, sadece debug build variant'ında olmalı."
else
  pass "debuggable=true production manifest'te yok"
fi

# 5. exported activity & intent-filter
EXPORTED=$(grep -c 'android:exported="true"' "$MANIFEST" || true)
if [[ "$EXPORTED" -gt 2 ]]; then
  warn "$EXPORTED adet exported=true activity/service var — her birinin gerçekten dışarıya açık olması gerekip gerekmediğini kontrol edin"
else
  pass "exported=true sayısı makul ($EXPORTED)"
fi

# 6. backup rules (Android 12+)
if grep -q 'dataExtractionRules\|fullBackupContent' "$MANIFEST"; then
  pass "Backup kuralları tanımlanmış"
else
  warn "dataExtractionRules tanımlanmamış — Android 12+ için hassas veri backup dışına alınmalı"
fi
