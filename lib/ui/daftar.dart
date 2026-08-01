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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: divider)),
          ),
          child: Row(
            children: [
              _Panah('‹', () => s.pilihTanggal(hari: -1)),
              Expanded(
                child: Tap(
                  onTap: () => s.pilihTanggal(),
                  child: Column(
                    children: [
                      Text(
                        fmtTanggal(s.tanggal),
                        style: TextStyle(
                          fontSize: f * .82,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        s.sedangTarik
                            ? 'MENGAMBIL DARI SERVER…'
                            : '${terpilih.length} TIKET · KETUK UNTUK HARI INI',
                        style: micro(f * .94),
                      ),
                    ],
                  ),
                ),
              ),
              _Panah('›', () => s.pilihTanggal(hari: 1)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: divider)),
          ),
          child: Segmen(
            labels: const ['Tiket', 'Laporan'],
            terpilih: s.daftarView == 'tiket' ? 0 : 1,
            onPilih: (i) =>
                s.ubah(() => s.daftarView = i == 0 ? 'tiket' : 'laporan'),
            fontSize: f * .74,
            berbingkai: false,
            align: TextAlign.left,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ink, width: 2)),
          ),
          child: Segmen(
            labels: const ['Semua', 'Terigu / Gula', 'Minyak'],
            terpilih: ['semua', 'sak', 'minyak'].indexOf(s.histFilter),
            onPilih: (i) =>
                s.ubah(() => s.histFilter = ['semua', 'sak', 'minyak'][i]),
            fontSize: f * .74,
            berbingkai: false,
            align: TextAlign.left,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
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
  final String label;
  final VoidCallback onTap;
  const _Panah(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    final f = fs(context);
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(border: Border.all(color: divider)),
        child: Text(
          label,
          style: TextStyle(fontSize: f * .85, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Chip status tiket: abu-abu terkirim, kuning antri, merah ditolak server.
class _ChipStatus extends StatelessWidget {
  final String status;
  final double f;
  const _ChipStatus({required this.status, required this.f});

  @override
  Widget build(BuildContext context) {
    final (bgWarna, fgWarna) = switch (status) {
      statusTerkirim => (badgeOkBg, badgeOkFg),
      statusDitolak => (badgeTolakBg, badgeTolakFg),
      _ => (badgeAntriBg, badgeAntriFg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: bgWarna,
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: f * .66,
          fontWeight: FontWeight.w700,
          letterSpacing: f * .66 * .06,
          color: fgWarna,
        ),
      ),
    );
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
        final namaLama = r.revisi.isNotEmpty && r.revisi.last.pelanggan != r.pelanggan
            ? r.revisi.last.pelanggan
            : null;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: divider)),
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
                  Text(r.jam,
                      style: TextStyle(fontSize: f * .7, color: neutral600)),
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
              const SizedBox(height: 7),
              Row(
                children: [
                  _ChipStatus(status: r.status, f: f),
                  const SizedBox(width: 8),
                  Text(r.petugas,
                      style: TextStyle(fontSize: f * .68, color: neutral600)),
                  const Spacer(),
                  Tap(
                    onTap: () => _bukaEdit(context, r),
                    child: Text('UBAH',
                        style: _aksi(f, ink)),
                  ),
                  const SizedBox(width: 12),
                  Tap(
                    onTap: () => s.cetakUlang(r),
                    child: Text('CETAK ULANG', style: _aksi(f, accent700)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  TextStyle _aksi(double f, Color c) => TextStyle(
    fontSize: f * .7,
    fontWeight: FontWeight.w700,
    letterSpacing: f * .7 * .06,
    color: c,
  );

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
                  _Kotak('–', 48, () => setState(() {
                        jerigen = (jerigen - 1).clamp(0, 99);
                      })),
                  const SizedBox(width: 14),
                  Text('$jerigen', style: heading(f * 2.6, height: 1)),
                  const SizedBox(width: 8),
                  Text('JERIGEN', style: micro(f * 1.09)),
                  const SizedBox(width: 14),
                  _Kotak('+', 48, () => setState(() {
                        jerigen = (jerigen + 1).clamp(0, 99);
                      })),
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
                    _Kotak('–', 34, () => _ubahQty(i, -1)),
                    SizedBox(
                      width: 62,
                      child: Text(
                        '${items[i].qty} sak',
                        textAlign: TextAlign.center,
                        style: heading(f * .95),
                      ),
                    ),
                    _Kotak('+', 34, () => _ubahQty(i, 1)),
                    Tap(
                      onTap: () => setState(() => items.removeAt(i)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('✕',
                            style: TextStyle(
                              color: accent700,
                              fontWeight: FontWeight.w700,
                              fontSize: f * .8,
                            )),
                      ),
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
                  for (final b in s.merekAktif)
                    Tap(
                      onTap: () => _tambah(b.nama),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(border: Border.all(color: ink)),
                        child: Text(
                          b.nama,
                          style: TextStyle(
                            fontSize: f * .72,
                            fontWeight: FontWeight.w700,
                            letterSpacing: f * .72 * .03,
                          ),
                        ),
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

class _Kotak extends StatelessWidget {
  final String label;
  final double ukuran;
  final VoidCallback onTap;
  const _Kotak(this.label, this.ukuran, this.onTap);

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    child: Container(
      width: ukuran,
      height: ukuran,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: ink, width: ukuran > 40 ? 2 : 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fs(context) * (ukuran > 40 ? 1.4 : 1),
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _Laporan extends StatelessWidget {
  final List<Tiket> tiket;
  const _Laporan({required this.tiket});

  @override
  Widget build(BuildContext context) {
    final f = fs(context);
    final rekap = rekapMerek(tiket);
    final totalSak = rekap.fold(0, (a, b) => a + b.value);
    final totalJerigen = tiket
        .where((t) => t.isMinyak)
        .fold(0, (a, b) => a + b.jerigen);

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ink, width: 2)),
          ),
          child: Row(
            children: [
              _Stat('Total sak', '$totalSak sak', f),
              const SizedBox(width: 24),
              _Stat('Total minyak', '$totalJerigen jerigen', f),
            ],
          ),
        ),
        if (rekap.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: LabelMikro('Rekap per merek'),
          ),
          for (final e in rekap)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key,
                      style: TextStyle(
                        fontSize: f * .84,
                        fontWeight: FontWeight.w600,
                      )),
                  Text('${e.value} sak', style: heading(f * .95)),
                ],
              ),
            ),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: LabelMikro('Rincian cetak'),
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
                      Text(t.pelanggan,
                          style: TextStyle(
                            fontSize: f * .86,
                            fontWeight: FontWeight.w700,
                          )),
                      for (final b in t.barisTeks)
                        Text(b,
                            style: TextStyle(
                              fontSize: f * .8,
                              color: neutral800,
                            )),
                      Text(t.petugas.toUpperCase(), style: micro(f * .97)),
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
      Text(label.toUpperCase(), style: micro(f * .97)),
      Text(nilai, style: heading(f * 1.7, height: 1.2)),
    ],
  );
}
