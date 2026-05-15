#!/usr/bin/env bash
# Hardcoded credential ve email sızıntısı kontrolü

PROJECT_DIR="${1:-$PROJECT_DIR}"
SRC_DIRS=()
for d in src app lib; do
  [[ -d "$PROJECT_DIR/$d" ]] && SRC_DIRS+=("$PROJECT_DIR/$d")
done
[[ -f "$PROJECT_DIR/App.tsx" ]] && SRC_DIRS+=("$PROJECT_DIR/App.tsx")
[[ -f "$PROJECT_DIR/index.js" ]] && SRC_DIRS+=("$PROJECT_DIR/index.js")

pass() { echo -e "${GREEN}  [GEÇTI]${NC} $1"; echo "PASS:$1" >> /tmp/rn_audit_results; }
warn() { echo -e "${YELLOW}  [UYARI]${NC} $1"; echo "WARN:$1" >> /tmp/rn_audit_results; }
fail() { echo -e "${RED}  [KRITIK]${NC} $1"; echo -e "  ${YELLOW}  → Öneri:${NC} $2"; echo "FAIL:$1" >> /tmp/rn_audit_results; }

if [[ ${#SRC_DIRS[@]} -eq 0 ]]; then
  warn "Kaynak dizini bulunamadı (src/, app/, lib/)"
  exit 0
fi

FOUND=0

check_pattern() {
  local label="$1"
  local pattern="$2"
  local suggestion="$3"
  local matches
  matches=$(grep -rn --include="*.ts" --include="*.tsx" --include="*.js" \
    -E "$pattern" "${SRC_DIRS[@]}" 2>/dev/null || true)
  if [[ -n "$matches" ]]; then
    fail "$label" "$suggestion"
    echo "$matches" | head -5 | while IFS= read -r line; do
      echo -e "     ${RED}$line${NC}"
    done
    FOUND=1
  fi
}

# Kurumsal / kişisel email adresleri
check_pattern \
  "Kaynak kodda email adresi tespit edildi" \
  "[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}" \
  "Email adreslerini kaynak koddan kaldırın. Test için gerekiyorsa .env dosyasına taşıyın."

# Hardcoded şifre atamaları
check_pattern \
  "Hardcoded şifre tespit edildi" \
  "(password|passwd|secret|pwd)\s*[=:]\s*['\"][^'\"]{4,}" \
  "Şifreleri .env dosyasına taşıyın ve react-native-config ile okuyun."

# API key / token
check_pattern \
  "Hardcoded API key / token tespit edildi" \
  "(api_key|apikey|api_secret|access_token|auth_token)\s*[=:]\s*['\"][^'\"]{8,}" \
  "API anahtarlarını .env dosyasına taşıyın, asla kaynak koda yazmayın."

# __DEV__ guard ile sarılmış credential (bundle'a yine de gömülür)
check_pattern \
  "__DEV__ guard ile sarılmış credential — bundle'a yine de gömülür" \
  "__DEV__.*['\"][a-zA-Z0-9._%+\-]+@" \
  "__DEV__ kontrolü runtime'da çalışır, string bundle'a derlenir. Tamamen kaldırın."

# .env dosyası git'te mi?
if git -C "$PROJECT_DIR" ls-files --error-unmatch .env &>/dev/null 2>&1; then
  fail ".env dosyası git'e commit edilmiş" \
       ".env dosyasını .gitignore'a ekleyin: echo '.env' >> .gitignore && git rm --cached .env"
else
  pass ".env dosyası git'te takip edilmiyor"
fi

# .env.example var mı?
if [[ -f "$PROJECT_DIR/.env.example" ]]; then
  pass ".env.example şablon dosyası mevcut"
else
  warn ".env.example eksik — yeni geliştiriciler hangi değerleri dolduracağını bilemez"
fi

# CI credential check script'i var mı?
if find "$PROJECT_DIR/scripts" -name "*.sh" 2>/dev/null | xargs grep -l "credential\|password\|email" 2>/dev/null | grep -q .; then
  pass "CI credential kontrol script'i mevcut"
else
  warn "CI credential kontrol script'i bulunamadı — scripts/check-credentials-leak.sh oluşturun"
fi

[[ $FOUND -eq 0 ]] && pass "Kaynak kodda hardcoded credential bulunamadı"
