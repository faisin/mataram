#!/usr/bin/env bash
# Mataram updater: update the installed scripts from the faisin/mataram main branch.
set -Eeuo pipefail

REPO_RAW="https://raw.githubusercontent.com/faisin/mataram/main"
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Jalankan sebagai root: sudo bash update-v2.sh" >&2
  exit 1
fi
command -v curl >/dev/null 2>&1 || { apt-get update && apt-get install -y curl; }
command -v install >/dev/null 2>&1 || { echo "Perintah install tidak ditemukan." >&2; exit 1; }

# Only update files that are part of the repository and used by the installed panel.
declare -A targets=(
  [menu]="menu.sh"
  [nf]="media.sh"
  [ins-helium]="ins-helium.sh"
  [limit]="limit-speed.sh"
  [bbr]="bbr.sh"
  [add-tr]="add-tr.sh"
  [add-vless]="add-vless.sh"
  [add-ws]="add-ws.sh"
  [user-tr]="user-tr.sh"
  [user-vless]="user-vless.sh"
  [user-ws]="user-ws.sh"
  [wssgen]="wssgen.sh"
  [status]="status.sh"
  [info]="info.sh"
  [restart]="restart.sh"
  [ram]="ram.py"
  [dns]="dns.sh"
  [xp]="xp.sh"
)

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
for target in "${!targets[@]}"; do
  source_file=${targets[$target]}
  tmp="$tmpdir/$target"
  if ! curl --fail --location --silent --show-error "$REPO_RAW/$source_file" -o "$tmp"; then
    echo "Gagal mengunduh $source_file; file terpasang tidak diubah." >&2
    exit 1
  fi
  [[ -s "$tmp" ]] || { echo "File kosong: $source_file" >&2; exit 1; }
  if [[ "$source_file" == *.sh ]] && [[ "$source_file" != "ram.py" ]]; then
    bash -n "$tmp" || { echo "Sintaks tidak valid: $source_file" >&2; exit 1; }
  fi
  install -m 0755 "$tmp" "/usr/bin/$target"
done

# Keep the Xray core itself untouched; it is not an autoscript source file.
echo "Pembaruan skrip Mataram selesai. Xray core tidak diubah."
echo "Periksa layanan sebelum memutuskan untuk restart."
