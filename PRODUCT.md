# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Petugas gudang CV Rejeki Amerta Jaya. Mereka memakai HP Android sepanjang hari kerja di gudang untuk mencatat pesanan pengambilan barang (sak terigu/gula dan jerigen minyak) dan mencetak tanda ambil barang ke printer thermal. Input sering cepat dan berturut-turut: pilih merek, ketik jumlah di numpad, cetak, ulangi.

## Product Purpose

Mengganti nota tulis tangan di gudang dengan tiket tercetak yang seragam, dan menyimpan semua tiket ke server bersama (PocketBase) supaya beberapa HP di gudang melihat daftar dan rekap yang sama. Berhasil kalau petugas bisa mencetak tiket dalam hitungan detik tanpa salah ketik, dan tidak ada tiket yang hilang walaupun sinyal putus.

## Operating Context

- Struk "TANDA AMBIL BARANG" dicetak di printer thermal 58/80 mm (teruji RPP02N via Bluetooth). Satu atau dua rangkap: kuli muat dan pelanggan. Tiket ditusuk di paku gudang setelah barang keluar.
- Bekerja luring: tiket tersimpan dulu di HP, diunggah saat ada jaringan.
- Beberapa HP berbagi daftar merek dan tiket per tanggal lewat server.
- Ada versi desktop (Windows/Linux, cetak USB), tapi yang dipakai di gudang adalah Android.

## Capabilities and Constraints

- Dua mode pesanan: Sak (pilih merek, jumlah 1–99) dan Minyak (jumlah jerigen saja).
- Tab Daftar: tiket per tanggal, filter, rekap per merek; ubah dan cetak ulang tiket.
- Hapus tiket hanya untuk petugas tertentu (pagar terhadap salah tekan, bukan keamanan).
- Pratinjau struk di layar meniru hasil cetak dan selalu berwarna kertas putih, apa pun mode tampilannya.
- Teks struk dibatasi ASCII karena code page printer.

## Brand Commitments

- Nama aplikasi "Tiket Alamat", watermark "by CV Rejeki Amerta Jaya".
- Tampilan mengikuti tema AmePOS (aplikasi kasir milik perusahaan yang sama), varian online/HP: palet hijau #00A86B, tombol dan kartu membulat, mode Sistem/Terang/Gelap. Dipilih pengguna pada 2026-11-28.

## Product Principles

1. Kecepatan input di atas segalanya: setiap ketukan yang bisa dihemat petugas, dihemat.
2. Data tidak boleh hilang: tiket tersimpan walau printer atau jaringan gagal.
3. Yang di layar sama dengan yang tercetak.
4. Satu keluarga dengan AmePOS: petugas yang memakai keduanya tidak perlu belajar dua bahasa visual.
