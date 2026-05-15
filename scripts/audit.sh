#!/usr/bin/env bash
# =============================================================
# rn-security-audit — React Native Güvenlik Denetim Aracı
# Kullanım: bash scripts/audit.sh <proje_dizini>
# Örnek:    bash scripts/audit.sh ~/projeler/MyApp
# =============================================================

set -euo pipefail

PROJECT_DIR="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0

if [[ -z "$PROJECT_DIR" ]]; then
  echo -e "${RED}Hata: Proje dizini belirtilmedi.${NC}"
  echo "Kullanım: bash scripts/audit.sh <proje_dizini>"
  exit 1
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo -e "${RED}Hata: '$PROJECT_DIR' dizini bulunamadı.${NC}"
  exit 1
fi

export PROJECT_DIR
export RED YELLOW GREEN BLUE BOLD NC
export PASS WARN FAIL

echo ""
echo -e "${BOLD}=================================================${NC}"
echo -e "${BOLD}   RN Security Audit${NC}"
echo -e "${BOLD}   Proje: $PROJECT_DIR${NC}"
echo -e "${BOLD}   Tarih: $(date '+%Y-%m-%d %H:%M')${NC}"
echo -e "${BOLD}=================================================${NC}"
echo ""

run_check() {
  local name="$1"
  local script="$2"
  echo -e "${BLUE}━━━ $name ${NC}"
  bash "$SCRIPT_DIR/checks/$script" "$PROJECT_DIR" || true
  echo ""
}

run_check "1. AndroidManifest Güvenlik Kontrolleri" "manifest.sh"
run_check "2. iOS Info.plist & ATS Kontrolleri" "ios.sh"
run_check "3. Hardcoded Credential & Email Sızıntısı" "credentials.sh"
run_check "4. Ağ Güvenliği Yapılandırması" "network.sh"
run_check "5. İzin (Permission) Analizi" "permissions.sh"
run_check "6. Obfuscation & Build Güvenliği" "obfuscation.sh"
run_check "7. Bağımlılık Güvenliği" "dependencies.sh"

# Sonuç özetini her check'in yazdığı geçici dosyadan topla
PASS=$(grep -r "^PASS:" /tmp/rn_audit_results 2>/dev/null | wc -l | tr -d ' ') || PASS=0
WARN=$(grep -r "^WARN:" /tmp/rn_audit_results 2>/dev/null | wc -l | tr -d ' ') || WARN=0
FAIL=$(grep -r "^FAIL:" /tmp/rn_audit_results 2>/dev/null | wc -l | tr -d ' ') || FAIL=0
rm -f /tmp/rn_audit_results

echo -e "${BOLD}=================================================${NC}"
echo -e "${BOLD}   ÖZET${NC}"
echo -e "${BOLD}=================================================${NC}"
echo -e "  ${GREEN}GEÇTI : $PASS${NC}"
echo -e "  ${YELLOW}UYARI : $WARN${NC}"
echo -e "  ${RED}BAŞARISIZ: $FAIL${NC}"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}Kritik güvenlik sorunları tespit edildi. Yukarıdaki önerileri uygulayın.${NC}"
  exit 1
else
  echo -e "${GREEN}Kritik sorun bulunamadı.${NC}"
  exit 0
fi
