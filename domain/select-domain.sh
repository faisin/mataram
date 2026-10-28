#!/usr/bin/env bash
# MATARAM domain selection and DNS validation.
# Option 1 creates a random subdomain in a Cloudflare zone controlled by the user.
# Option 2 accepts a domain the user already owns. This is Mataram's own flow/UI.
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'ERROR: jalankan sebagai root.' >&2; exit 1; }
SOURCE_DIR="${MATARAM_SOURCE_DIR:-/opt/mataram/source}"
CF_SCRIPT="$SOURCE_DIR/install/cf.sh"

printf '\n'
printf '%s\n' '┌──────────────────────────────────────────────┐'
printf '%s\n' '│              MATARAM / DOMAIN                │'
printf '%s\n' '└──────────────────────────────────────────────┘'
printf '%s\n' 'Pilih sumber domain untuk server Mataram:'
printf '%s\n' '  1) Buat subdomain melalui zona Cloudflare milik Anda'
printf '%s\n' '  2) Masukkan domain yang sudah Anda miliki'
printf '%s\n' '  0) Batal'
read -r -p 'Pilihan [0-2]: ' choice

case "$choice" in
  1)
    [[ -f "$CF_SCRIPT" ]] || { echo "ERROR: modul Cloudflare tidak ditemukan: $CF_SCRIPT" >&2; exit 1; }
    bash "$CF_SCRIPT"
    ;;
  2)
    read -r -p 'Domain yang akan dipakai (contoh: vpn.domainanda.com): ' DOMAIN
    DOMAIN="${DOMAIN,,}"
    DOMAIN="${DOMAIN%.}"
    if [[ ! "$DOMAIN" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$ ]]; then
      echo 'ERROR: format domain tidak valid. Masukkan nama domain saja, tanpa https://, port, atau path.' >&2
      exit 1
    fi
    printf '%s\n' "$DOMAIN" > /root/domain
    ;;
  0) echo 'Pemilihan domain dibatalkan.'; exit 0 ;;
  *) echo 'ERROR: pilihan tidak dikenal.' >&2; exit 1 ;;
esac

DOMAIN="$(tr -d '\r\n' </root/domain 2>/dev/null || true)"
[[ -n "$DOMAIN" ]] || { echo 'ERROR: modul domain tidak menghasilkan nama domain.' >&2; exit 1; }
DOMAIN="${DOMAIN,,}"
if [[ ! "$DOMAIN" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$ ]]; then
  echo "ERROR: domain hasil pemilihan tidak valid: $DOMAIN" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
if ! command -v dig >/dev/null 2>&1 || ! command -v ip >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y dnsutils iproute2
fi
PUBLIC_IPV4="$(curl -4fsS --connect-timeout 8 --max-time 15 https://api.ipify.org)" || {
  echo 'ERROR: tidak dapat mendeteksi IPv4 publik VPS.' >&2; exit 1;
}

printf '\nMemeriksa domain %s\n' "$DOMAIN"
printf 'IPv4 publik VPS: %s\n' "$PUBLIC_IPV4"
DNS_OK=0
for attempt in $(seq 1 24); do
  if dig +short A "$DOMAIN" | grep -Fxq "$PUBLIC_IPV4"; then
    DNS_OK=1
    break
  fi
  printf 'DNS A belum cocok (%s/24); menunggu 5 detik...\n' "$attempt"
  sleep 5
done
if [[ $DNS_OK -ne 1 ]]; then
  echo "ERROR: record A $DOMAIN belum mengarah ke $PUBLIC_IPV4 setelah 120 detik." >&2
  echo 'Periksa DNS. Jika memakai Cloudflare, matikan proxy sementara (DNS only) saat penerbitan sertifikat HTTP-01.' >&2
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
  if [[ $IPV6_MATCH -ne 1 ]]; then
    echo "ERROR: record AAAA $DOMAIN tidak cocok dengan IPv6 global VPS." >&2
    echo 'Perbaiki/hapus record AAAA, atau pastikan IPv6 VPS dan routing-nya aktif.' >&2
    exit 1
  fi
fi

install -d -m 0755 /etc/mataram /usr/local/etc/xray
printf '%s\n' "$DOMAIN" > /root/domain
printf '%s\n' "$DOMAIN" > /etc/mataram/domain
printf '%s\n' "$DOMAIN" > /usr/local/etc/xray/domain
printf '\nDomain Mataram tersimpan: %s\n' "$DOMAIN"
printf 'DNS A cocok dengan IPv4 VPS. Pemeriksaan DNS selesai.\n'
printf 'Penerbitan sertifikat TLS akan dilakukan oleh modul domain Mataram.\n\n'
