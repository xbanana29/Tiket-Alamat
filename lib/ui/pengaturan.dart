import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import '../models.dart';
import '../pembaruan.dart';
import '../printer.dart';
import '../printer_desktop.dart';
import '../state.dart';
import '../theme.dart';
import 'widgets.dart';

class TabPengaturan extends StatelessWidget {
  const TabPengaturan({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return s.aturView == 'merek' ? const _Merek() : const _Utama();
  }
}

/// Urutan pilihan di segmen Tampilan.
const _urutanTema = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

class _Blok extends StatelessWidget {
  final List<Widget> children;
  const _Blok({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(Sudut.lg),
      border: Border.all(color: divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _Utama extends StatefulWidget {
  const _Utama();
  @override
  State<_Utama> createState() => _UtamaState();
}

class _UtamaState extends State<_Utama> {
  TextEditingController? _petugasCtl;
  TextEditingController? _urlCtl;

  @override
  void dispose() {
    _petugasCtl?.dispose();
    _urlCtl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    _petugasCtl ??= TextEditingController(text: s.petugas);
    _urlCtl ??= TextEditingController(text: s.serverUrl);

    return ListView(
      children: [
        Tap(
          onTap: () => s.ubah(() => s.aturView = 'merek'),
          child: _Blok(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kategori & merek SAK',
                          style: TextStyle(
                            fontSize: f * .9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${s.brands.length} merek · tambah, ubah, hapus',
                          style: TextStyle(
                            fontSize: f * .7,
                            color: neutral600,
                            letterSpacing: f * .7 * .04,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: neutral600),
                ],
              ),
            ],
          ),
        ),
        _Blok(
          children: [
            const JudulBagian('Tampilan'),
            const SizedBox(height: 8),
            Segmen(
              labels: const ['Sistem', 'Terang', 'Gelap'],
              terpilih: _urutanTema.indexOf(s.temaMode.value),
              onPilih: (i) =>
                  s.ubah(() => s.temaMode.value = _urutanTema[i], simpan: true),
              fontSize: f * .82,
            ),
            const SizedBox(height: 8),
            Text(
              switch (s.temaMode.value) {
                ThemeMode.system =>
                  'Ikut tema HP — berganti sendiri saat HP pindah terang/gelap.',
                ThemeMode.light =>
                  'Mode terang — kontras tinggi di siang hari.',
                ThemeMode.dark =>
                  'Mode gelap — nyaman di gudang malam / layar redup.',
              },
              style: TextStyle(
                fontSize: f * .72,
                color: neutral600,
                height: 1.5,
              ),
            ),
          ],
        ),
        _Blok(
          children: [
            const JudulBagian('Ukuran huruf'),
            const SizedBox(height: 8),
            Segmen(
              labels: const ['Kecil', 'Sedang', 'Besar', 'Jumbo'],
              terpilih: s.fontStep,
              onPilih: (i) => s.ubah(() => s.fontStep = i, simpan: true),
              fontSize: f * .78,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: neutral100,
                border: Border.all(color: divider),
                borderRadius: BorderRadius.circular(Sudut.md),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Contoh: ',
                      style: TextStyle(color: neutral600),
                    ),
                    TextSpan(
                      text: 'CAKRA KEMBAR — 12 sak',
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: f * .9, height: 1.4, color: ink),
              ),
            ),
          ],
        ),
        _Blok(
          children: [
            const JudulBagian('Lebar kertas'),
            const SizedBox(height: 8),
            Segmen(
              labels: const ['58 mm', '80 mm'],
              terpilih: s.printerWidth == 58 ? 0 : 1,
              onPilih: (i) =>
                  s.ubah(() => s.printerWidth = i == 0 ? 58 : 80, simpan: true),
              fontSize: f * .82,
              align: TextAlign.left,
            ),
          ],
        ),
        _Blok(
          children: [
            const JudulBagian('Jumlah rangkap'),
            const SizedBox(height: 8),
            Segmen(
              labels: const ['1 rangkap', '2 rangkap'],
              terpilih: s.copies - 1,
              onPilih: (i) => s.ubah(() => s.copies = i + 1, simpan: true),
              fontSize: f * .82,
              align: TextAlign.left,
            ),
            const SizedBox(height: 8),
            Text(
              s.copies == 2
                  ? 'Rangkap 1 untuk kuli muat, rangkap 2 untuk pelanggan.'
                  : 'Satu lembar saja — ditusuk di paku gudang setelah barang keluar.',
              style: TextStyle(
                fontSize: f * .72,
                color: neutral600,
                height: 1.5,
              ),
            ),
          ],
        ),
        _Blok(
          children: [
            const JudulBagian('Sisa kertas bawah'),
            const SizedBox(height: 8),
            Segmen(
              labels: const ['0', '1', '2', '3'],
              terpilih: s.paperFeed.clamp(0, 3),
              onPilih: (i) => s.ubah(() => s.paperFeed = i, simpan: true),
              fontSize: f * .82,
              align: TextAlign.left,
            ),
            const SizedBox(height: 8),
            Text(
              'Baris kosong sebelum potong. Mulai dari 0 bila sisa blank '
              'terlalu panjang; naikkan 1–2 bila tulisan terakhir kepotong.',
              style: TextStyle(
                fontSize: f * .72,
                color: neutral600,
                height: 1.5,
              ),
            ),
          ],
        ),
        const _BlokPrinter(),
        const _BlokPembaruan(),
        _Blok(
          children: [
            const JudulBagian('Server & antrian'),
            const SizedBox(height: 8),
            TextField(
              controller: _urlCtl,
              keyboardType: TextInputType.url,
              onChanged: (v) =>
                  s.ubah(() => s.serverUrl = v.trim(), simpan: true),
              style: TextStyle(fontFamily: mono, fontSize: f * .78, color: ink),
              decoration: InputDecoration(fillColor: neutral100),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Antrian menunggu unggah',
                    style: TextStyle(
                      fontSize: f * .82,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text('${s.queue}', style: heading(f * 1.2)),
                ],
              ),
            ),
            if (s.jumlahDitolak > 0) const _TiketDitolak(),
            // Satu tombol dua arah: kirim antrian + tarik tiket & merek dari
            // perangkat lain. Sama dengan pil SYNC di header.
            TombolAksi(
              s.sedangSync
                  ? 'Menyinkronkan…'
                  : (s.queue > 0
                        ? 'Sinkronkan sekarang (${s.queue} antre)'
                        : 'Sinkronkan sekarang'),
              onTap: s.syncSekarang,
              sekunder: s.queue == 0,
            ),
            const SizedBox(height: 8),
            Text(
              'Mengirim tiket yang mengantre sekaligus mengambil tiket dan '
              'merek dari HP lain. Tiket tetap tercetak saat luring dan '
              'terkirim sendiri begitu internet tersedia.',
              style: TextStyle(
                fontSize: f * .72,
                color: neutral600,
                height: 1.5,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const JudulBagian('Nama petugas sesi ini'),
              const SizedBox(height: 8),
              Isian(
                controller: _petugasCtl!,
                cap: TextCapitalization.words,
                fontSize: f * .9,
              ),
              const SizedBox(height: 8),
              TombolAksi(
                'Simpan nama',
                onTap: () {
                  s.mulaiSesi(_petugasCtl!.text);
                  s.tampilToast('Petugas: ${s.petugas}');
                },
                sekunder: true,
              ),
              const SizedBox(height: 8),
              TombolAksi('Akhiri sesi', onTap: s.akhiriSesi, sekunder: true),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
          child: Column(
            children: [
              Text(
                kAppName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: f * .78,
                  fontWeight: FontWeight.w700,
                  color: neutral700,
                ),
              ),
              const SizedBox(height: 4),
              const WatermarkBy(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Printer: pilih perangkat yang sudah di-pair, tes cetak.
/// Versi terpasang + cek rilis terbaru di GitHub.
class _BlokPembaruan extends StatefulWidget {
  const _BlokPembaruan();
  @override
  State<_BlokPembaruan> createState() => _BlokPembaruanState();
}

class _BlokPembaruanState extends State<_BlokPembaruan> {
  String? _versi;
  Rilis? _rilis;
  bool _sibuk = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    // Versi dibaca dari paket terpasang, bukan konstanta yang bisa lupa
    // dinaikkan saat rilis.
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _versi = p.version);
    });
  }

  Future<void> _cek() async {
    if (_sibuk) return;
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      final r = await cekRilisTerbaru();
      if (mounted) setState(() => _rilis = r);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _galat = e is PembaruanGagal ? e.pesan : '$e');
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _buka(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      AppScope.of(context).tampilToast('Tidak bisa membuka $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = fs(context);
    final sekarang = _versi;
    final r = _rilis;
    final baru =
        sekarang != null && r != null && adaVersiBaru(sekarang, r.versi);

    return _Blok(
      children: [
        const JudulBagian('Versi aplikasi'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                sekarang == null ? '…' : 'Terpasang: $sekarang',
                style: TextStyle(
                  fontSize: f * .88,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (r != null && !baru) ChipNada('Terbaru', warna: badgeOkFg),
          ],
        ),
        if (_galat != null) ...[
          const SizedBox(height: 8),
          Text(
            _galat!,
            style: TextStyle(fontSize: f * .74, color: bahaya, height: 1.4),
          ),
        ],
        if (baru) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: badgeAntriBg,
              borderRadius: BorderRadius.circular(Sudut.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Versi ${r.versi} tersedia',
                  style: TextStyle(
                    fontSize: f * .82,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: badgeAntriFg,
                  ),
                ),
                if (r.catatan.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    // Catatan rilis bisa panjang; ambil bagian awalnya saja.
                    r.catatan.length > 300
                        ? '${r.catatan.substring(0, 300)}…'
                        : r.catatan,
                    style: TextStyle(
                      fontSize: f * .72,
                      height: 1.5,
                      color: badgeAntriFg,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TombolAksi(
                _sibuk ? 'Memeriksa…' : 'Cek pembaruan',
                onTap: _cek,
                sekunder: !baru,
              ),
            ),
            if (baru) ...[
              const SizedBox(width: 8),
              Expanded(
                child: TombolAksi(
                  Platform.isAndroid ? 'Unduh APK' : 'Buka rilis',
                  onTap: () => _buka(
                    Platform.isAndroid && r.unduhanApk != null
                        ? r.unduhanApk!
                        : kHalamanRilis,
                  ),
                  sekunder: true,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          Platform.isAndroid
              ? 'APK diunduh lewat browser, lalu ketuk berkasnya untuk memasang. '
                    'Data tiket tidak terhapus saat memperbarui.'
              : 'Membuka halaman rilis di browser.',
          style: TextStyle(fontSize: f * .72, color: neutral600, height: 1.5),
        ),
      ],
    );
  }
}

/// Tiket yang ditolak server, lintas tanggal.
///
/// Chip "DITOLAK SERVER" di tab Daftar hanya terlihat pada tanggal yang sedang
/// dibuka; tiket bermasalah dari minggu lalu tidak akan pernah ketemu tanpa
/// daftar ini.
class _TiketDitolak extends StatelessWidget {
  const _TiketDitolak();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    final ditolak = s.riwayat.where((t) => t.status == statusDitolak).toList();
    // Cukup beberapa — kalau ratusan, masalahnya di skema server, bukan di tiket.
    const batas = 5;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badgeTolakBg,
        borderRadius: BorderRadius.circular(Sudut.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ditolak.length} tiket ditolak server',
            style: TextStyle(
              fontSize: f * .82,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: badgeTolakFg,
            ),
          ),
          const SizedBox(height: 6),
          for (final t in ditolak.take(batas))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${t.tanggalKunci} ${t.jam} · ${t.pelanggan}',
                style: TextStyle(
                  fontSize: f * .74,
                  fontWeight: FontWeight.w600,
                  color: badgeTolakFg,
                ),
              ),
            ),
          if (ditolak.length > batas)
            Text(
              'dan ${ditolak.length - batas} lainnya',
              style: TextStyle(fontSize: f * .72, color: badgeTolakFg),
            ),
          const SizedBox(height: 6),
          Text(
            'Isinya ditolak server, bukan gangguan jaringan. Tetap dicoba '
            'ulang tiap sinkronisasi — hubungi admin server bila menetap.',
            style: TextStyle(
              fontSize: f * .7,
              height: 1.5,
              color: badgeTolakFg,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlokPrinter extends StatefulWidget {
  const _BlokPrinter();
  @override
  State<_BlokPrinter> createState() => _BlokPrinterState();
}

class _BlokPrinterState extends State<_BlokPrinter> {
  bool _sibuk = false;

  Future<void> _jalankan(AppState s, Future<void> Function() aksi) async {
    if (_sibuk) return;
    setState(() => _sibuk = true);
    try {
      await aksi();
    } on Object catch (e) {
      s.tampilToast(e is PrinterError ? e.pesan : '$e');
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _pindai(AppState s) => _jalankan(s, () async {
    final list = await s.printer.daftarPerangkat();
    if (!mounted) return;
    final pilih = await showDialog<Perangkat>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(
          'Pilih printer',
          style: TextStyle(
            color: ink,
            fontWeight: FontWeight.w700,
            fontSize: fs(c),
          ),
        ),
        children: [
          for (final p in list)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, p),
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  p.nama,
                  style: TextStyle(color: ink, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  p.mac,
                  style: TextStyle(
                    fontFamily: mono,
                    color: neutral600,
                    fontSize: fs(c) * .78,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (pilih == null) return;
    s.ubah(() {
      s.printerMac = pilih.mac;
      s.printerNama = pilih.nama;
    }, simpan: true);
    s.tampilToast('Printer: ${pilih.nama}');
  });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    final adaPrinter = (s.printerMac ?? '').isNotEmpty;
    return _Blok(
      children: [
        const JudulBagian('Printer'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: neutral100,
            border: Border.all(color: divider),
            borderRadius: BorderRadius.circular(Sudut.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adaPrinter ? s.printerNama : 'Belum dipilih',
                      style: TextStyle(
                        fontSize: f * .88,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      adaPrinter
                          ? (PrinterDesktop.didukung
                                ? 'USB · antrean sistem'
                                : 'Bluetooth · ${s.printerMac}')
                          : 'Ketuk ${PrinterDesktop.didukung ? "Cari printer" : "Pindai perangkat"}',
                      style: TextStyle(
                        fontSize: f * .7,
                        color: neutral600,
                        letterSpacing: f * .7 * .04,
                      ),
                    ),
                  ],
                ),
              ),
              ChipNada(
                adaPrinter ? 'Tersimpan' : 'Kosong',
                warna: adaPrinter ? badgeOkFg : neutral600,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          PrinterDesktop.didukung
              ? 'Printer USB dibaca dari antrean sistem '
                    '(${Platform.isLinux ? "CUPS" : "Windows"}). Pasang printernya '
                    'di setelan sistem dulu, lalu pilih di sini.'
              : 'Pasangkan printer lewat Setelan → Bluetooth, lalu pilih di sini. '
                    'Koneksi dibuka otomatis saat mencetak.',
          style: TextStyle(fontSize: f * .74, color: neutral700, height: 1.5),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TombolAksi(
                _sibuk
                    ? 'Tunggu…'
                    : (PrinterDesktop.didukung
                          ? 'Cari printer'
                          : 'Pindai perangkat'),
                onTap: () => _pindai(s),
                sekunder: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TombolAksi(
                'Tes cetak',
                onTap: () => _jalankan(s, () async {
                  await s.printer.tesCetak(
                    mac: s.printerMac,
                    lebarMm: s.printerWidth,
                    paperFeed: s.paperFeed,
                  );
                  s.tampilToast('Tes cetak terkirim');
                }),
                sekunder: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Drilldown: CRUD merek.
class _Merek extends StatefulWidget {
  const _Merek();
  @override
  State<_Merek> createState() => _MerekState();
}

class _MerekState extends State<_Merek> {
  final ctl = TextEditingController();

  /// Nama merek yang sedang diubah; null berarti sedang menambah baru.
  String? namaEdit;
  String kategori = 'Terigu';

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    namaEdit = null;
    ctl.clear();
    kategori = 'Terigu';
  });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    return ListView(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: TextButton.icon(
              onPressed: () {
                _reset();
                s.ubah(() => s.aturView = 'utama');
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Pengaturan'),
              style: TextButton.styleFrom(
                foregroundColor: ink,
                textStyle: TextStyle(
                  fontFamily: 'Archivo',
                  fontSize: f * .9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(Sudut.lg),
            border: Border.all(color: divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JudulBagian(namaEdit == null ? 'Tambah merek' : 'Ubah merek'),
              const SizedBox(height: 10),
              Isian(controller: ctl, hint: 'Nama merek', fontSize: f * .9),
              const SizedBox(height: 10),
              Segmen(
                labels: const ['Terigu', 'Gula'],
                terpilih: kategori == 'Terigu' ? 0 : 1,
                onPilih: (i) =>
                    setState(() => kategori = i == 0 ? 'Terigu' : 'Gula'),
                fontSize: f * .8,
                align: TextAlign.left,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TombolAksi(
                      namaEdit == null ? 'Tambah' : 'Simpan perubahan',
                      onTap: () {
                        final sebelum = s.brands.length;
                        s.simpanMerek(namaEdit, ctl.text, kategori);
                        // Reset form hanya bila simpan benar-benar terjadi.
                        if (namaEdit != null || s.brands.length != sebelum) {
                          _reset();
                        }
                      },
                    ),
                  ),
                  if (namaEdit != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: TombolAksi('Batal', onTap: _reset, sekunder: true),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        for (final m in s.brands)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.nama,
                        style: TextStyle(
                          fontSize: f * .86,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(m.kategori, style: micro(f)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    namaEdit = m.nama;
                    ctl.text = m.nama;
                    kategori = m.kategori;
                  }),
                  style: _aksi(f, ink),
                  child: const Text('Ubah'),
                ),
                TextButton(
                  onPressed: () {
                    s.hapusMerek(m.nama);
                    _reset();
                  },
                  style: _aksi(f, bahaya),
                  child: const Text('Hapus'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  ButtonStyle _aksi(double f, Color c) => TextButton.styleFrom(
    foregroundColor: c,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    textStyle: TextStyle(
      fontFamily: 'Archivo',
      fontSize: f * .82,
      fontWeight: FontWeight.w600,
    ),
  );
}
