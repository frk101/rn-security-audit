#!/usr/bin/env bash
# Android izin (permission) analizi

PROJECT_DIR="${1:-$PROJECT_DIR}"
MANIFEST="$PROJECT_DIR/android/app/src/main/AndroidManifest.xml"

pass() { echo -e "${GREEN}  [GEÇTI]${NC} $1"; echo "PASS:$1" >> /tmp/rn_audit_results; }
warn() { echo -e "${YELLOW}  [UYARI]${NC} $1"; echo "WARN:$1" >> /tmp/rn_audit_results; }
fail() { echo -e "${RED}  [KRITIK]${NC} $1"; echo -e "  ${YELLOW}  → Öneri:${NC} $2"; echo "FAIL:$1" >> /tmp/rn_audit_results; }

if [[ ! -f "$MANIFEST" ]]; then
  warn "AndroidManifest.xml bulunamadı"
  exit 0
fi

# Tehlikeli izinler — varlığı tek başına hata değil ama işaretlenir
DANGEROUS_PERMISSIONS=(
  "READ_EXTERNAL_STORAGE:Geniş depolama okuma — Android 13+ için MediaStore API kullanın"
  "WRITE_EXTERNAL_STORAGE:Geniş depolama yazma — Scoped storage yeterli"
  "ACCESS_FINE_LOCATION:Hassas GPS konumu — gerçekten GPS gerekiyor mu, COARSE yeterli mi kontrol edin"
  "ACCESS_BACKGROUND_LOCATION:Arka planda konum — KVKK riski, kesinlikle gerekli değilse kaldırın"
  "READ_CONTACTS:Rehber okuma — bu iznin kullanım amacını belgeleyin"
  "READ_CALL_LOG:Arama geçmişi — çok geniş, gerekli mi?"
  "CAMERA:Kamera — kullanım amacını in-app rationale ile kullanıcıya açıklayın"
  "RECORD_AUDIO:Mikrofon — kullanım amacını in-app rationale ile kullanıcıya açıklayın"
  "SEND_SMS:SMS gönderme — kesinlikle gerekli mi?"
  "READ_SMS:SMS okuma — çok geniş, güçlü gerekçe şart"
  "PROCESS_OUTGOING_CALLS:Giden aramaları engelleme/yönlendirme — neden gerekli?"
)

echo -e "  Manifest'teki tüm izinler:"
grep 'uses-permission' "$MANIFEST" | grep -v 'tools:node="remove"' | \
  grep -oE 'android\.permission\.[A-Z_]+' | while IFS= read -r perm; do
  echo -e "  ${BLUE}  • $perm${NC}"
done
echo ""

for entry in "${DANGEROUS_PERMISSIONS[@]}"; do
  perm="${entry%%:*}"
  msg="${entry#*:}"
  if grep -q "android.permission.$perm" "$MANIFEST" && ! grep -A1 "android.permission.$perm" "$MANIFEST" | grep -q 'tools:node="remove"'; then
    fail "$perm izni mevcut — $msg" \
         "Bu iznin gerçekten gerekli olup olmadığını değerlendirin. Gerekmiyorsa manifest'ten kaldırın."
  fi
done

# ACCESS_FINE_LOCATION olmadan ACCESS_COARSE_LOCATION kontrolü — iyi durum
if grep -q "ACCESS_COARSE_LOCATION" "$MANIFEST" && \
   ! grep "ACCESS_FINE_LOCATION" "$MANIFEST" | grep -v 'tools:node="remove"' | grep -q .; then
  pass "Konum için yalnızca COARSE_LOCATION kullanılıyor (en az ayrıcalık prensibi)"
fi

# Runtime rationale kontrolü — PermissionsAndroid kullanılıyor mu?
SRC_DIR="$PROJECT_DIR/src"
if [[ -d "$SRC_DIR" ]]; then
  if grep -rn --include="*.tsx" --include="*.ts" "PermissionsAndroid" "$SRC_DIR" 2>/dev/null | grep -q .; then
    pass "PermissionsAndroid.request() kullanımı tespit edildi — runtime rationale mevcut"
  else
    warn "PermissionsAndroid.request() bulunamadı — izin talep öncesi kullanıcıya rationale gösterilmiyor olabilir"
  fi
fi
