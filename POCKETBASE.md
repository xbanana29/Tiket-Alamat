# PocketBase — handoff + dokumentasi server

> **Status (2026-08-01): server SUDAH LIVE** di `https://pb.rejekiamerta.com`.
> Koleksi `tiket` terimport, HTTPS aktif, backup harian jalan.
> Detail akses: [Server terpasang](#server-terpasang).
>
> Bagian "Langkah setup" di bawah disimpan sebagai catatan **cara** server ini
> didirikan (berguna kalau pindah VPS), bukan pekerjaan yang masih tertunda.

---

## Server terpasang

| | |
|---|---|
| API | `https://pb.rejekiamerta.com` — sama dengan default `lib/state.dart`, app tidak perlu diubah |
| Admin UI | `https://pb.rejekiamerta.com/_/` |
| Admin email | `nikokevin29@gmail.com` |
| Admin password | **tidak disimpan di repo** — ada di `/root/pocketbase/.admin-password` pada VPS |
| Versi | PocketBase 0.39.10 |
| Host | VPS `204.168.237.146`, container Docker `pocketbase`, bind `127.0.0.1:8090` |
| Compose | `/root/pocketbase/docker-compose.yml` (+ runbook di `/root/pocketbase/README.md`) |
| Data | `/root/pocketbase/pb_data` |
| Reverse proxy | nginx-proxy-manager (`npm-app-1`) → `pocketbase:8090` lewat network `npm_default` |
| TLS | Let's Encrypt ECDSA, auto-renew oleh NPM |
| DNS | Cloudflare A `pb.rejekiamerta.com` → `204.168.237.146` (proxied) |
| Backup | `/root/backup_pocketbase.sh`, cron harian 21:00 → `r2:vst-laravel/backups/pocketbase`, retensi 30 hari, notif Telegram |

> ⚠️ **Jangan pernah menulis password di file ini.** Versi sebelumnya sempat
> memuat password superuser dalam teks biasa; commit itu masih ada di riwayat
> git dan tidak bisa dihapus begitu saja. Password tersebut **sudah dirotasi**,
> jadi yang tertinggal di riwayat tidak lagi berlaku.
>
> Kalau perlu ganti lagi, lihat [Rotasi password](#rotasi-password-superuser).

### Rotasi password superuser

Password baru (jalankan di mana saja, jangan pakai yang pernah ditulis di chat
atau file):

```bash
openssl rand -base64 24
```

**Cara A — Admin UI (paling gampang):**
`https://pb.rejekiamerta.com/_/` → login → menu profil kanan atas →
**Change password** → simpan.

**Cara B — dari VPS (kalau lupa password lama):**

```bash
ssh root@204.168.237.146
docker exec -it pocketbase /pb/pocketbase superuser upsert nikokevin29@gmail.com 'PASSWORD_BARU'
```

`upsert` membuat akun bila belum ada dan menimpa password bila sudah ada, jadi
aman dipakai walau password lama tidak diketahui.

Setelah ganti, simpan di VPS (bukan di repo) dan kunci izinnya:

```bash
printf '%s\n' 'PASSWORD_BARU' > /root/pocketbase/.admin-password
chmod 600 /root/pocketbase/.admin-password
```

Verifikasi password baru dipakai dan yang lama sudah mati:

```bash
# harus 200 + token
curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  https://pb.rejekiamerta.com/api/collections/_superusers/auth-with-password \
  -H 'Content-Type: application/json' \
  -d '{"identity":"nikokevin29@gmail.com","password":"PASSWORD_BARU"}'

# harus 400 — kalau masih 200, rotasi belum berhasil
curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  https://pb.rejekiamerta.com/api/collections/_superusers/auth-with-password \
  -H 'Content-Type: application/json' \
  -d '{"identity":"nikokevin29@gmail.com","password":"PASSWORD_LAMA"}'
```

Rate limit login = 5 percobaan/menit, jadi jangan menembak berulang kali.

### Setelan server yang tidak default

- **API rules koleksi `tiket` dibiarkan terbuka** (public list/view/create/update)
  — keputusan owner, app internal. Konsekuensi & urutan aman kalau nanti mau
  dikunci: lihat [Kekurangan sisi klien](#kekurangan-sisi-klien-yang-berdampak-ke-server) poin 1.
- **Rate limit hanya di endpoint login** (`_superusers:auth` 5/menit, `*:auth`
  10/menit). Koleksi `tiket` sengaja **tanpa** rate limit — klien mengirim
  antrian tanpa backoff (poin 3).
- **Trusted proxy** = header `CF-Connecting-IP`, karena di belakang Cloudflare + NPM.

### Verifikasi yang sudah dijalankan (2026-08-01)

- create → `getFirstListItem` → update lewat domain publik: semua 200, tetap **1 record** (upsert jalan).
- `tiket_id` duplikat ditolak 400 oleh unique index `idx_tiket_id`.
- 120 create beruntun: semua 200 (antrian panjang tidak kena limit).
- 7× login admin salah: 429 mulai percobaan ke-6.
- Container di-restart: endpoint tetap sehat (`restart: always`).
- Backup manual: 228K terunggah ke R2.
- Seluruh record uji sudah dihapus — koleksi `tiket` kosong.

---

## Konteks app

| Item | Nilai |
|---|---|
| App | Flutter Android — **Tiket Alamat** (`id.gudang.tiket_gudang`) |
| Repo root | folder `tiket_gudang` (file ini di root yang sama) |
| Sync client | `lib/sync.dart` — package `pocketbase` Dart |
| Default URL di kode | `https://pb.rejekiamerta.com` (`lib/state.dart` → `serverUrl`) |
| User bisa override | **Pengaturan → Server & antrian** (tersimpan di `data.json` lokal) |
| Schema | `pb_schema.json` di root repo |

### Perilaku yang sudah diimplementasi

1. Tiket **selalu** disimpan lokal dulu (`Store` → `data.json`).
2. Status awal: `Menunggu unggah` (`models.dart` → `statusAntri`).
3. Saat online / tombol **Unggah sekarang**: `Sync.push` ke koleksi `tiket`.
4. Sukses → status `Terkirim`. Gagal → tetap antri, coba lagi nanti.
5. **Upsert** by field `tiket_id` (edit tiket → push ulang update, bukan dobel create).
6. Server mati / DNS gagal = **bukan bug** — antrian menumpuk (diharapkan).

Payload push (`lib/sync.dart`):

```json
{
  "tiket_id": "<string id lokal>",
  "pelanggan": "...",
  "waktu": "<ISO8601 UTC>",
  "petugas": "...",
  "mode": "sak" | "minyak",
  "items": [{ "nama": "...", "qty": 1 }],
  "jerigen": 0,
  "revisi": [{ "pelanggan": "...", "baris": ["20 SAK ..."] }]
}
```

Filter lookup: `tiket_id='<id>'` lalu `update`, atau `create` bila 404.

---

## Status tugas setup

- [x] VPS / host dengan binary PocketBase — container Docker, bukan systemd
- [x] DNS: `pb.rejekiamerta.com` → IP VPS (A record)
- [x] HTTPS (Let's Encrypt lewat nginx-proxy-manager)
- [x] PocketBase serve (Docker `restart: always`)
- [x] Import koleksi dari `pb_schema.json`
- [x] Admin user PocketBase dibuat
- [ ] ~~**API rules dikunci**~~ — sengaja **tidak** dikunci, keputusan owner (app internal)
- [ ] Smoke test dari app: unggah 1 tiket dari HP → status `Terkirim`
      (sisi server sudah diverifikasi lewat HTTP; tinggal dites dari perangkat)

---

## Langkah setup (ikuti berurutan)

### 1. Install PocketBase di VPS

Contoh Ubuntu:

```bash
# unduh rilis terbaru dari https://github.com/pocketbase/pocketbase/releases
# pilih linux_amd64 (atau arm64 sesuai VPS)
mkdir -p /opt/pocketbase && cd /opt/pocketbase
# tar -xzf pocketbase_*_linux_amd64.zip
chmod +x pocketbase
./pocketbase superuser upsert ADMIN_EMAIL ADMIN_PASSWORD
```

### 2. Systemd (agar hidup terus)

```ini
# /etc/systemd/system/pocketbase.service
[Unit]
Description=PocketBase Tiket Alamat
After=network.target

[Service]
Type=simple
User=pocketbase
WorkingDirectory=/opt/pocketbase
ExecStart=/opt/pocketbase/pocketbase serve --http=127.0.0.1:8090
Restart=on-failure
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable --now pocketbase
```

PocketBase **jangan** expose `:8090` ke publik mentah — taruh di belakang reverse proxy HTTPS.

### 3. DNS + HTTPS

- DNS: `pb.rejekiamerta.com` A → IP VPS  
- Reverse proxy (Caddy / Nginx) → `127.0.0.1:8090`  
- Sertifikat TLS valid (app Android menolak cleartext ke domain non-localhost kecuali diizinkan)

Contoh Caddy:

```
pb.rejekiamerta.com {
    reverse_proxy 127.0.0.1:8090
}
```

Admin UI: `https://pb.rejekiamerta.com/_/`

### 4. Buat koleksi

> ⚠️ `pb_schema.json` adalah **rujukan bentuk**, bukan payload impor siap pakai.
> Menempelkannya ke **Import collections** ditolak dengan
> *"Invalid collections configuration"* — PocketBase 0.23+ menuntut field
> sistem (`id`, `created`, `updated`) ikut dideklarasikan.
>
> Selain itu opsi **"Delete missing collections"** di layar impor bisa
> **menghapus koleksi lain beserta seluruh isinya**. Untuk menambah satu
> koleksi, impor bukan cara yang sepadan risikonya.

**Cara yang dianjurkan — buat manual lewat Admin UI.**

Koleksi **`tiket`**:

| Field | Tipe | Setelan |
|---|---|---|
| `tiket_id` | Text | required |
| `pelanggan` | Text | required |
| `waktu` | Date | required |
| `petugas` | Text | required |
| `mode` | Select | required, max 1, values `sak`, `minyak` |
| `items` | JSON | max 20000 |
| `jerigen` | Number | 0–99 |
| `revisi` | JSON | max 50000 |

Index: `CREATE UNIQUE INDEX \`idx_tiket_id\` ON \`tiket\` (\`tiket_id\`)`

Koleksi **`merek`**:

| Field | Tipe | Setelan |
|---|---|---|
| `nama` | Text | required |
| `kategori` | Select | required, max 1, values `Terigu`, `Gula` |
| `dihapus` | Bool | — |
| `diubah` | Date | required |

Index: `CREATE UNIQUE INDEX \`idx_merek_nama\` ON \`merek\` (\`nama\`)`

Index unik itu **bukan opsional**: tanpanya dua perangkat yang menambah baris
bersamaan membuat duplikat, dan penggabungan di klien jadi tidak menentu.

API Rules kedua koleksi: `list`/`view`/`create`/`update` dikosongkan (publik),
`delete` dibiarkan terkunci.

**Kalau tetap ingin lewat JSON:** **Settings → Export collections** dulu, lalu
tiru persis bentuk keluaran itu untuk koleksi baru — di situ terlihat field
sistem apa saja yang harus ikut disertakan pada versi PocketBase yang dipakai.

Field wajib (harus cocok dengan `sync.dart`):

| Field | Type | Catatan |
|---|---|---|
| `tiket_id` | text, required | unique index |
| `pelanggan` | text, required | |
| `waktu` | date, required | app kirim UTC ISO8601 |
| `petugas` | text, required | |
| `mode` | select `sak` \| `minyak` | |
| `items` | json | array `{nama, qty}` |
| `jerigen` | number 0–99 | mode minyak |
| `revisi` | json | array jejak edit |

### 5. API rules (penting)

`pb_schema.json` saat ini **sengaja terbuka** (list/view/create/update = `""` = public) agar dev mudah.

**Sebelum production:**

- Kunci create/update (API key, auth user device, atau rule sempit).  
- `deleteRule` biarkan null / superuser only.  
- Jangan biarkan publik `list` seluruh tiket gudang tanpa auth.

Opsi praktis minimal:

1. Buat collection auth / user service untuk device gudang, **atau**  
2. Pakai rule + header custom / token (butuh ubah `lib/sync.dart` bila auth ditambah).

Kalau rules diganti ke butuh auth, **update `lib/sync.dart`** supaya login/auth dulu sebelum `push`. Saat ini client **tanpa auth**.

> ⚠️ **Urutannya penting.** Mengunci rules sebelum klien punya auth akan
> menghentikan sinkronisasi seluruh device secara diam-diam. Baca
> [Kekurangan sisi klien](#kekurangan-sisi-klien-yang-berdampak-ke-server)
> poin 1 & 2 sebelum menyentuh rules.

### 6. Arahkan app

Default kode sudah:

```
https://pb.rejekiamerta.com
```

Device yang pernah jalan dengan URL lama menyimpan URL di `data.json` lokal — user harus ganti manual di **Pengaturan → Server & antrian**, atau clear data app.

Uji lokal sebelum DNS:

```bash
# PC
./pocketbase serve

# HP via USB
adb reverse tcp:8090 tcp:8090
# URL di app: http://127.0.0.1:8090
```

### 7. Verifikasi end-to-end

1. HP online, URL = `https://pb.rejekiamerta.com`  
2. Buat tiket sak → cetak (atau simpan)  
3. Badge **ANTRI** turun setelah unggah  
4. Admin UI: record di koleksi `tiket`  
5. **Ubah** tiket di app → unggah lagi → **1 record** (update by `tiket_id`), bukan 2  
6. Matikan server → tiket baru tetap `Menunggu unggah` → nyalakan server → unggah sukses  

---

## Batasan yang perlu diketahui AI

- Sync **dua arah**, tapi tarikannya **per tanggal**, bukan seluruh riwayat:
  app hanya meminta tiket untuk tanggal yang sedang dibuka di tab Daftar
  (filter `waktu >= awal-hari && waktu < awal-hari-berikutnya`, dalam UTC).
  Server perlu melayani query filter itu dengan lancar; jangan hapus atau
  ganti tipe field `waktu`.
- **Resolusi konflik seadanya:** tiket lokal yang belum terkirim selalu menang;
  selebihnya versi server yang menang. Tidak ada merge per-field, tidak ada
  vector clock. Dua petugas mengedit tiket yang sama nyaris bersamaan =
  yang terakhir push menang.
- Tidak ada realtime/subscribe — tarikan hanya saat tab Daftar dibuka, tanggal
  digeser, app mulai, dan setelah unggah.  
- Antrian hanya dicoba saat app hidup + online (`connectivity_plus`); bukan workmanager background.  
- Filter `tiket_id='...'` raw — ID lokal = timestamp microsecond (aman); jangan ganti ke input user mentah.  
- `pb.rejekiamerta.com` harus HTTPS di production Android.  

---

## Kekurangan sisi klien yang berdampak ke server

> Bagian ini untuk AI yang mengurus VPS. Semuanya **sudah terverifikasi di kode**,
> bukan dugaan. Baca sebelum mengunci rules atau menyalahkan server saat ada
> perilaku aneh.

### 1. Klien tanpa auth sama sekali

`lib/sync.dart` membuat `PocketBase(url)` polos — tidak ada `authWithPassword`,
tidak ada header token. Konsekuensi: **begitu Anda mengunci `createRule`/`updateRule`,
semua unggahan langsung gagal 403** dan tiket menumpuk di HP tanpa ada yang sadar.

Urutan aman:

1. Tambahkan auth di `lib/sync.dart` **lebih dulu**, rilis APK-nya ke perangkat.
2. Baru kunci rules di server.

Membalik urutan ini = gudang berhenti sinkron tanpa pesan error yang jelas.

### 2. Record yang ditolak dilewati, tapi tidak pernah menyerah

`unggahAntrian()` di `lib/state.dart` membedakan dua jenis kegagalan:

| Kondisi | Perilaku klien |
|---|---|
| 4xx validasi (400/422, unique bentrok, enum salah) | **lewati tiket itu**, lanjut ke berikutnya |
| 401 / 403 / 408 / 429 / 5xx / jaringan mati | **hentikan antrian**, coba lagi nanti |

Klasifikasinya ada di `ditolakPermanen()` (`lib/sync.dart`).

Yang perlu diketahui server:

- Tiket yang ditolak diberi status **`Ditolak server`** (chip merah di tab
  Daftar + daftar ringkas di **Pengaturan → Server & antrian**), tapi **tetap
  dihitung belum terkirim dan tetap dicoba lagi** setiap sinkronisasi. Status
  itu penanda, bukan jalan buntu — begitu skema server diperbaiki, tiketnya
  masuk sendiri tanpa campur tangan petugas.
- Karena tetap dicoba ulang, server yang menolak permanen akan menerima request
  yang sama berulang selamanya dan badge **ANTRI** tidak pernah nol. Perbaiki
  skema/data-nya supaya tiketnya bisa masuk — tidak ada tombol "buang tiket
  ini" di app.
- Menambahkan field `required` baru di koleksi `tiket` akan membuat **semua**
  tiket lama ditolak. Klien tidak akan berhenti, tapi juga tidak akan pernah
  berhasil. Jangan lakukan tanpa mengubah `lib/sync.dart`.
- 401/403 dari rules yang baru dikunci akan **menghentikan** antrian total —
  itu memang disengaja, lihat poin 1.

### 3. Tidak ada retry backoff, tidak ada batas ukuran

- Retry hanya dipicu ulang saat konektivitas berubah atau user menekan
  **Unggah sekarang** — tidak ada exponential backoff.
- Semua tiket antri dikirim **satu per satu berurutan**, tanpa batch dan tanpa
  batas jumlah. Device yang luring seminggu akan menembak ratusan request
  beruntun begitu online. Siapkan rate limit yang **longgar** (atau kecualikan
  koleksi `tiket`), jangan yang agresif.

### 4. Tidak ada penanganan jam yang meleset

`waktu` dikirim dari jam HP (`DateTime.now().toUtc()`). Tidak ada sinkronisasi
NTP dan tidak ada koreksi. HP dengan jam salah akan menghasilkan record dengan
`waktu` salah, dan **server menerimanya apa adanya**. Jangan pakai `waktu`
sebagai sumber kebenaran untuk urutan kejadian lintas device; pakai
`created` bawaan PocketBase kalau butuh urutan yang andal.

### 5. `revisi` tumbuh tanpa batas

Setiap kali tiket diedit, satu entri ditambahkan ke array `revisi` dan
**seluruh array ikut dikirim ulang**. Tiket yang diedit puluhan kali membuat
payload membesar terus. `maxSize` field `revisi` di `pb_schema.json` = 50000;
kalau terlampaui, push tiket itu ditolak selamanya → lihat poin 2.

### 6. Status tiket hanya ada di HP

Tidak ada field status di server — `Menunggu unggah` / `Ditolak server` /
`Terkirim` semuanya lokal. HP menandai `Terkirim` **setelah** panggilan
sukses. Kalau response hilang di tengah jalan (timeout padahal server sudah
menyimpan), HP tetap menganggapnya antri dan akan mengirim ulang. Upsert by
`tiket_id` yang menyelamatkan keadaan ini — **jangan hapus unique index
`tiket_id`**, itu satu-satunya pengaman terhadap duplikat.

### 7. Tidak ada migrasi URL otomatis

Device yang pernah dijalankan dengan URL lama menyimpannya di `data.json`.
Mengganti default di kode **tidak** mengubah device yang sudah jalan — harus
diubah manual di **Pengaturan → Server & antrian**. Saat memindahkan domain,
hitung device lama sebagai pekerjaan manual.

### 8. Tidak ada backup di sisi HP

`data.json` ada di direktori dokumen app. **Uninstall app = data hilang.**
Server adalah satu-satunya salinan tahan lama, jadi backup `pb_data` bukan
opsional — lihat checklist di bawah.

---

## File terkait di repo

```
tiket_gudang/
  pb_schema.json      ← import ke PocketBase
  POCKETBASE.md       ← dokumen ini
  lib/sync.dart       ← client push + upsert
  lib/state.dart      ← serverUrl default, unggahAntrian()
  lib/models.dart     ← statusAntri / statusTerkirim, Tiket JSON
  README.md           ← ringkas menjalankan app
```

---

## Checklist selesai

- [x] `https://pb.rejekiamerta.com/_/` admin bisa login  
- [x] Koleksi `tiket` + index `tiket_id` ada  
- [ ] App unggah → status **Terkirim** (belum dites dari HP)  
- [x] Edit + re-upload tidak dobel record (diuji lewat HTTP)  
- [ ] ~~Rules production dikunci~~ — sengaja terbuka, keputusan owner  
- [x] Backup `pb_data` terjadwal (harian 21:00 → Cloudflare R2, retensi 30 hari)  

---

*Server live sejak 2026-08-01 di `pb.rejekiamerta.com`.*
