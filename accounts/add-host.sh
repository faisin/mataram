#!/usr/bin/env bash
# Change Mataram's domain and issue/install its matching TLS certificate.
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'ERROR: jalankan sebagai root.' >&2; exit 1; }
read -r -p 'Domain baru untuk Mataram (contoh: vpn.domainanda.com): ' NEW_DOMAIN
NEW_DOMAIN="${NEW_DOMAIN,,}"
NEW_DOMAIN="${NEW_DOMAIN%.}"
if [[ ! "$NEW_DOMAIN" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$ ]]; then
  echo 'ERROR: format domain tidak valid. Masukkan nama domain saja, tanpa https://, port, atau path.' >&2
  exit 1
fi

SOURCE_DIR="${MATARAM_SOURCE_DIR:-/opt/mataram/source}"
HELPER="$SOURCE_DIR/domain/issue-certificate.sh"
[[ -f "$HELPER" ]] || { echo "ERROR: modul sertifikat Mataram tidak ditemukan: $HELPER" >&2; exit 1; }
OLD_DOMAIN="$(cat /etc/mataram/domain 2>/dev/null || true)"
[[ -n "$OLD_DOMAIN" ]] || OLD_DOMAIN="$(cat /root/domain 2>/dev/null || true)"
printf '\nDomain Mataram saat ini : %s\n' "${OLD_DOMAIN:-belum diatur}"
printf 'Domain yang akan dipakai : %s\n\n' "$NEW_DOMAIN"
echo 'Mataram akan memeriksa DNS, menerbitkan sertifikat, lalu menerapkan domain baru.'
# The shared helper validates DNS and updates the domain files only after TLS succeeds.
bash "$HELPER" "$NEW_DOMAIN"

# The certificate helper restores the original nginx/apache state itself.
# Restart only Xray services that are currently active; do not start disabled units.
XRAY_UNITS=(xray.service xray@none.service xray@vless.service xray@vnone.service xray@trojanws.service xray@trnone.service xray@xtrojan.service xray@trojan.service)
for unit in "${XRAY_UNITS[@]}"; do
  if systemctl is-active --quiet "$unit" 2>/dev/null; then
    echo "Memuat sertifikat baru pada $unit..."
    systemctl restart "$unit" || { echo "ERROR: sertifikat terpasang, tetapi $unit gagal di-restart." >&2; exit 1; }
  fi
done

IP="$(curl -4fsS --connect-timeout 8 --max-time 15 https://api.ipify.org || true)"
if [[ -n "$IP" ]]; then
  install -d -m 0755 /var/lib/crot-script /var/lib/premium-script
  printf 'IP=%s\n' "$IP" > /var/lib/crot-script/ipvps.conf
  printf 'IP=%s\n' "$IP" > /var/lib/premium-script/ipvps.conf
fi
echo "Domain Mataram berhasil diperbarui menjadi $NEW_DOMAIN."
