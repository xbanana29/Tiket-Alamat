# Tiket Alamat

Aplikasi Flutter (Android) untuk mencatat pesanan gudang dan mencetak
"TANDA AMBIL BARANG" di printer thermal Bluetooth.

**by CV Rejeki Amerta Jaya**

## Menjalankan

```
flutter run -d <device-id>
```

Perangkat harus dalam keadaan tidak terkunci.

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
