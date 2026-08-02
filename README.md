# Tiket Alamat

Aplikasi Flutter (Android) untuk mencatat pesanan gudang dan mencetak
"TANDA AMBIL BARANG" di printer thermal Bluetooth.

**by CV Rejeki Amerta Jaya**

## Menjalankan

```
flutter run -d <device-id>
```

Perangkat harus dalam keadaan tidak terkunci.

## Unduhan & rilis

Build otomatis lewat GitHub Actions (`.github/workflows/release.yml`):

| Platform | Berkas | Siap pakai? |
|---|---|---|
| Android | `TiketAlamat-android.apk` | ya — ini yang dipakai di gudang |
| Windows x64 | `TiketAlamat-windows-x64.zip` | ya |
| Linux x64 | `TiketAlamat-linux-x64.tar.gz` | ya |
| macOS | `TiketAlamat-macos.zip` | ya, tapi belum ditandatangani Apple |
| iOS | `TiketAlamat-ios-unsigned.zip` | **tidak** — lihat di bawah |

> **iOS tidak bisa dipasang dari berkas ini.** Apple mewajibkan aplikasi
> ditandatangani sertifikat berbayar (Apple Developer Program, ~$99/tahun) dan
> disebarkan lewat TestFlight atau App Store. Berkas yang dihasilkan CI dibangun
> `--no-codesign`, jadi gunanya hanya membuktikan kodenya tetap terkompilasi
> untuk iOS. Kalau nanti perlu iPhone di gudang, yang dibutuhkan adalah akun
> developer Apple, bukan perubahan kode.
>
> **macOS** ikut dibangun tanpa tanda tangan. Saat pertama dibuka, macOS akan
> menolaknya — klik kanan berkasnya lalu pilih **Open** untuk melewati
> Gatekeeper, atau tandatangani dengan akun developer Apple.

Membuat rilis:

```
git tag v1.0.0 && git push origin v1.0.0
```

Tag `v*` → analyze + test → build ketiga platform → Release otomatis dibuat.
Untuk sekadar mencoba build tanpa membuat tag, jalankan workflow lewat tombol
**Run workflow**; artefaknya bisa diunduh dari halaman run.

### Yang perlu diketahui soal build

- **Kunci penandatanganan Android wajib disiapkan.** Ini bukan formalitas Play
  Store: tanpa kunci tetap, tiap build CI memakai kunci debug baru dan APK
  versi berikutnya **ditolak memasang** di atas versi sebelumnya
  (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) — tombol pembaruan jadi percuma.

  Sekali saja, di komputer Anda:

  ```bash
  keytool -genkey -v -keystore rilis.jks -keyalg RSA -keysize 2048 \
      -validity 10000 -alias tiketalamat
  base64 -w0 rilis.jks > rilis.jks.b64     # macOS: base64 -i rilis.jks -o rilis.jks.b64
  ```

  Lalu simpan sebagai GitHub Secrets (**Settings → Secrets and variables →
  Actions**):

  | Secret | Isi |
  |---|---|
  | `ANDROID_KEYSTORE_BASE64` | isi `rilis.jks.b64` |
  | `ANDROID_STORE_PASSWORD` | password keystore |
  | `ANDROID_KEY_ALIAS` | `tiketalamat` |
  | `ANDROID_KEY_PASSWORD` | password key |

  **Simpan `rilis.jks` baik-baik.** Kalau hilang, semua HP harus uninstall
  dulu sebelum bisa dipasangi versi berikutnya. Berkas ini tidak boleh masuk
  git (sudah ada di `.gitignore`).
- **Cetak Bluetooth hanya di Android** (teruji dengan RPP02N). Di Windows,
  Linux, dan macOS jalurnya **USB lewat sistem cetak OS** — CUPS `lp -o raw`
  di Linux/macOS, winspool datatype `RAW` di Windows. Jalur USB itu belum
  pernah diuji dengan printer fisik.
- Di macOS, `permission_handler` tidak punya implementasi sama sekali, jadi
  jalur Bluetooth di sana pasti gagal — karena itu macOS diarahkan ke CUPS.
- Tata letaknya dirancang untuk layar ponsel potret; di desktop jendelanya
  hanya melebar, belum ditata ulang.

## Struktur

| File | Isi |
|---|---|
| `lib/state.dart` | `AppState` — seluruh state + logika murni (numpad, upsert item, revisi, rekap) |
| `lib/models.dart` | `Tiket`, `Item`, `Revisi`, `Merek` + seed 20 merek |
| `lib/store.dart` | Persistensi: satu file `data.json` di direktori dokumen app |
| `lib/printer.dart` | ESC/POS ke printer Bluetooth Classic (58/80 mm) |
| `lib/sync.dart` | Unggah tiket ke PocketBase |
| `lib/ui/` | Layar: shell, setup, pesanan, daftar, pengaturan |

Tanpa Riverpod/Bloc/router — satu `ChangeNotifier` di `InheritedNotifier`,
sesuai bentuk state rancangan aslinya.

## Printer

RPP02N (dan sejenisnya) memakai Bluetooth **Classic/SPP**, bukan BLE.

1. Pasangkan printer di **Setelan Android → Bluetooth** (app tidak melakukan
   discovery, hanya membaca daftar perangkat ter-pair).
2. Buka **Pengaturan → Printer → Pindai perangkat**, pilih printer.
3. **Tes cetak** untuk memastikan.

Bila printer gagal saat mencetak tiket, **tiket tetap tersimpan** — kertas bisa
diulang lewat **Daftar → Cetak ulang**.

## PocketBase

Tiket disimpan lokal dengan status `Menunggu unggah`, lalu di-push ke server dan
berubah menjadi `Terkirim`. Antrian dicoba ulang otomatis saat internet kembali.

> **Server live** di `https://pb.rejekiamerta.com` (sejak 2026-08-01).  
> Kredensial admin, detail VPS, dan backup: **[POCKETBASE.md](./POCKETBASE.md)**.

Koleksi `tiket` sudah terimport. Di HP cukup pastikan URL di **Pengaturan →
Server & antrian** = `https://pb.rejekiamerta.com` (sudah jadi default di kode).

### Merek & kategori ikut tersinkron

Daftar merek juga dipakai bersama: menambah, mengubah, atau menghapus merek di
satu HP ikut berlaku di HP lain. Ditarik saat app dibuka dan saat tab
**Pengaturan** dibuka.

Penghapusan memakai **hapus lunak** — barisnya tetap tersimpan dengan penanda
`dihapus`. Tanpa itu, HP lain yang masih menyimpan merek lama akan
mengirimkannya kembali dan penghapusan batal dengan sendirinya. Kalau dua HP
mengubah merek yang sama, perubahan dengan waktu paling baru yang menang.

> Butuh koleksi `merek` di PocketBase — import dari `pb_schema.json`.

### Tiket muncul di semua HP

Sinkronisasinya dua arah. Tiket dari perangkat lain ditarik otomatis saat:
app dibuka, tab **Daftar** dibuka, tanggal digeser, dan setelah sinkronisasi
manual — petugas tidak perlu menekan apa pun.

**Tombol SYNC** di pojok kanan atas menarik semuanya sekaligus (kirim antrian +
ambil tiket + selaraskan merek), dari tab mana pun. Tombol yang sama juga ada
di **Pengaturan → Server & antrian**.

Tidak ada realtime: perubahan di HP lain baru terlihat setelah salah satu
pemicu di atas. Kalau petugas tahu ada perubahan dan tidak mau menunggu,
tekan **SYNC**.

Yang ditarik hanya tiket **untuk tanggal yang sedang dilihat**, bukan seluruh
riwayat, supaya tidak makin berat tiap tahun.

Kalau tiket yang sama ada di dua tempat: **versi lokal yang belum terkirim
selalu menang** (ketikan petugas tidak boleh hilang), selain itu versi server
yang menang. Tidak ada merge per-field — dua orang mengedit tiket yang sama
nyaris bersamaan, yang terakhir mengunggah yang menang.

Jam di server disimpan **UTC**, ditampilkan **waktu lokal HP**. Tiket 19:35 UTC
tampil 02:35 WIB. Itu disengaja: dua HP yang beda zona waktu tetap sepakat soal
urutan kejadian.

Uji dengan PocketBase lokal:

```
pocketbase serve                                   # di PC
adb reverse tcp:8090 tcp:8090                      # lalu isi URL http://127.0.0.1:8090
```

Aturan koleksi di `pb_schema.json` terbuka (tanpa auth) supaya mudah dicoba —
**perketat sebelum dipakai di produksi.**

## Test

```
flutter test
```

Menguji logika yang bisa salah diam-diam: clamp numpad, upsert item, pencatatan
revisi, rekap per merek, format struk, dan round-trip JSON.
