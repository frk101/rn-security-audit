#!/usr/bin/env bash
# Obfuscation, ProGuard/R8 ve build güvenliği kontrolleri

PROJECT_DIR="${1:-$PROJECT_DIR}"
BUILD_GRADLE="$PROJECT_DIR/android/app/build.gradle"
PROGUARD="$PROJECT_DIR/android/app/proguard-rules.pro"
METRO="$PROJECT_DIR/metro.config.js"

pass() { echo -e "${GREEN}  [GEÇTI]${NC} $1"; echo "PASS:$1" >> /tmp/rn_audit_results; }
warn() { echo -e "${YELLOW}  [UYARI]${NC} $1"; echo "WARN:$1" >> /tmp/rn_audit_results; }
fail() { echo -e "${RED}  [KRITIK]${NC} $1"; echo -e "  ${YELLOW}  → Öneri:${NC} $2"; echo "FAIL:$1" >> /tmp/rn_audit_results; }

# 1. ProGuard aktif mi?
if [[ -f "$BUILD_GRADLE" ]]; then
  if grep -q 'enableProguardInReleaseBuilds\s*=\s*true' "$BUILD_GRADLE"; then
    pass "ProGuard/R8 release build'de aktif"
  else
    fail "ProGuard/R8 kapalı — native kod obfuscate edilmiyor" \
         "build.gradle içinde: def enableProguardInReleaseBuilds = true"
  fi

  # shrinkResources
  if grep -q 'shrinkResources' "$BUILD_GRADLE"; then
    pass "shrinkResources aktif"
  else
    warn "shrinkResources tanımlanmamış — kullanılmayan kaynaklar APK'ya giriyor"
  fi

  # optimize proguard
  if grep -q 'proguard-android-optimize' "$BUILD_GRADLE"; then
    pass "proguard-android-optimize.txt kullanılıyor"
  else
    warn "proguard-android.txt kullanılıyor — daha agresif optimizasyon için proguard-android-optimize.txt tercih edin"
  fi

  # Hermes source map
  if grep -E 'hermesFlags\s*=\s*\[.*-output-source-map' "$BUILD_GRADLE" | grep -v '//' | grep -q .; then
    fail "Hermes -output-source-map flag'i aktif — source map APK'ya gömülüyor" \
         "hermesFlags = [\"-O\"] olarak değiştirin, -output-source-map'i kaldırın."
  else
    pass "Hermes source map production'a gömülmüyor"
  fi
else
  warn "android/app/build.gradle bulunamadı"
fi

# 2. ProGuard kuralları yeterli mi?
if [[ -f "$PROGUARD" ]]; then
  RULE_COUNT=$(grep -c '^-' "$PROGUARD" 2>/dev/null || echo 0)
  if [[ "$RULE_COUNT" -lt 5 ]]; then
    warn "proguard-rules.pro çok az kural içeriyor ($RULE_COUNT satır) — React Native keep kuralları eksik olabilir"
  else
    pass "proguard-rules.pro tanımlanmış ($RULE_COUNT kural)"
  fi

  # Log stripping
  if grep -q 'assumenosideeffects.*android.util.Log' "$PROGUARD"; then
    pass "Log.* çağrıları release'de kaldırılıyor"
  else
    warn "Log.* stripping tanımlanmamış — debug logları production APK'ya girebilir"
  fi
else
  warn "proguard-rules.pro bulunamadı"
fi

# 3. Metro config — JS minification
if [[ -f "$METRO" ]]; then
  if grep -q 'drop_console' "$METRO"; then
    pass "Metro config'de console.* stripping tanımlanmış"
  else
    warn "Metro config'de drop_console yok — console.log'lar production bundle'a girebilir"
  fi
else
  warn "metro.config.js bulunamadı"
fi

# 4. Tamper detection
TAMPER_FILE=$(find "$PROJECT_DIR/android" -name "TamperDetection*.kt" 2>/dev/null | head -1)
if [[ -n "$TAMPER_FILE" ]]; then
  pass "TamperDetection sınıfı mevcut"
else
  warn "Tamper detection (APK imza doğrulaması) bulunamadı — modifiye APK tespiti için eklenebilir"
fi

# 5. Root detection
ROOT_FILE=$(find "$PROJECT_DIR/android" -name "RootDetection*.kt" 2>/dev/null | head -1)
if [[ -n "$ROOT_FILE" ]]; then
  pass "RootDetection sınıfı mevcut"
else
  warn "Root detection bulunamadı — rooted cihaz tespiti için eklenebilir"
fi

# 6. Bundle içinde build path sızıntısı (varsa bundle)
BUNDLE="$PROJECT_DIR/android/app/src/main/assets/index.android.bundle"
if [[ -f "$BUNDLE" ]]; then
  if grep -q '/home/runner\|/Users/\|/root/' "$BUNDLE" 2>/dev/null; then
    fail "Bundle içinde CI/geliştirici build path'i sızıyor" \
         "Metro minification'ı aktif edin ve source map'leri bundle'dan çıkarın."
  else
    pass "Bundle içinde build path sızıntısı tespit edilmedi"
  fi
else
  warn "Derlenmiş bundle bulunamadı — kontrol atlandı (release build sonrası tekrar çalıştırın)"
fi
