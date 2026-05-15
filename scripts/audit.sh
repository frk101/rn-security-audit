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
  echo -e "${RED}Kritik güvenlik sorunları tespit edildi.${NC}"
else
  echo -e "${GREEN}Kritik sorun bulunamadı.${NC}"
fi

# Otomatik düzeltme önerisi — sadece interaktif terminalde sor (CI'da atla)
if [[ "$FAIL" -gt 0 || "$WARN" -gt 0 ]] && [[ -t 0 ]] && [[ "${CI:-}" != "true" ]] && [[ "${RN_AUDIT_NO_FIX:-}" != "1" ]]; then
  echo ""
  echo -e "${BOLD}Bazı sorunları otomatik düzeltebilirim:${NC}"
  echo -e "  • .env dosyasını .gitignore'a ekleme"
  echo -e "  • AndroidManifest: allowBackup=\"false\" + networkSecurityConfig"
  echo -e "  • build.gradle: ProGuard'ı açma"
  echo -e "  • Podfile: Hermes'i açma"
  echo -e "  • .env.example oluşturma"
  echo ""
  echo -e "${YELLOW}Riskli değişiklikler (kod içi credential, izin kaldırma) elle yapılmalı.${NC}"
  echo ""
  read -r -p "Otomatik düzeltmeleri uygulayayım mı? [y/N]: " ANSWER
  if [[ "$ANSWER" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    bash "$SCRIPT_DIR/fix.sh" "$PROJECT_DIR"
  else
    echo -e "${BLUE}Düzeltme atlandı. Yukarıdaki önerileri elle uygulayabilirsin.${NC}"
  fi
fi

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
else
  exit 0
fi
