# Mataram VPN Script

## Instalasi

Jalankan sebagai `root` pada Debian 11/12/13 atau Ubuntu 20.04/22.04/24.04/26.04 (amd64):

```bash
wget -qO /root/setup.sh https://raw.githubusercontent.com/faisin/mataram/main/setup.sh && bash /root/setup.sh
```

`setup.sh` adalah satu-satunya entry point instalasi. Ia mengunduh arsip repositori lengkap ke `/opt/mataram/source`, memvalidasi file wajib, lalu menjalankan `install/run-install.sh`.

## Struktur sumber

- `install/` — installer utama, SSH, Xray, dan helper pemasangan
- `domain/` — pilih domain sendiri atau Cloudflare, pemeriksaan DNS, sertifikat Let's Encrypt
- `accounts/` — tambah, hapus, cek, perpanjang, trial akun protokol
- `menu/` — menu utama dan menu protokol
- `system/` — status, backup/restore, restart, update dan utilitas sistem
- `assets/` — konfigurasi Nginx, Dropbear, halaman web dan konfigurasi pendukung
- `tools/` — alat dan binary pendukung yang digunakan skrip

OpenVPN tidak disertakan. Protokol VMess, VLESS, dan Trojan tetap menjadi sasaran konfigurasi Xray.

> Catatan pengujian: pemeriksaan sintaks shell tidak menggantikan uji instalasi end-to-end pada VM bersih. Uji nyata tetap diperlukan untuk setiap versi OS dan provider VPS.
