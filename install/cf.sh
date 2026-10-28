#!/usr/bin/env bash
# Create a random A record and wildcard record using a scoped Cloudflare API token.
set -Eeuo pipefail

command -v curl >/dev/null 2>&1 || { echo "curl belum terpasang." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { apt-get update && apt-get install -y jq curl; }

read -rp "Domain zona Cloudflare (contoh: example.com): " ZONE_NAME
ZONE_NAME=${ZONE_NAME,,}
if [[ ! "$ZONE_NAME" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$ ]]; then
  echo "Nama domain tidak valid." >&2; exit 1
fi
read -rsp "Cloudflare API Token (izin Zone:Read + DNS:Edit): " CF_TOKEN
printf '\n'
[[ -n "$CF_TOKEN" ]] || { echo "API token wajib diisi." >&2; exit 1; }

IP=$(curl -4fsS --max-time 10 https://api.ipify.org) || { echo "Gagal mendeteksi IPv4 publik." >&2; exit 1; }
API="https://api.cloudflare.com/client/v4"
AUTH=(-H "Authorization: Bearer $CF_TOKEN" -H 'Content-Type: application/json')
ZONE_JSON=$(curl -fsS --get "${API}/zones" "${AUTH[@]}" --data-urlencode "name=${ZONE_NAME}" --data-urlencode 'status=active') || { echo "Cloudflare API gagal." >&2; exit 1; }
ZONE_ID=$(jq -er '.result[0].id' <<<"$ZONE_JSON") || { echo "Zona tidak ditemukan atau token tidak punya izin." >&2; exit 1; }

random=$(tr -dc 'a-z0-9' </dev/urandom | head -c 8 || true)
[[ ${#random} -eq 8 ]] || { echo "Gagal membuat nama subdomain acak." >&2; exit 1; }
SUB_DOMAIN="${random}.${ZONE_NAME}"

upsert_a_record() {
  local record_name="$1" record_json record_id payload response
  record_json=$(curl -fsS --get "${API}/zones/${ZONE_ID}/dns_records" "${AUTH[@]}" --data-urlencode "type=A" --data-urlencode "name=${record_name}")
  record_id=$(jq -r '.result[0].id // empty' <<<"$record_json")
  payload=$(jq -nc --arg type A --arg name "$record_name" --arg content "$IP" '{type:$type,name:$name,content:$content,ttl:120,proxied:false}')
  if [[ -n "$record_id" ]]; then
    response=$(curl -fsS -X PUT "${API}/zones/${ZONE_ID}/dns_records/${record_id}" "${AUTH[@]}" --data "$payload")
  else
    response=$(curl -fsS -X POST "${API}/zones/${ZONE_ID}/dns_records" "${AUTH[@]}" --data "$payload")
  fi
  [[ $(jq -r '.success' <<<"$response") == true ]] || { jq -r '.errors[]?.message' <<<"$response" >&2; return 1; }
}

upsert_a_record "$SUB_DOMAIN"
upsert_a_record "*.${random}.${ZONE_NAME}"
mkdir -p /etc/mataram
printf '%s\n' "$SUB_DOMAIN" > /root/domain
printf '%s\n' "$SUB_DOMAIN" > /etc/mataram/domain
printf 'Domain: %s\nIPv4: %s\n' "$SUB_DOMAIN" "$IP"
echo "Record DNS dibuat. Installer akan menunggu propagasi DNS sebelum meminta sertifikat."
echo "Selesai. Token tidak disimpan ke disk."
