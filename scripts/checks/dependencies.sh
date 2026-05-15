#!/usr/bin/env bash
# Bağımlılık güvenliği kontrolleri

PROJECT_DIR="${1:-$PROJECT_DIR}"
PKG="$PROJECT_DIR/package.json"

pass() { echo -e "${GREEN}  [GEÇTI]${NC} $1"; echo "PASS:$1" >> /tmp/rn_audit_results; }
warn() { echo -e "${YELLOW}  [UYARI]${NC} $1"; echo "WARN:$1" >> /tmp/rn_audit_results; }
fail() { echo -e "${RED}  [KRITIK]${NC} $1"; echo -e "  ${YELLOW}  → Öneri:${NC} $2"; echo "FAIL:$1" >> /tmp/rn_audit_results; }
info() { echo -e "  ${BLUE}  ℹ${NC}  $1"; }

if [[ ! -f "$PKG" ]]; then
  warn "package.json bulunamadı"
  exit 0
fi

# 1. npm audit (varsa)
if command -v npm &>/dev/null; then
  echo -e "  npm audit çalıştırılıyor..."
  cd "$PROJECT_DIR"
  AUDIT_OUTPUT=$(npm audit --json 2>/dev/null || true)
  CRITICAL=$(echo "$AUDIT_OUTPUT" | grep -o '"critical":[0-9]*' | grep -o '[0-9]*' | head -1 || echo "0")
  HIGH=$(echo "$AUDIT_OUTPUT" | grep -o '"high":[0-9]*' | grep -o '[0-9]*' | head -1 || echo "0")

  if [[ "$CRITICAL" -gt 0 ]]; then
    fail "$CRITICAL kritik güvenlik açığı tespit edildi" \
         "npm audit fix --force çalıştırın ve raporu inceleyin."
  elif [[ "$HIGH" -gt 0 ]]; then
    warn "$HIGH yüksek öncelikli güvenlik açığı tespit edildi — npm audit fix ile düzeltin"
  else
    pass "npm audit: kritik/yüksek güvenlik açığı yok"
  fi
else
  warn "npm bulunamadı — bağımlılık açığı taraması atlandı"
fi

# 2. Güvenlik açısından riskli paketler
RISKY_PACKAGES=(
  "react-native-sensitive-info:Hassas veri depolama — Keychain/Keystore doğru yapılandırılmalı"
  "react-native-fs:Dosya sistemi erişimi — hangi dizinlerin erişildiğini gözden geçirin"
  "react-native-fetch-blob:Dosya indirme — hedef dizin ve dosya adı doğrulaması yapın"
  "react-native-blob-util:Dosya I/O — depolama izinlerinin minimize edildiğinden emin olun"
)

for entry in "${RISKY_PACKAGES[@]}"; do
  pkg="${entry%%:*}"
  msg="${entry#*:}"
  if grep -q "\"$pkg\"" "$PKG"; then
    warn "$pkg kullanılıyor — $msg"
  fi
done

# 3. react-native-config kurulu mu?
if grep -q '"react-native-config"' "$PKG"; then
  pass "react-native-config kurulu — env değişkenleri kaynak koddan ayrılmış"
else
  warn "react-native-config kurulu değil — API key/şifre gibi değerleri .env ile yönetin: npm install react-native-config"
fi

# 4. Güvenlik araçları
if grep -q '"react-native-jailbreak-detect"\|"react-native-jail"\|"jail-monkey"' "$PKG"; then
  pass "Jailbreak/root detection kütüphanesi kurulu"
else
  info "Üçüncü taraf root/jailbreak detection kütüphanesi bulunamadı (native implementasyon varsa normal)"
fi

# 5. package.json'da lock dosyası var mı?
if [[ -f "$PROJECT_DIR/package-lock.json" ]] || [[ -f "$PROJECT_DIR/yarn.lock" ]]; then
  pass "Lock dosyası mevcut — bağımlılık versiyonları sabitlenmiş"
else
  fail "Lock dosyası yok — bağımlılık versiyonları sabitlenmemiş" \
       "npm install veya yarn install ile lock dosyası oluşturun ve git'e commit edin."
fi

# 6. Wildcard versiyon kullanımı
WILDCARD_COUNT=$(grep -E '"[*^~]' "$PKG" | grep -v "devDependencies" | wc -l | tr -d ' ' || echo 0)
if [[ "$WILDCARD_COUNT" -gt 5 ]]; then
  warn "$WILDCARD_COUNT bağımlılık wildcard versiyon kullanıyor (^, ~, *) — beklenmedik güvenlik açığı içeren sürüm çekilebilir"
fi
