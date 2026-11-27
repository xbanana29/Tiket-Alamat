---
version: 1
slug: "lib-ui-shell-dart"
primary_target: "lib/ui/shell.dart"
related_targets: ["lib/ui/pesanan.dart","lib/ui/daftar.dart","lib/ui/pengaturan.dart","lib/ui/setup.dart"]
---

# Tiket Alamat — layar kerja (Pesanan, Daftar, Pengaturan)

Scope: seluruh aplikasi Android (Shell, Pesanan, Daftar, Pengaturan, Setup). Mode: Operate.
Tugas: petugas gudang memilih merek, mengetik jumlah, mencetak tiket berkali-kali sepanjang hari; meninjau tiket per tanggal; mengatur printer dan merek.
Constraints: alur, salinan teks, dan perilaku tetap; pratinjau struk tetap kertas putih; target sentuh ≥48 dp; Archivo tetap sebagai huruf.

## Direction contract

THESIS: Tiket Alamat menjadi anggota keluarga AmePOS varian online/HP, bukan aplikasi brutalist sendiri. Menolak bingkai hitam tebal, siku 0, dan tombol balik-warna; diganti bahasa Material 3 AmePOS.

OWN-WORLD: ColorScheme.fromSeed hijau #00A86B (gelap #2DD4A0), ground #F7FAF8 / #111714, kartu putih atau surfaceContainerHighest 45%, garis outlineVariant tipis. Radius 8/12/16/22. Tombol isi hijau radius 12; segmen terpilih = tint hijau 14% + teks hijau tua; status chip tint 14% radius 8; keypad = tombol secondaryContainer radius 8 jarak 3. Mode Sistem/Terang/Gelap.

STORY: petugas langsung mengenali kontrol AmePOS: pilih kartu merek, keypad, bar hijau Cetak. Status sinkron dan antrean terbaca sebagai chip.

FIRST VIEWPORT: app bar judul + chip SYNC/LURING + chip antrean; segmen Sak/Minyak; kartu nama pelanggan; kertas struk putih; grid kartu merek 3×3 (kartu terpilih = tint hijau + lencana jumlah); bar hijau penuh "Cetak tiket · N sak" di atas NavigationBar M3 tiga tujuan.

FORM: pin pengguna, tanpa roll. seed: none (pinned) — "saya mau ganti theme agar model button color pallete dan darkmode/lightmode mirip theme amepos"; varian dipilih: "Online/HP"; mode: "Sistem/Terang/Gelap". Signature move: bar aksi hijau penuh seperti bar keranjang kasir AmePOS.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
