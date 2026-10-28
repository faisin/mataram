#!/usr/bin/env bash
# MATARAM certificate renewal command.
# Reuses the same domain/ACME module as installation; never deletes ACME state.
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'ERROR: jalankan sebagai root.' >&2; exit 1; }
DOMAIN="$(cat /etc/mataram/domain 2>/dev/null || true)"
[[ -n "$DOMAIN" ]] || DOMAIN="$(cat /usr/local/etc/xray/domain 2>/dev/null || true)"
[[ -n "$DOMAIN" ]] || DOMAIN="$(cat /root/domain 2>/dev/null || true)"
[[ -n "$DOMAIN" ]] || { echo 'ERROR: domain Mataram belum tersimpan.' >&2; exit 1; }

SOURCE_DIR="${MATARAM_SOURCE_DIR:-/opt/mataram/source}"
HELPER="$SOURCE_DIR/domain/issue-certificate.sh"
if [[ ! -f "$HELPER" ]]; then
  echo "ERROR: modul sertifikat Mataram tidak ditemukan: $HELPER" >&2
  echo 'Jalankan pembaruan sumber Mataram terlebih dahulu.' >&2
  exit 1
fi

printf 'Memeriksa/memperbarui sertifikat TLS untuk %s...\n' "$DOMAIN"
bash "$HELPER" "$DOMAIN"

# Restart only Xray units that were active. Do not stop or start unrelated units.
XRAY_UNITS=(xray.service xray@none.service xray@vless.service xray@vnone.service xray@trojanws.service xray@trnone.service xray@xtrojan.service xray@trojan.service)
for unit in "${XRAY_UNITS[@]}"; do
  if systemctl is-active --quiet "$unit" 2>/dev/null; then
    echo "Memuat ulang sertifikat pada $unit..."
    systemctl restart "$unit" || { echo "ERROR: gagal me-restart $unit." >&2; exit 1; }
  fi
done
printf 'Pemeriksaan sertifikat Mataram selesai untuk %s.\n' "$DOMAIN"
