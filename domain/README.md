# Domain dan TLS Mataram

Modul domain dikelola terpisah dari installer utama supaya alur domain dapat diperbaiki tanpa mengubah skrip protokol.

## Alur pemilihan

`select-domain.sh` menyediakan dua opsi yang khusus untuk kebutuhan Mataram:

1. **Buat subdomain melalui Cloudflare** — pengguna memasukkan zona yang mereka kendalikan dan API Token terbatas untuk Zone Read serta DNS Edit. Modul `install/cf.sh` membuat subdomain dan record A.
2. **Gunakan domain milik sendiri** — pengguna memasukkan FQDN, misalnya `vpn.domainanda.com`.

Keduanya melewati validasi yang sama. Record A harus mengarah ke IPv4 publik VPS. Jika record AAAA tersedia, alamat tersebut harus cocok dengan alamat IPv6 global VPS. Jika pemeriksaan gagal, instalasi berhenti sebelum mengubah layanan protokol.

Domain disimpan di tiga lokasi untuk menjaga kompatibilitas skrip lama dan baru:

- `/etc/mataram/domain` — konfigurasi utama Mataram.
- `/usr/local/etc/xray/domain` — kompatibilitas konfigurasi Xray.
- `/root/domain` — kompatibilitas dengan skrip lama yang belum dimigrasikan.

## Sertifikat

`issue-certificate.sh` menerbitkan dan memasang sertifikat Let's Encrypt menggunakan HTTP-01 standalone. Port TCP/80 harus dapat dijangkau dari internet. Hook ACME menyimpan status nginx/apache2 sebelum validasi, menghentikan layanan yang memang aktif, lalu memulihkan status sebelumnya. Hook yang sama dipakai untuk pembaruan otomatis.

Perintah `install/cert.sh` menggunakan modul sertifikat bersama; skrip ini tidak menghapus `/root/.acme.sh` dan hanya me-restart unit Xray yang sebelumnya aktif.

## Batasan yang perlu diketahui

- Opsi Cloudflare memerlukan domain zona yang sudah dimiliki/dikelola pengguna dan API Token yang sesuai; Mataram tidak menciptakan domain publik gratis dari nol.
- Untuk HTTP-01, record A harus dapat diverifikasi langsung. Jika Cloudflare proxy aktif, ubah sementara menjadi **DNS only** saat penerbitan sertifikat.
- DNS/port/sertifikat masih harus diuji dari jaringan luar pada VPS uji sebelum rilis produksi.
