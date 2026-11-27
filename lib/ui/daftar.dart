import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import 'widgets.dart';

class TabDaftar extends StatelessWidget {
  const TabDaftar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    final terpilih = s.tiketTerpilih;
    return Column(
      children: [
        // Navigasi tanggal: ‹ / label (ketuk = hari ini) / ›
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              _Panah(
                Icons.chevron_left,
                'Hari sebelumnya',
                () => s.pilihTanggal(hari: -1),
              ),
              Expanded(
                child: Tap(
                  onTap: () => s.pilihTanggal(),
                  child: Column(
                    children: [
                      Text(
                        fmtTanggal(s.tanggal),
                        style: TextStyle(
                          fontSize: f * .9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        s.sedangTarik
                            ? 'Mengambil dari server…'
                            : '${terpilih.length} tiket · ketuk untuk hari ini',
                        style: micro(f),
                      ),
                    ],
                  ),
                ),
              ),
              _Panah(
                Icons.chevron_right,
                'Hari berikutnya',
                () => s.pilihTanggal(hari: 1),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Segmen(
            labels: const ['Tiket', 'Laporan'],
            terpilih: s.daftarView == 'tiket' ? 0 : 1,
            onPilih: (i) =>
                s.ubah(() => s.daftarView = i == 0 ? 'tiket' : 'laporan'),
            fontSize: f * .8,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Segmen(
            labels: const ['Semua', 'Terigu / Gula', 'Minyak'],
            terpilih: ['semua', 'sak', 'minyak'].indexOf(s.histFilter),
            onPilih: (i) =>
                s.ubah(() => s.histFilter = ['semua', 'sak', 'minyak'][i]),
            fontSize: f * .8,
          ),
        ),
        Divider(color: divider),
        Expanded(
          child: s.daftarView == 'tiket'
              ? _ListTiket(tiket: terpilih)
              : _Laporan(tiket: terpilih),
        ),
      ],
    );
  }
}

class _Panah extends StatelessWidget {
  final IconData ikon;
  final String keterangan;
  final VoidCallback onTap;
  const _Panah(this.ikon, this.keterangan, this.onTap);

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    onPressed: onTap,
    tooltip: keterangan,
    icon: Icon(ikon),
    style: IconButton.styleFrom(
      side: BorderSide(color: divider),
      foregroundColor: ink,
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sudut.md),
      ),
    ),
  );
}

/// Chip status tiket: abu-abu terkirim, kuning antri, merah ditolak server.
class _ChipStatus extends StatelessWidget {
  final String status;
  final double f;
  const _ChipStatus({required this.status, required this.f});

  @override
  Widget build(BuildContext context) {
    final warna = switch (status) {
      statusTerkirim => badgeOkFg,
      statusDitolak => badgeTolakFg,
      _ => badgeAntriFg,
    };
    final label = status.isEmpty
        ? status
        : status[0].toUpperCase() + status.substring(1);
    return ChipNada(label, warna: warna);
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    child: Text(
      'Tidak ada tiket pada tanggal ini.',
      style: TextStyle(fontSize: fs(context) * .78, color: neutral600),
    ),
  );
}

class _ListTiket extends StatelessWidget {
  final List<Tiket> tiket;
  const _ListTiket({required this.tiket});

  @override
  Widget build(BuildContext context) {
    if (tiket.isEmpty) return const _Kosong();
    final s = AppScope.of(context);
    final f = fs(context);
    return ListView.builder(
      itemCount: tiket.length,
      itemBuilder: (_, i) {
        final r = tiket[i];
        // Baris revisi lama dicoret, di atas baris pesanan yang berlaku.
        final baris = <(String, bool)>[
          for (final rev in r.revisi)
            for (final t in rev.baris) (t, true),
          for (final t in r.barisTeks) (t, false),
        ];
        final namaLama =
            r.revisi.isNotEmpty && r.revisi.last.pelanggan != r.pelanggan
            ? r.revisi.last.pelanggan
            : null;
        // Satu tiket satu kartu, seperti daftar dokumen AmePOS.
        return Container(
          margin: EdgeInsets.fromLTRB(12, i == 0 ? 10 : 4, 12, 4),
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(Sudut.lg),
            border: Border.all(color: divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      r.pelanggan,
                      style: TextStyle(
                        fontSize: f * .92,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    r.jam,
                    style: TextStyle(fontSize: f * .7, color: neutral600),
                  ),
                ],
              ),
              if (namaLama != null)
                Text(
                  namaLama,
                  style: TextStyle(
                    fontSize: f * .74,
                    color: neutral500,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              const SizedBox(height: 5),
              for (final (teks, coret) in baris)
                Text(
                  teks,
                  style: TextStyle(
                    fontSize: f * .78,
                    height: 1.4,
                    color: coret ? neutral500 : neutral800,
                    decoration: coret ? TextDecoration.lineThrough : null,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _ChipStatus(status: r.status, f: f),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.petugas,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: f * .72, color: neutral600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _bukaEdit(context, r),
                    style: _aksi(f, ink),
                    child: const Text('Ubah'),
                  ),
                  if (s.bolehHapusTiket)
                    TextButton(
                      onPressed: () => _konfirmasiHapus(context, r),
                      style: _aksi(f, bahaya),
                      child: const Text('Hapus'),
                    ),
                  TextButton(
                    onPressed: () => s.cetakUlang(r),
                    style: _aksi(f, accent700),
                    child: const Text('Cetak ulang'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  ButtonStyle _aksi(double f, Color c) => TextButton.styleFrom(
    foregroundColor: c,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    textStyle: TextStyle(
      fontFamily: 'Archivo',
      fontSize: f * .8,
      fontWeight: FontWeight.w600,
    ),
  );

  /// Menghapus tiket tidak bisa dibatalkan dan ikut menghapusnya di HP lain,
  /// jadi selalu ditanya dulu.
  void _konfirmasiHapus(BuildContext context, Tiket r) {
    final s = AppScope.of(context);
    final f = fs(context);
    showDialog<void>(
      context: context,
      builder: (d) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hapus tiket?', style: heading(f * 1.1)),
                  const SizedBox(height: 10),
                  Text(
                    r.pelanggan,
                    style: TextStyle(
                      fontSize: f * 1.05,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${r.jam} · ${r.barisTeks.join(", ")}',
                    style: TextStyle(fontSize: f * .78, color: neutral600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tiket ini hilang dari HP ini dan dari server, lalu ikut '
                    'hilang di HP lain saat sync. Tidak bisa dibatalkan.',
                    style: TextStyle(
                      fontSize: f * .76,
                      height: 1.5,
                      color: neutral700,
                    ),
                  ),
                ],
              ),
            ),
            FooterDua(
              kiri: 'Batal',
              kanan: 'Hapus',
              bahaya: true,
              onKiri: () => Navigator.pop(d),
              onKanan: () {
                Navigator.pop(d);
                s.hapusTiket(r);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _bukaEdit(BuildContext context, Tiket r) {
    final s = AppScope.of(context);
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => AppScope(
        state: s,
        child: SheetUbahTiket(tiket: r),
      ),
    );
  }
}

/// Sheet "Ubah tiket": ganti nama pelanggan, qty per merek, atau jumlah jerigen.
class SheetUbahTiket extends StatefulWidget {
  final Tiket tiket;
  const SheetUbahTiket({super.key, required this.tiket});

  @override
  State<SheetUbahTiket> createState() => _SheetUbahTiketState();
}

class _SheetUbahTiketState extends State<SheetUbahTiket> {
  late final ctl = TextEditingController(text: widget.tiket.pelanggan);
  late List<Item> items = List.of(widget.tiket.items);
  late int jerigen = widget.tiket.jerigen;

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _ubahQty(int i, int d) => setState(() {
    final q = (items[i].qty + d).clamp(0, 99);
    if (q == 0) {
      items.removeAt(i);
    } else {
      items[i] = items[i].copyWith(qty: q);
    }
  });

  void _tambah(String nama) => setState(() {
    final i = items.indexWhere((x) => x.nama == nama);
    if (i >= 0) {
      items[i] = items[i].copyWith(qty: (items[i].qty + 1).clamp(1, 99));
    } else {
      items.add(Item(nama, 1));
    }
  });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    final minyak = widget.tiket.isMinyak;
    return SheetBawah(
      judul: 'Ubah tiket',
      onTutup: () => Navigator.pop(context),
      isi: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LabelMikro('Nama pelanggan'),
                const SizedBox(height: 4),
                Isian(controller: ctl),
              ],
            ),
          ),
          if (minyak)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _Kotak(
                    Icons.remove,
                    'Kurangi',
                    52,
                    () => setState(() {
                      jerigen = (jerigen - 1).clamp(0, 99);
                    }),
                  ),
                  const SizedBox(width: 14),
                  Text('$jerigen', style: heading(f * 2.6, height: 1)),
                  const SizedBox(width: 8),
                  Text('jerigen', style: micro(f * 1.09)),
                  const SizedBox(width: 14),
                  _Kotak(
                    Icons.add,
                    'Tambah',
                    52,
                    () => setState(() {
                      jerigen = (jerigen + 1).clamp(0, 99);
                    }),
                  ),
                ],
              ),
            )
          else ...[
            for (var i = 0; i < items.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].nama,
                        style: TextStyle(
                          fontSize: f * .82,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _Kotak(Icons.remove, 'Kurangi', 40, () => _ubahQty(i, -1)),
                    SizedBox(
                      width: 62,
                      child: Text(
                        '${items[i].qty} sak',
                        textAlign: TextAlign.center,
                        style: heading(f * .95),
                      ),
                    ),
                    _Kotak(Icons.add, 'Tambah', 40, () => _ubahQty(i, 1)),
                    IconButton(
                      onPressed: () => setState(() => items.removeAt(i)),
                      tooltip: 'Buang merek',
                      icon: Icon(Icons.close, color: bahaya),
                    ),
                  ],
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: LabelMikro('Tambah merek'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final b in s.brands)
                    ActionChip(
                      onPressed: () => _tambah(b.nama),
                      avatar: Icon(Icons.add, size: f, color: accent700),
                      label: Text(b.nama),
                      labelStyle: TextStyle(
                        fontSize: f * .8,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                      backgroundColor: surface,
                      side: BorderSide(color: divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Sudut.sm),
                      ),
                    ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(
              'Pesanan lama tetap tercatat dan ditampilkan dicoret '
              'di atas pesanan baru.',
              style: TextStyle(
                fontSize: f * .72,
                color: neutral600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
      footer: FooterDua(
        kiri: 'Batal',
        kanan: 'Simpan perubahan',
        onKiri: () => Navigator.pop(context),
        onKanan: () {
          if (ctl.text.trim().isEmpty) {
            s.tampilToast('Nama pelanggan kosong');
            return;
          }
          s.simpanEdit(
            widget.tiket.id,
            pelanggan: ctl.text,
            items: items,
            jerigen: jerigen,
          );
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Tombol tambah/kurang jumlah: kotak tombol numpad, bersudut 8.
class _Kotak extends StatelessWidget {
  final IconData ikon;
  final String keterangan;
  final double ukuran;
  final VoidCallback onTap;
  const _Kotak(this.ikon, this.keterangan, this.ukuran, this.onTap);

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    onPressed: onTap,
    tooltip: keterangan,
    icon: Icon(ikon, size: ukuran * .5),
    style: IconButton.styleFrom(
      backgroundColor: tombolBg,
      foregroundColor: tombolFg,
      fixedSize: Size.square(ukuran),
      minimumSize: Size.square(ukuran),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sudut.sm),
      ),
    ),
  );
}

class _Laporan extends StatelessWidget {
  final List<Tiket> tiket;
  const _Laporan({required this.tiket});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    final rekap = rekapMerek(tiket);
    final totalSak = rekap.fold(0, (a, b) => a + b.value);
    final totalJerigen = tiket
        .where((t) => t.isMinyak)
        .fold(0, (a, b) => a + b.jerigen);

    // Ikut filter di atasnya: saat Terigu/Gula dipilih, angka minyak selalu 0
    // dan hanya jadi gangguan — begitu pula sebaliknya.
    final tampilSak = s.histFilter != 'minyak';
    final tampilMinyak = s.histFilter != 'sak';

    return ListView(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent200,
            borderRadius: BorderRadius.circular(Sudut.lg),
          ),
          child: Row(
            children: [
              if (tampilSak) _Stat('Total sak', '$totalSak sak', f),
              if (tampilSak && tampilMinyak) const SizedBox(width: 24),
              if (tampilMinyak)
                _Stat('Total minyak', '$totalJerigen jerigen', f),
            ],
          ),
        ),
        if (rekap.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: JudulBagian('Rekap per merek'),
          ),
          for (final e in rekap)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: TextStyle(
                      fontSize: f * .84,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text('${e.value} sak', style: heading(f * .95)),
                ],
              ),
            ),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: JudulBagian('Rincian cetak'),
        ),
        if (tiket.isEmpty) const _Kosong(),
        for (final t in tiket)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: divider)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    t.jam,
                    style: TextStyle(
                      fontFamily: mono,
                      fontSize: f * .8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.pelanggan,
                        style: TextStyle(
                          fontSize: f * .86,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final b in t.barisTeks)
                        Text(
                          b,
                          style: TextStyle(fontSize: f * .8, color: neutral800),
                        ),
                      Text(t.petugas, style: micro(f)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String nilai;
  final double f;
  const _Stat(this.label, this.nilai, this.f);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: micro(f, color: accent800)),
      Text(
        nilai,
        style: heading(
          f * 1.7,
          height: 1.2,
          color: accent800,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    ],
  );
}
