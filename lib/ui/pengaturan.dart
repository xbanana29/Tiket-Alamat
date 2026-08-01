import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
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

class _Blok extends StatelessWidget {
  final List<Widget> children;
  const _Blok({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: divider)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
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
                        Text('Kategori & merek SAK',
                            style: TextStyle(
                              fontSize: f * .9,
                              fontWeight: FontWeight.w700,
                            )),
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
                  Text('›',
                      style: TextStyle(
                        fontSize: f * 1.1,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ],
          ),
        ),
        _Blok(
          children: [
            const LabelMikro('Tampilan'),
            const SizedBox(height: 8),
            Segmen(
              labels: const ['Terang', 'Gelap'],
              terpilih: s.darkMode ? 1 : 0,
              onPilih: (i) =>
                  s.ubah(() => s.darkMode = i == 1, simpan: true),
              fontSize: f * .82,
              align: TextAlign.left,
            ),
            const SizedBox(height: 8),
            Text(
              s.darkMode
                  ? 'Mode gelap — nyaman di gudang malam / layar redup.'
                  : 'Mode terang — kontras tinggi di siang hari.',
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
            const LabelMikro('Ukuran huruf'),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
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
            const LabelMikro('Lebar kertas'),
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
            const LabelMikro('Jumlah rangkap'),
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
            const LabelMikro('Sisa kertas bawah'),
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
        _Blok(
          children: [
            const LabelMikro('Server & antrian'),
            const SizedBox(height: 8),
            TextField(
              controller: _urlCtl,
              keyboardType: TextInputType.url,
              onChanged: (v) => s.ubah(() => s.serverUrl = v.trim(), simpan: true),
              style: TextStyle(fontFamily: mono, fontSize: f * .78, color: ink),
              decoration: InputDecoration(fillColor: neutral100),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Antrian menunggu unggah',
                      style: TextStyle(
                        fontSize: f * .82,
                        fontWeight: FontWeight.w600,
                      )),
                  Text('${s.queue}', style: heading(f * 1.2)),
                ],
              ),
            ),
            if (s.jumlahDitolak > 0) const _TiketDitolak(),
            TombolAksi(
              s.queue > 0 ? 'Unggah sekarang (${s.queue})' : 'Semua tersinkron',
              onTap: s.unggahAntrian,
              warna: s.queue > 0 ? accent : neutral200,
              teks: s.queue > 0 ? Colors.white : neutral700,
            ),
            const SizedBox(height: 8),
            Text(
              'Tiket tetap tercetak saat luring. Data terkirim sendiri '
              'begitu internet tersedia.',
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
              const LabelMikro('Nama petugas sesi ini'),
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
                warna: neutral200,
                teks: ink,
              ),
              const SizedBox(height: 8),
              TombolAksi('Akhiri sesi', onTap: s.akhiriSesi),
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
      padding: const EdgeInsets.all(10),
      color: badgeTolakBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ditolak.length} TIKET DITOLAK SERVER',
            style: TextStyle(
              fontSize: f * .68,
              fontWeight: FontWeight.w800,
              letterSpacing: f * .68 * .06,
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

  Future<void> _jalankan(
    AppState s,
    Future<void> Function() aksi,
  ) async {
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
        backgroundColor: bg,
        shape: const RoundedRectangleBorder(),
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
        const LabelMikro('Printer'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: neutral100,
            border: Border.all(color: divider),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                color: adaPrinter ? accent : neutral200,
                child: Text(
                  adaPrinter ? 'TERSIMPAN' : 'KOSONG',
                  style: TextStyle(
                    fontSize: f * .66,
                    fontWeight: FontWeight.w700,
                    letterSpacing: f * .66 * .06,
                    color: adaPrinter ? Colors.white : neutral700,
                  ),
                ),
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
                warna: neutral200,
                teks: ink,
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
                warna: bg,
                teks: ink,
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
  int? idx;
  String kategori = 'Terigu';

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    idx = null;
    ctl.clear();
    kategori = 'Terigu';
  });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    return ListView(
      children: [
        Tap(
          onTap: () {
            _reset();
            s.ubah(() => s.aturView = 'utama');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ink, width: 2)),
            ),
            child: Text(
              '‹ PENGATURAN',
              style: TextStyle(
                fontSize: f * .76,
                fontWeight: FontWeight.w700,
                letterSpacing: f * .76 * .06,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: neutral100,
            border: Border(bottom: BorderSide(color: ink, width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabelMikro(idx == null ? 'Tambah merek' : 'Ubah merek'),
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
                      idx == null ? 'Tambah' : 'Simpan perubahan',
                      onTap: () {
                        final sebelum = s.brands.length;
                        s.simpanMerek(idx, ctl.text, kategori);
                        // Reset form hanya bila simpan benar-benar terjadi.
                        if (idx != null || s.brands.length != sebelum) _reset();
                      },
                    ),
                  ),
                  if (idx != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: TombolAksi(
                        'Batal',
                        onTap: _reset,
                        warna: bg,
                        teks: ink,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        for (var i = 0; i < s.brands.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.brands[i].nama,
                          style: TextStyle(
                            fontSize: f * .86,
                            fontWeight: FontWeight.w700,
                          )),
                      Text(s.brands[i].kategori.toUpperCase(),
                          style: micro(f * .97)),
                    ],
                  ),
                ),
                Tap(
                  onTap: () => setState(() {
                    idx = i;
                    ctl.text = s.brands[i].nama;
                    kategori = s.brands[i].kategori;
                  }),
                  child: Text('UBAH', style: _aksi(f, ink)),
                ),
                const SizedBox(width: 12),
                Tap(
                  onTap: () {
                    s.hapusMerek(i);
                    _reset();
                  },
                  child: Text('HAPUS', style: _aksi(f, accent700)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  TextStyle _aksi(double f, Color c) => TextStyle(
    fontSize: f * .72,
    fontWeight: FontWeight.w700,
    letterSpacing: f * .72 * .06,
    color: c,
  );
}
