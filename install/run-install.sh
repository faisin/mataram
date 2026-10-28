#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V1.0
# Auther  : NevermoreSSH
# (C) Copyright 2022
# =========================================

# Supported operating systems: Debian 11-13 and Ubuntu 20.04-26.04.
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "ERROR: jalankan installer sebagai root." >&2; exit 1
fi
if [[ ! -r /etc/os-release ]]; then
  echo "ERROR: /etc/os-release tidak ditemukan; OS tidak dapat dikenali." >&2; exit 1
fi
. /etc/os-release
case "${ID:-}" in
  debian) case "${VERSION_ID%%.*}" in 11|12|13) ;; *) echo "ERROR: Debian yang didukung hanya 11, 12, 13." >&2; exit 1;; esac ;;
  ubuntu) case "${VERSION_ID%%.*}" in 20|22|24|26) ;; *) echo "ERROR: Ubuntu yang didukung hanya 20.04, 22.04, 24.04, 26.04." >&2; exit 1;; esac ;;
  *) echo "ERROR: OS tidak didukung: ${PRETTY_NAME:-unknown}." >&2; exit 1 ;;
esac
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
if [[ "$ARCH" != "amd64" && "$ARCH" != "x86_64" ]]; then
  echo "ERROR: paket Xray bawaan proyek hanya tersedia untuk amd64/x86_64 (terdeteksi: $ARCH)." >&2; exit 1
fi
export DEBIAN_FRONTEND=noninteractive
clear
DEFBOLD='\e[39;1m'
RB='\e[31;1m'
GB='\e[32;1m'
YB='\e[33;1m'
BB='\e[34;1m'
MB='\e[35;1m'
CB='\e[35;1m'
WB='\e[37;1m'
red='\e[1;31m'
green='\e[0;32m'
purple='\e[0;35m'
orange='\e[0;33m'
NC='\e[0m'
export Server_URL="raw.githubusercontent.com/faisin/mataram/main"

# Prefer the complete source tree fetched by the public setup.sh bootstrap.
# Fall back to raw GitHub only when this module is run independently.
fetch_project_file() {
  local name="$1" destination="$2" source_dir="${MATARAM_SOURCE_DIR:-}"
  if [[ -n "$source_dir" && -f "$source_dir/install/$name" ]]; then
    install -m 0755 "$source_dir/install/$name" "$destination"
  elif [[ -n "$source_dir" && -f "$source_dir/$name" ]]; then
    install -m 0755 "$source_dir/$name" "$destination"
  else
    wget -q --timeout=20 -O "$destination" "https://${Server_URL}/install/$name" || return 1
    chmod 0755 "$destination"
  fi
}
echo "Checking VPS"
clear
red='\e[1;31m'
green='\e[0;32m'
yell='\e[1;33m'
tyblue='\e[1;36m'
purple='\e[0;35m'
NC='\e[0m'
purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }


red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
fi
if [ "$(systemd-detect-virt)" == "openvz" ]; then
		echo "OpenVZ is not supported"
		exit 1
fi
secs_to_human() {
    echo "Installation time : $(( ${1} / 3600 )) hours $(( (${1} / 60) % 60 )) minutes $(( ${1} % 60 )) seconds"
}
start=$(date +%s)

echo -e "[ ${green}INFO${NC} ] Preparing the autoscript installation ~"
apt_update_with_retry() {
  local attempt
  for attempt in 1 2 3; do
    echo "Memperbarui indeks APT (percobaan $attempt/3)..."
    if apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20 update; then
      return 0
    fi
    [[ "$attempt" -eq 3 ]] || sleep $((attempt * 3))
  done
  echo "ERROR: apt-get update gagal setelah 3 percobaan. Periksa DNS, koneksi, dan repository." >&2
  return 1
}
apt_update_with_retry || exit 1
apt-get install -y git curl wget ca-certificates unzip || { echo "ERROR: gagal memasang prasyarat installer." >&2; exit 1; }
echo -e "[ ${green}INFO${NC} ] Installation file is ready to begin !"
sleep 1

if [[ "${MATARAM_FORCE_INSTALL:-0}" != "1" ]] && { [[ -f /etc/mataram/install-complete ]] || { [[ -s /usr/local/etc/xray/config.json ]] && systemctl cat xray.service >/dev/null 2>&1; }; }; then
  echo "Mataram terdeteksi sudah terpasang. Installer dihentikan agar konfigurasi aktif tidak tertimpa."
  echo "Untuk melanjutkan instalasi yang sebelumnya gagal, jalankan dengan MATARAM_FORCE_INSTALL=1 setelah memastikan konfigurasi lama boleh ditimpa."
  exit 0
fi
if [[ "${MATARAM_FORCE_INSTALL:-0}" == "1" ]]; then
  echo "PERINGATAN: MATARAM_FORCE_INSTALL aktif; proses instalasi akan diteruskan dan konfigurasi yang ada mungkin berubah."
fi

mkdir -p /var/lib/premium-script /var/lib/crot-script;
clear
#echo -e "${red}♦️${NC} ${green}Established By NevermoreSSH 2022${NC} ${red}♦️${NC}"
#DOWNLOAD SOURCE SCRIPT
# Domain selection and DNS checks are maintained in one Mataram module.
DOMAIN_MODULE="${MATARAM_SOURCE_DIR:-/opt/mataram/source}/domain/select-domain.sh"
if [[ ! -f "$DOMAIN_MODULE" ]]; then
  echo "ERROR: modul pemilihan domain Mataram tidak ditemukan: $DOMAIN_MODULE" >&2
  exit 1
fi
bash "$DOMAIN_MODULE" || { echo "Pemilihan atau validasi domain gagal; instalasi dihentikan." >&2; exit 1; }
DOMAIN="$(cat /etc/mataram/domain 2>/dev/null || true)"
[[ -n "$DOMAIN" ]] || DOMAIN="$(cat /root/domain 2>/dev/null || true)"
[[ -n "$DOMAIN" ]] || { echo "ERROR: domain tidak tersimpan." >&2; exit 1; }
MYIP="$(curl -4fsS --connect-timeout 8 --max-time 15 https://api.ipify.org)" || { echo "Gagal mendeteksi IPv4 publik VPS." >&2; exit 1; }
host="$MYIP"
printf 'IP=%s\n' "$host" > /var/lib/premium-script/ipvps.conf
printf 'IP=%s\n' "$host" > /var/lib/crot-script/ipvps.conf
#clear
#echo -e "\e[0;32mREADY FOR INSTALLATION SCRIPT...\e[0m"
#echo -e ""
#sleep 1
#Install SSH-VPN
echo -e "\e[0;32mINSTALLING SSH-VPN...\e[0m"
sleep 1
fetch_project_file ssh-vpn.sh /root/ssh-vpn.sh || { echo "Gagal menyiapkan ssh-vpn.sh" >&2; exit 1; }; bash /root/ssh-vpn.sh || { echo "Instalasi SSH-VPN gagal; proses dihentikan." >&2; exit 1; }
sleep 3
clear
echo -e "\e[0;32mINSTALLING XRAY CORE...\e[0m"
sleep 3
fetch_project_file xray.sh /root/xray.sh || { echo "Gagal menyiapkan xray.sh" >&2; exit 1; }
bash /root/xray.sh || { echo "Instalasi Xray gagal; proses dihentikan." >&2; exit 1; }
rm -f /root/xray.sh
echo -e "${GREEN}Done!${NC}"
sleep 2
clear
#Install SET-BR
echo -e "\e[0;32mINSTALLING SET-BR...\e[0m"
sleep 1
fetch_project_file set-br.sh /root/set-br.sh || { echo "Gagal menyiapkan set-br.sh" >&2; exit 1; }
bash /root/set-br.sh || { echo "Konfigurasi set-br gagal; proses dihentikan." >&2; exit 1; }
echo -e "${GREEN}Done!${NC}"
sleep 2
clear


# Finish
rm -f /root/ins-xray.sh
rm -f /root/set-br.sh
rm -f /root/ssh-vpn.sh

# Version
echo "1.0" > /home/ver
clear
echo ""
echo -e "${RB}      .-------------------------------------------.${NC}"
echo -e "${RB}      |${NC}      ${CB}Installation Has Been Completed${NC}      ${RB}|${NC}"
echo -e "${RB}      '-------------------------------------------'${NC}"
echo -e "${BB}————————————————————————————————————————————————————————${NC}"
echo -e "      ${WB}Multiport Websocket Autoscript By NevermoreSSH${NC}"
echo -e "${BB}————————————————————————————————————————————————————————${NC}"
echo -e "  ${WB}»»» Protocol Service «««  |  »»» Network Protocol «««${NC}  "
echo -e "${BB}————————————————————————————————————————————————————————${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Vmess Websocket${NC}         ${WB}|${NC}  ${YB}- Websocket (CDN) TLS${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Vless Websocket${NC}         ${WB}|${NC}  ${YB}- Websocket (CDN) NTLS${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Trojan Websocket${NC}        ${WB}|${NC}  ${YB}- TCP XTLS${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Trojan TCP XTLS${NC}         ${WB}|${NC}  ${YB}- TCP TLS${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Trojan TCP${NC}              ${WB}|${NC}"
echo -e "${BB}————————————————————————————————————————————————————————${NC}"
echo -e "           ${WB}»»» YAML Service Information «««${NC}          "
echo -e "${BB}————————————————————————————————————————————————————————${NC}"
echo -e "  ${RB}♦️${NC} ${YB}YAML XRAY VMESS WS${NC}"
echo -e "  ${RB}♦️${NC} ${YB}YAML XRAY VLESS WS${NC}"
echo -e "  ${RB}♦️${NC} ${YB}YAML XRAY TROJAN WS${NC}"
echo -e "  ${RB}♦️${NC} ${YB}YAML XRAY TROJAN XTLS${NC}"
echo -e "  ${RB}♦️${NC} ${YB}YAML XRAY TROJAN TCP${NC}"
echo -e "${BB}————————————————————————————————————————————————————————${NC}"
echo -e "             ${WB}»»» Server Information «««${NC}                 "
echo -e "${BB}————————————————————————————————————————————————————————${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Timezone                : Asia/Kuala_Lumpur (GMT +8)${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Fail2Ban                : [ON]${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Dflate                  : [ON]${NC}"
echo -e "  ${RB}♦️${NC} ${YB}IPtables                : [ON]${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Auto-Reboot             : [ON]${NC}"
echo -e "  ${RB}♦️${NC} ${YB}IPV6                    : [DIPERTAHANKAN SESUAI VPS]${NC}"
echo -e ""
echo -e "  ${RB}♦️${NC} ${YB}Autoreboot On 06.00 GMT +8${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Backup & Restore VPS Data${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Automatic Delete Expired Account${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Bandwith Monitor${NC}"
echo -e "  ${RB}♦️${NC} ${YB}RAM & CPU Monitor${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Check Login User${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Check Created Config${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Automatic Clear Log${NC}"
echo -e "  ${RB}♦️${NC} ${YB}Media Checker${NC}"
echo -e "  ${RB}♦️${NC} ${YB}DNS Changer${NC}"
echo -e "${BB}————————————————————————————————————————————————————————${NC}"
echo -e "              ${WB}»»» Network Port Service «««${NC}             "
echo -e "${BB}————————————————————————————————————————————————————————${NC}"
echo -e "  ${RB}♦️${NC} ${YB}HTTP                    : 80, 8080, 8880${NC}"
echo -e "  ${RB}♦️${NC} ${YB}HTTPS                   : 443${NC}"
echo -e "${BB}————————————————————————————————————————————————————————${NC}"
echo ""
secs_to_human "$(($(date +%s) - ${start}))"
echo ""

echo ""
echo ""
mkdir -p /etc/mataram
printf 'installed_at=%s\ndomain=%s\n' "$(date -Is)" "$(cat /etc/mataram/domain 2>/dev/null || cat /root/domain)" > /etc/mataram/install-complete
echo "Instalasi selesai. Periksa status layanan, lalu reboot manual jika diperlukan."
