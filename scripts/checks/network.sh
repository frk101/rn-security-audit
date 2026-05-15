#!/usr/bin/env bash
# Ağ güvenliği yapılandırma kontrolleri

PROJECT_DIR="${1:-$PROJECT_DIR}"
MANIFEST="$PROJECT_DIR/android/app/src/main/AndroidManifest.xml"
NET_CONFIG="$PROJECT_DIR/android/app/src/main/res/xml/network_security_config.xml"
DEBUG_MANIFEST="$PROJECT_DIR/android/app/src/debug/AndroidManifest.xml"

pass() { echo -e "${GREEN}  [GEÇTI]${NC} $1"; echo "PASS:$1" >> /tmp/rn_audit_results; }
warn() { echo -e "${YELLOW}  [UYARI]${NC} $1"; echo "WARN:$1" >> /tmp/rn_audit_results; }
fail() { echo -e "${RED}  [KRITIK]${NC} $1"; echo -e "  ${YELLOW}  → Öneri:${NC} $2"; echo "FAIL:$1" >> /tmp/rn_audit_results; }

# 1. network_security_config.xml varlığı
if [[ -f "$NET_CONFIG" ]]; then
  pass "network_security_config.xml mevcut"

  # Kullanıcı CA'larına güven
  if grep -q 'src="user"' "$NET_CONFIG"; then
    fail "network_security_config.xml kullanıcı CA'larına güveniyor" \
         "<certificates src=\"user\" /> satırını kaldırın. Sadece system CA'ya güvenin."
  else
    pass "Kullanıcı CA'larına güven yok"
  fi

  # Certificate pinning
  if grep -q '<pin-set' "$NET_CONFIG"; then
    # Placeholder pin var mı?
    if grep -q 'REPLACE_WITH' "$NET_CONFIG"; then
      fail "Certificate pinning tanımlanmış ama placeholder hash değiştirilmemiş" \
           "Gerçek SPKI hash'ini alın: openssl s_client -connect DOMAIN:443 2>/dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64"
    else
      pass "Certificate pinning aktif ve hash'ler doldurulmuş"
    fi

    # Expiration tarihi kontrolü
    EXPIRATION=$(grep -oE 'expiration="[0-9]{4}-[0-9]{2}-[0-9]{2}"' "$NET_CONFIG" | head -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
    if [[ -n "$EXPIRATION" ]]; then
      TODAY=$(date +%Y-%m-%d)
      if [[ "$EXPIRATION" < "$TODAY" ]]; then
        fail "Certificate pin süresi dolmuş: $EXPIRATION" \
             "network_security_config.xml içindeki expiration tarihini güncelleyin ve pin hash'ini yenileyin."
      else
        pass "Certificate pin expiration tarihi geçerli ($EXPIRATION)"
      fi
    fi
  else
    warn "Certificate pinning tanımlanmamış — kritik API endpoint'leri için önerilir"
  fi

else
  fail "network_security_config.xml eksik" \
       "android/app/src/main/res/xml/network_security_config.xml oluşturun ve manifest'e ekleyin."
fi

# 2. Debug manifest'te cleartext açık mı?
if [[ -f "$DEBUG_MANIFEST" ]]; then
  if grep -q 'usesCleartextTraffic="true"' "$DEBUG_MANIFEST"; then
    warn "Debug manifest'te usesCleartextTraffic=true — sadece debug build'i etkiler ama dikkatli olun"
  else
    pass "Debug manifest'te cleartext traffic açık değil"
  fi
fi

# 3. Kaynak kodda HTTP URL var mı?
HTTP_URLS=$(grep -rn --include="*.ts" --include="*.tsx" --include="*.js" \
  -E "http://[a-zA-Z]" "$PROJECT_DIR/src" 2>/dev/null | grep -v "//\s*http" || true)
if [[ -n "$HTTP_URLS" ]]; then
  fail "Kaynak kodda HTTP (şifresiz) URL tespit edildi" \
       "Tüm URL'leri https:// ile başlatın."
  echo "$HTTP_URLS" | head -5 | while IFS= read -r line; do
    echo -e "     ${RED}$line${NC}"
  done
else
  pass "Kaynak kodda HTTP URL bulunamadı"
fi

# 4. Localhost / 10.0.2.2 hardcode
if grep -rn --include="*.ts" --include="*.tsx" --include="*.js" \
  -E "localhost|10\.0\.2\.2|127\.0\.0\.1" "$PROJECT_DIR/src" 2>/dev/null | grep -q .; then
  warn "Kaynak kodda localhost/emülatör adresi tespit edildi — production build'e geçmemeli"
else
  pass "Localhost/emülatör adresi bulunamadı"
fi
