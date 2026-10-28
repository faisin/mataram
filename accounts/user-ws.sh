#!/usr/bin/env bash
# Display the existing VMess WebSocket account links.
set -u
CONFIG=/usr/local/etc/xray/config.json
DOMAIN_FILE=/root/domain
[[ -r "$CONFIG" ]] || { echo "ERROR: konfigurasi VMess tidak ditemukan: $CONFIG" >&2; exit 1; }
[[ -r "$DOMAIN_FILE" ]] || { echo "ERROR: domain belum disimpan di $DOMAIN_FILE" >&2; exit 1; }
mapfile -t CLIENTS < <(awk '/^### / {print $2 "|" $3}' "$CONFIG")
((${#CLIENTS[@]})) || { echo 'Belum ada akun VMess WS.'; exit 1; }
echo 'Daftar akun VMess WS:'
for i in "${!CLIENTS[@]}"; do printf '%2d) %s
' "$((i+1))" "${CLIENTS[$i]//|/  Exp: }"; done
read -rp 'Pilih nomor akun: ' choice
[[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#CLIENTS[@]})) || { echo 'Pilihan tidak valid.' >&2; exit 1; }
entry="${CLIENTS[$((choice-1))]}"; user="${entry%%|*}"; expiry="${entry#*|}"
domain="$(cat "$DOMAIN_FILE")"
for kind in tls none; do
  file="/usr/local/etc/xray/${user}-${kind}.json"
  [[ -s "$file" ]] || { echo "ERROR: file konfigurasi akun tidak ditemukan: $file" >&2; exit 1; }
  printf '
VMess %s (%s):
vmess://%s
' "${kind^^}" "$user" "$(base64 -w 0 "$file")"
done
ip="$(curl -4fsS --connect-timeout 5 --max-time 10 https://api.ipify.org 2>/dev/null || printf 'tidak tersedia')"
printf '
Domain: %s
IP VPS: %s
Expired: %s
' "$domain" "$ip" "$expiry"
