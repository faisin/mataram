#!/usr/bin/env bash
# MATARAM single entry point: download full repository, validate, then install.
set -Eeuo pipefail
REPO="${MATARAM_REPO:-faisin/mataram}"; BRANCH="${MATARAM_BRANCH:-main}"
ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.zip"
INSTALL_ROOT=/opt/mataram; SOURCE_DIR="$INSTALL_ROOT/source"
log(){ printf '[MATARAM] %s\n' "$*"; }; die(){ printf '[MATARAM] ERROR: %s\n' "$*" >&2; exit 1; }
[[ ${EUID:-$(id -u)} -eq 0 ]] || die 'Jalankan sebagai root.'
[[ -r /etc/os-release ]] || die '/etc/os-release tidak ditemukan.'
. /etc/os-release
case "${ID:-}" in
 debian) case "${VERSION_ID%%.*}" in 11|12|13) ;; *) die "Mendukung Debian 11/12/13; terdeteksi ${PRETTY_NAME:-unknown}.";; esac ;;
 ubuntu) case "${VERSION_ID%%.*}" in 20|22|24|26) ;; *) die "Mendukung Ubuntu 20.04/22.04/24.04/26.04; terdeteksi ${PRETTY_NAME:-unknown}.";; esac ;;
 *) die "OS tidak didukung: ${PRETTY_NAME:-unknown}.";;
esac
ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$ARCH" in amd64|x86_64) ;; *) die "Saat ini hanya amd64/x86_64; terdeteksi $ARCH.";; esac
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl wget unzip
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
log "Mengunduh seluruh repositori ${REPO}/${BRANCH}..."
curl -fLsS --retry 3 --connect-timeout 15 --max-time 300 "$ARCHIVE_URL" -o "$TMP/repo.zip" || die 'Gagal mengunduh repositori.'
unzip -tq "$TMP/repo.zip" >/dev/null || die 'Arsip GitHub rusak.'
mkdir "$TMP/extract"; unzip -q "$TMP/repo.zip" -d "$TMP/extract"
REPO_DIR="$(find "$TMP/extract" -mindepth 1 -maxdepth 1 -type d -print -quit)"
[[ -n "$REPO_DIR" ]] || die 'Folder repositori kosong.'
for f in install/run-install.sh install/ssh-vpn.sh install/xray.sh domain/select-domain.sh domain/issue-certificate.sh install/cf.sh tools/acme.sh; do [[ -f "$REPO_DIR/$f" ]] || die "File wajib tidak ditemukan: $f"; done
mkdir -p "$INSTALL_ROOT"; NEW="$INSTALL_ROOT/source.new.$$"; OLD="$INSTALL_ROOT/source.old.$$"
rm -rf "$NEW"; cp -a "$REPO_DIR" "$NEW"
[[ ! -e "$SOURCE_DIR" ]] || mv "$SOURCE_DIR" "$OLD"
if mv "$NEW" "$SOURCE_DIR"; then rm -rf "$OLD"; else [[ ! -e "$OLD" ]] || mv "$OLD" "$SOURCE_DIR"; die 'Gagal memasang source tree.'; fi
export MATARAM_SOURCE_DIR="$SOURCE_DIR" MATARAM_REPO_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
log 'Source lengkap tersedia di /opt/mataram/source.'
exec bash "$SOURCE_DIR/install/run-install.sh" "$@"
