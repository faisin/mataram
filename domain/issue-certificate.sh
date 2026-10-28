#!/usr/bin/env bash
# MATARAM certificate lifecycle for the selected domain.
# HTTP-01 is used; the service state is preserved before and after issuance/renewal.
set -Eeuo pipefail

DOMAIN="${1:-}"
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'ERROR: jalankan sebagai root.' >&2; exit 1; }
[[ -n "$DOMAIN" ]] || { echo 'ERROR: domain tidak diberikan.' >&2; exit 1; }
DOMAIN="${DOMAIN,,}"
[[ "$DOMAIN" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$ ]] || {
  echo "ERROR: format domain tidak valid: $DOMAIN" >&2; exit 1;
}
for cmd in curl ss dig ip openssl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: perintah $cmd tidak tersedia." >&2; exit 1; }
done

PUBLIC_IPV4="$(curl -4fsS --connect-timeout 8 --max-time 15 https://api.ipify.org)" || {
  echo 'ERROR: gagal mendeteksi IPv4 publik VPS.' >&2; exit 1;
}
if ! dig +short A "$DOMAIN" | grep -Fxq "$PUBLIC_IPV4"; then
  echo "ERROR: DNS A $DOMAIN tidak mengarah ke IPv4 VPS $PUBLIC_IPV4." >&2
  exit 1
fi
mapfile -t DNS_AAAA < <(dig +short AAAA "$DOMAIN" | grep -E '^[0-9a-fA-F:]+$' || true)
if ((${#DNS_AAAA[@]})); then
  mapfile -t VPS_IPV6 < <(ip -6 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
  IPV6_MATCH=0
  for dns6 in "${DNS_AAAA[@]}"; do
    for local6 in "${VPS_IPV6[@]}"; do
      [[ "${dns6,,}" == "${local6,,}" ]] && IPV6_MATCH=1
    done
  done
  [[ $IPV6_MATCH -eq 1 ]] || {
    echo "ERROR: record AAAA $DOMAIN tidak cocok dengan IPv6 global VPS." >&2
    exit 1
  }
fi

SOURCE_DIR="${MATARAM_SOURCE_DIR:-/opt/mataram/source}"
ACME_HOME=/root/.acme.sh
ACME_BIN="$ACME_HOME/acme.sh"
STATE_FILE=/run/mataram-acme-services.state
PRE_HOOK=/usr/local/sbin/mataram-acme-pre
POST_HOOK=/usr/local/sbin/mataram-acme-post
install -d -m 0755 "$ACME_HOME" /usr/local/etc/xray /etc/mataram /var/lib/mataram

# These hooks are also stored by acme.sh for unattended certificate renewal.
cat > "$PRE_HOOK" <<'PRE'
#!/usr/bin/env bash
set -Eeuo pipefail
state=/run/mataram-acme-services.state
: > "$state"
for service in nginx apache2; do
  if systemctl is-active --quiet "$service" 2>/dev/null; then
    printf '%s=1\n' "$service" >> "$state"
    systemctl stop "$service"
  else
    printf '%s=0\n' "$service" >> "$state"
  fi
done
if ss -H -ltn 'sport = :80' 2>/dev/null | grep -q .; then
  echo 'ERROR: port 80 masih dipakai layanan selain nginx/apache2; validasi HTTP-01 dibatalkan.' >&2
  /usr/local/sbin/mataram-acme-post || true
  exit 1
fi
PRE

cat > "$POST_HOOK" <<'POST'
#!/usr/bin/env bash
set -u
state=/run/mataram-acme-services.state
[[ -r "$state" ]] || exit 0
while IFS='=' read -r service was_active; do
  [[ "$was_active" == 1 ]] || continue
  case "$service" in nginx|apache2) systemctl start "$service" >/dev/null 2>&1 || echo "PERINGATAN: gagal memulihkan layanan $service." >&2 ;; esac
done < "$state"
rm -f "$state"
exit 0
POST
chmod 0755 "$PRE_HOOK" "$POST_HOOK"

restore_services() { "$POST_HOOK" || true; }
trap restore_services EXIT

if [[ -f "$SOURCE_DIR/tools/acme.sh" ]]; then
  install -m 0755 "$SOURCE_DIR/tools/acme.sh" "$ACME_BIN"
elif [[ -x "$ACME_BIN" ]]; then
  :
else
  echo 'ERROR: acme.sh tidak ditemukan di sumber Mataram.' >&2
  exit 1
fi
# --install harus dijalankan dari direktori staging agar sumber tidak sama
# dengan tujuan /root/.acme.sh/acme.sh (menghindari error cp same file).
[[ -s "$ACME_BIN" ]] || { echo 'ERROR: berkas acme.sh kosong atau tidak ditemukan.' >&2; exit 1; }
ACME_STAGE="$(mktemp -d /tmp/mataram-acme-install.XXXXXX)" || {
  echo 'ERROR: gagal membuat direktori sementara untuk acme.sh.' >&2; exit 1;
}
if ! cp "$ACME_BIN" "$ACME_STAGE/acme.sh"; then
  rm -rf "$ACME_STAGE"
  echo 'ERROR: gagal menyiapkan salinan sementara acme.sh.' >&2
  exit 1
fi
chmod 0755 "$ACME_STAGE/acme.sh"
if ! (cd "$ACME_STAGE" && ./acme.sh --install --home "$ACME_HOME" --config-home "$ACME_HOME"); then
  rm -rf "$ACME_STAGE"
  echo 'ERROR: gagal menyiapkan acme.sh.' >&2
  exit 1
fi
rm -rf "$ACME_STAGE"
"$ACME_BIN" --set-default-ca --server letsencrypt || {
  echo "ERROR: gagal mengatur Let's Encrypt sebagai CA default." >&2; exit 1;
}

# ACME hooks stop only services that were active and restore the same state afterward.
if ! "$ACME_BIN" --issue --server letsencrypt -d "$DOMAIN" --standalone --keylength ec-256 \
  --pre-hook "$PRE_HOOK" --post-hook "$POST_HOOK"; then
  echo "ERROR: Let's Encrypt gagal menerbitkan sertifikat untuk $DOMAIN." >&2
  echo 'Pastikan TCP port 80 dapat dijangkau dari internet dan DNS sudah benar.' >&2
  exit 1
fi

cat > /usr/local/sbin/mataram-reload-tls <<'RELOAD'
#!/usr/bin/env bash
set -u
if systemctl is-active --quiet nginx 2>/dev/null; then
  if nginx -t; then
    systemctl reload nginx
  else
    echo 'ERROR: konfigurasi nginx tidak valid; sertifikat diperbarui tetapi nginx tidak di-reload.' >&2
    exit 1
  fi
fi
exit 0
RELOAD
chmod 0755 /usr/local/sbin/mataram-reload-tls

"$ACME_BIN" --install-cert -d "$DOMAIN" --ecc \
  --key-file /usr/local/etc/xray/xray.key \
  --fullchain-file /usr/local/etc/xray/xray.crt \
  --reloadcmd /usr/local/sbin/mataram-reload-tls || {
    echo 'ERROR: gagal memasang sertifikat ke direktori Xray.' >&2; exit 1;
  }
[[ -s /usr/local/etc/xray/xray.crt && -s /usr/local/etc/xray/xray.key ]] || {
  echo 'ERROR: file sertifikat atau private key tidak ditemukan.' >&2; exit 1;
}
openssl x509 -in /usr/local/etc/xray/xray.crt -noout -checkhost "$DOMAIN" >/dev/null || {
  echo "ERROR: sertifikat tidak cocok dengan $DOMAIN." >&2; exit 1;
}
chmod 0644 /usr/local/etc/xray/xray.crt
chmod 0600 /usr/local/etc/xray/xray.key
printf '%s\n' "$DOMAIN" > /etc/mataram/domain
printf '%s\n' "$DOMAIN" > /usr/local/etc/xray/domain
printf '%s\n' "$DOMAIN" > /root/domain

# Restore the original service state now; the EXIT trap becomes a harmless no-op.
restore_services
trap - EXIT
echo "Sertifikat Let's Encrypt berhasil dipasang untuk $DOMAIN."
