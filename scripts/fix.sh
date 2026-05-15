#!/usr/bin/env bash
# Otomatik düzeltme scripti — güvenli olan kritik güvenlik ayarlarını uygular

PROJECT_DIR="${1:-$PROJECT_DIR}"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

fixed() { echo -e "${GREEN}  ✓${NC} $1"; }
skipped() { echo -e "${BLUE}  •${NC} $1"; }
warned() { echo -e "${YELLOW}  ⚠${NC} $1"; }

FIXED_COUNT=0
inc() { FIXED_COUNT=$((FIXED_COUNT + 1)); }

echo ""
echo -e "${BOLD}━━━ Otomatik Düzeltmeler Uygulanıyor${NC}"
echo ""

# ============================================================
# 1. .env dosyasını .gitignore'a ekle
# ============================================================
GITIGNORE="$PROJECT_DIR/.gitignore"
ENV_FILE="$PROJECT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  if [[ ! -f "$GITIGNORE" ]] || ! grep -qE '^\.env$|^\.env\s' "$GITIGNORE"; then
    echo ".env" >> "$GITIGNORE"
    fixed ".env → .gitignore'a eklendi"
    inc

    # Eğer git'e commit edilmişse cache'ten çıkar
    if (cd "$PROJECT_DIR" && git ls-files --error-unmatch .env >/dev/null 2>&1); then
      (cd "$PROJECT_DIR" && git rm --cached .env >/dev/null 2>&1) && \
        fixed ".env git cache'inden çıkarıldı (commit etmen gerekiyor)" && inc
      warned "Eğer .env'de gerçek secret varsa rotate et — git history'de hala görünüyor"
    fi
  else
    skipped ".env zaten .gitignore'da"
  fi
fi

# ============================================================
# 2. AndroidManifest: allowBackup="false" ekle
# ============================================================
MANIFEST="$PROJECT_DIR/android/app/src/main/AndroidManifest.xml"
if [[ -f "$MANIFEST" ]]; then
  if ! grep -q 'android:allowBackup' "$MANIFEST"; then
    # <application etiketinin içine ekle
    if grep -q '<application' "$MANIFEST"; then
      sed -i.bak 's|<application|<application\n      android:allowBackup="false"|' "$MANIFEST"
      rm -f "$MANIFEST.bak"
      fixed "AndroidManifest: android:allowBackup=\"false\" eklendi"
      inc
    fi
  else
    skipped "AndroidManifest: allowBackup zaten tanımlı"
  fi

  # 3. networkSecurityConfig ekle
  if ! grep -q 'networkSecurityConfig' "$MANIFEST"; then
    NSC_DIR="$PROJECT_DIR/android/app/src/main/res/xml"
    NSC_FILE="$NSC_DIR/network_security_config.xml"

    mkdir -p "$NSC_DIR"
    if [[ ! -f "$NSC_FILE" ]]; then
      cat > "$NSC_FILE" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
</network-security-config>
EOF
      fixed "network_security_config.xml oluşturuldu"
      inc
    fi

    sed -i.bak 's|<application|<application\n      android:networkSecurityConfig="@xml/network_security_config"|' "$MANIFEST"
    rm -f "$MANIFEST.bak"
    fixed "AndroidManifest: networkSecurityConfig referansı eklendi"
    inc
  else
    skipped "AndroidManifest: networkSecurityConfig zaten tanımlı"
  fi
fi

# ============================================================
# 4. build.gradle: ProGuard aç
# ============================================================
BUILD_GRADLE="$PROJECT_DIR/android/app/build.gradle"
if [[ -f "$BUILD_GRADLE" ]]; then
  if grep -q 'enableProguardInReleaseBuilds = false' "$BUILD_GRADLE"; then
    sed -i.bak 's|enableProguardInReleaseBuilds = false|enableProguardInReleaseBuilds = true|' "$BUILD_GRADLE"
    rm -f "$BUILD_GRADLE.bak"
    fixed "build.gradle: ProGuard release build için açıldı"
    inc
  else
    skipped "build.gradle: ProGuard ayarı zaten açık ya da farklı tanımlı"
  fi
fi

# ============================================================
# 5. metro.config.js: drop_console ekle
# ============================================================
METRO_CONFIG="$PROJECT_DIR/metro.config.js"
if [[ -f "$METRO_CONFIG" ]]; then
  if ! grep -q 'drop_console' "$METRO_CONFIG"; then
    warned "metro.config.js: drop_console eklenebilir — ama otomatik düzeltmedik (config yapısı projeye göre değişiyor)"
    echo -e "    ${BLUE}Manuel ekle:${NC}"
    echo -e "    transformer: { minifierConfig: { compress: { drop_console: true } } }"
  else
    skipped "metro.config.js: drop_console zaten tanımlı"
  fi
fi

# ============================================================
# 6. Podfile: Hermes aç
# ============================================================
PODFILE="$PROJECT_DIR/ios/Podfile"
if [[ -f "$PODFILE" ]]; then
  if grep -q ':hermes_enabled => false\|hermes_enabled.*false' "$PODFILE"; then
    sed -i.bak 's|:hermes_enabled => false|:hermes_enabled => true|g; s|hermes_enabled.*false|hermes_enabled => true|g' "$PODFILE"
    rm -f "$PODFILE.bak"
    fixed "Podfile: Hermes iOS için açıldı (cd ios && pod install gerekiyor)"
    inc
  else
    skipped "Podfile: Hermes zaten açık ya da farklı tanımlı"
  fi
fi

# ============================================================
# 7. .env.example oluştur
# ============================================================
ENV_EXAMPLE="$PROJECT_DIR/.env.example"
if [[ -f "$ENV_FILE" && ! -f "$ENV_EXAMPLE" ]]; then
  # .env'deki anahtarları al ama değerleri boşalt
  sed 's/=.*/=/' "$ENV_FILE" > "$ENV_EXAMPLE"
  fixed ".env.example oluşturuldu (anahtarlar var, değerler boş)"
  inc
fi

# ============================================================
# Özet
# ============================================================
echo ""
if [[ "$FIXED_COUNT" -eq 0 ]]; then
  echo -e "${BLUE}Otomatik düzeltilecek bir şey bulunamadı (zaten düzgün ya da manuel müdahale gerekiyor).${NC}"
else
  echo -e "${GREEN}${BOLD}$FIXED_COUNT düzeltme uygulandı.${NC}"
  echo -e "${YELLOW}Sonraki adımlar:${NC}"
  echo -e "  1. ${BLUE}git diff${NC} ile değişiklikleri incele"
  echo -e "  2. iOS değiştiyse: ${BLUE}cd ios && pod install${NC}"
  echo -e "  3. Tekrar tara: ${BLUE}npx rn-security-audit .${NC}"
  echo -e "  4. Beğendiysen commit et"
fi
echo ""
