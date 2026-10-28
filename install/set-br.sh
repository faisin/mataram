#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V1.0
# Auther  : NevermoreSSH
# (C) Copyright 2022
# =========================================
export Server_URL="raw.githubusercontent.com/faisin/mataram/main"

clear
dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
biji=`date +"%Y-%m-%d" -d "$dateFromServer"`
#########################
MYIP=$(wget -qO- ipv4.icanhazip.com);
MYIP=$(curl -s ipinfo.io/ip )
MYIP=$(curl -sS ipv4.icanhazip.com)
MYIP=$(curl -sS ifconfig.me )
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
  exit 1
}
apt_update_with_retry
DEBIAN_FRONTEND=noninteractive apt-get install -y rclone || { echo "ERROR: gagal memasang rclone." >&2; exit 1; }
printf "q\n" | rclone config
wget -O /root/.config/rclone/rclone.conf "https://${Server_URL}/assets/rclone.conf"
git clone  https://github.com/MrMan21/wondershaper.git
cd wondershaper
make install
cd
rm -rf wondershaper
cd /usr/bin
wget -O backup "https://${Server_URL}/system/backup.sh"
wget -O restore "https://${Server_URL}/system/restore.sh"
wget -O cleaner "https://${Server_URL}/system/logcleaner.sh"
chmod +x /usr/bin/backup
chmod +x /usr/bin/restore
chmod +x /usr/bin/cleaner
cd
if [ ! -f "/etc/cron.d/cleaner" ]; then
cat> /etc/cron.d/cleaner << END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/2 * * * * root /usr/bin/cleaner
END
fi
service cron restart > /dev/null 2>&1
rm -f /root/set-br.sh
