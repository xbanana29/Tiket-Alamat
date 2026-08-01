# PocketBase — handoff untuk AI / setup nanti

> **Status (2026-08):** server **belum dibuat**. App sudah siap sync offline-first; tiket mengantre status `Menunggu unggah` sampai endpoint hidup.
>
> **Domain target:** `https://pb.rejekiamerta.com`  
> (bukan `pb.gudang.id` — itu placeholder lama.)

Dokumen ini untuk AI/dev yang akan **mendirikan** PocketBase. Jangan asumsikan server sudah ada.

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

## Yang belum ada (tugas setup)

- [ ] VPS / host dengan binary PocketBase
- [ ] DNS: `pb.rejekiamerta.com` → IP VPS (A record)
- [ ] HTTPS (Let's Encrypt + reverse proxy, atau Caddy)
- [ ] `./pocketbase serve` (systemd recommended)
- [ ] Import koleksi dari `pb_schema.json`
- [ ] Admin user PocketBase dibuat
- [ ] **API rules dikunci** sebelum production traffic
- [ ] Smoke test: app unggah 1 tiket → status `Terkirim`

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

### 4. Import schema

1. Login Admin UI  
2. **Settings → Import collections**  
3. Paste / upload isi `pb_schema.json`  
4. Pastikan koleksi **`tiket`** muncul dengan unique index `tiket_id`

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

- **Tidak ada** pull/download tiket dari server ke HP — sync **satu arah** (device → PB).  
- **Tidak ada** multi-device conflict resolution.  
- Antrian hanya dicoba saat app hidup + online (`connectivity_plus`); bukan workmanager background.  
- Filter `tiket_id='...'` raw — ID lokal = timestamp microsecond (aman); jangan ganti ke input user mentah.  
- `pb.rejekiamerta.com` harus HTTPS di production Android.  

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

## Checklist selesai (centang saat done)

- [ ] `https://pb.rejekiamerta.com/_/` admin bisa login  
- [ ] Koleksi `tiket` + index `tiket_id` ada  
- [ ] App unggah → status **Terkirim**  
- [ ] Edit + re-upload tidak dobel record  
- [ ] Rules production dikunci (bukan `""` publik)  
- [ ] Backup volume `/opt/pocketbase/pb_data` terjadwal  

---

*Handoff: server OTW. Domain tetap `pb.rejekiamerta.com` kecuali product owner ganti.*
