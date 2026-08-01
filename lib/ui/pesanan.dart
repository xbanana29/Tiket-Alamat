import 'package:flutter/material.dart';

import '../models.dart';
import '../printer.dart';

import '../theme.dart';
import 'widgets.dart';

class TabPesanan extends StatelessWidget {
  const TabPesanan({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    // Keyboard buka → lepas numpad/grid/footer cetak (sumber overflow).
    final kb = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ink, width: 2)),
          ),
          child: Segmen(
            labels: const ['Sak', 'Minyak'],
            terpilih: s.isMinyak ? 1 : 0,
            onPilih: (i) => s.ubah(() => s.mode = i == 0 ? 'sak' : 'minyak'),
            fontSize: f * .85,
            berbingkai: false,
            align: TextAlign.left,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: divider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelMikro('Nama pelanggan'),
              const SizedBox(height: 4),
              Isian(
                controller: s.pelangganCtl,
                hint: 'Ketik nama toko / pelanggan',
              ),
            ],
          ),
        ),
        Expanded(
          child: s.isMinyak ? _Minyak(kb: kb) : _Sak(kb: kb),
        ),
        if (!kb)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ink, width: 2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TombolAksi('Cetak tiket', onTap: s.bukaPratinjau),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  color: neutral200,
                  child: Text(
                    (s.isMinyak
                            ? '${s.minyakQty} jerigen'
                            : '${s.totalSak} sak')
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: f * .74,
                      fontWeight: FontWeight.w700,
                      letterSpacing: f * .74 * .06,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Minyak extends StatelessWidget {
  final bool kb;
  const _Minyak({required this.kb});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) {
              // Angka besar menyesuaikan sisa tinggi — tidak paksa f*8 saat sempit.
              final angkaFs = (box.maxHeight * 0.35).clamp(28.0, f * 8);
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LabelMikro('Jumlah jerigen'),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            s.minyakBuf.isEmpty ? '0' : s.minyakBuf,
                            style: heading(angkaFs, height: .9).copyWith(
                              letterSpacing: -angkaFs * .04,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('JERIGEN', style: micro(f * 1.32)),
                        ],
                      ),
                    ),
                    if (!kb) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Maksimal 99 per tiket. Minyak tidak memakai merek — '
                        'hanya pelanggan dan jumlah jerigen.',
                        style: TextStyle(
                          fontSize: f * .72,
                          color: neutral600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        if (!kb)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ink, width: 2)),
            ),
            child: Numpad(
              kolom: 3,
              onDigit: s.tekanMinyak,
              onClear: s.resetMinyak,
              onAkhir: s.hapusMinyakDigit,
              labelAkhir: '⌫',
              akhirMerah: false,
            ),
          ),
      ],
    );
  }
}

class _Sak extends StatelessWidget {
  final bool kb;
  const _Sak({required this.kb});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // Saat keyboard: hanya pratinjau struk (scroll). Grid merek disembunyikan
    // supaya Flexible tidak meluap di sisa tinggi kecil.
    return Column(
      children: [
        Flexible(
          flex: kb ? 1 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: neutral100,
              border: kb
                  ? null
                  : Border(bottom: BorderSide(color: ink, width: 2)),
            ),
            child: const SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: _StrukHidup(),
            ),
          ),
        ),
        if (!kb)
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 230),
              child: GridView.count(
                crossAxisCount: 3,
                padding: const EdgeInsets.all(10),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1 / .72,
                children: [
                  for (final b in s.brands)
                    _TileMerek(merek: b, qty: s.qtyOf(b.nama)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TileMerek extends StatelessWidget {
  final Merek merek;
  final int qty;
  const _TileMerek({required this.merek, required this.qty});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    return Tap(
      onTap: () => s.bukaKeypad(merek.nama),
      child: Container(
        decoration: BoxDecoration(
          color: qty > 0 ? accent200 : bg,
          border: Border.all(color: ink, width: 2),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  merek.nama,
                  style: TextStyle(
                    fontSize: f * 1.05,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: f * 1.05 * .02,
                  ),
                ),
              ),
            ),
            if (qty > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  color: ink,
                  child: Text('$qty', style: heading(f * 1.1, color: bg)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kertas struk putih di tab Pesanan — mencerminkan apa yang akan tercetak.
/// Warna kertas selalu terang (paper/paperInk), independent dari dark mode.
class _StrukHidup extends StatelessWidget {
  const _StrukHidup();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    final kecil = TextStyle(
      fontFamily: mono,
      fontSize: f * .78,
      height: 1.7,
      color: paperInk,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      decoration: BoxDecoration(
        color: paper,
        border: Border.all(color: paperInk.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TANDA AMBIL BARANG',
            textAlign: TextAlign.center,
            style: kecil.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: f * .78 * .12,
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 2, thickness: 2, color: paperInk),
          const SizedBox(height: 12),
          ValueListenableBuilder(
            valueListenable: s.pelangganCtl,
            builder: (_, v, _) => Text(
              v.text.trim().isEmpty ? '—' : v.text.trim().toUpperCase(),
              textAlign: TextAlign.center,
              style: heading(f * .78 * 3.4, height: 1.05, color: paperInk),
            ),
          ),
          const SizedBox(height: 10),
          Text(fmtWaktuCetak(DateTime.now()),
              textAlign: TextAlign.center, style: kecil),
          Text('Petugas: ${s.petugas}',
              textAlign: TextAlign.center, style: kecil),
          const _Putus(),
          if (s.items.isEmpty)
            Text('— belum ada barang —',
                style: kecil.copyWith(color: paperMuted)),
          for (var i = 0; i < s.items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Tap(
                onTap: () => s.hapusItem(i),
                child: Text(
                  '${s.items[i].qty} SAK ${s.items[i].nama}',
                  style: heading(f * .78 * 1.75, color: paperInk),
                ),
              ),
            ),
          const _Putus(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL', style: kecil.copyWith(fontWeight: FontWeight.w700)),
              Text('${s.totalSak} sak',
                  style: kecil.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Putus extends StatelessWidget {
  const _Putus();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: _Dashed(),
  );
}

/// Garis putus-putus ala struk (di atas kertas putih → pakai paperMuted).
class _Dashed extends StatelessWidget {
  const _Dashed();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final n = (c.maxWidth / 6).floor();
      return Row(
        children: List.filled(
          n,
          Container(
            width: 3,
            height: 1,
            color: paperMuted,
            margin: const EdgeInsets.only(right: 3),
          ),
        ),
      );
    },
  );
}

/// Sheet numpad "Jumlah sak" untuk merek yang sedang dipilih.
class KeypadSheet extends StatelessWidget {
  const KeypadSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Tap(
            onTap: s.tutupKeypad,
            child: Container(color: sheetScrim),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              border: Border(top: BorderSide(color: ink, width: 2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: divider)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const LabelMikro('Jumlah sak'),
                            Text(s.armed ?? '—', style: heading(f)),
                          ],
                        ),
                      ),
                      Text(s.buf.isEmpty ? '0' : s.buf,
                          style: heading(f * 2.2, height: 1)),
                    ],
                  ),
                ),
                Numpad(
                  onDigit: s.tekan,
                  onClear: s.hapusBuf,
                  onAkhir: s.konfirmasiQty,
                  labelAkhir: '✓',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pratinjau sebelum mencetak — satu kertas per rangkap.
class PratinjauCetak extends StatelessWidget {
  const PratinjauCetak({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.draft;
    return SheetBawah(
      judul: 'Pratinjau · ${s.printerWidth} mm',
      onTutup: () => s.ubah(() => s.printOpen = false),
      maxTinggi: .86,
      isiWarna: neutral200,
      isi: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (var i = 0; i < s.copies; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              KertasStruk(
                tiket: t,
                judul: s.copies == 1
                    ? 'TANDA AMBIL BARANG'
                    : (i == 0
                          ? 'RANGKAP 1 — KULI MUAT'
                          : 'RANGKAP 2 — PELANGGAN'),
              ),
            ],
          ],
        ),
      ),
      footer: FooterDua(
        kiri: 'Batal',
        kanan: s.copies == 2 ? 'Cetak 2 rangkap' : 'Cetak tiket',
        onKiri: () => s.ubah(() => s.printOpen = false),
        onKanan: s.konfirmasiCetak,
      ),
    );
  }
}

/// Representasi visual satu lembar struk. Dipakai pratinjau cetak & cetak ulang.
/// Selalu kertas putih + tinta gelap, agar terbaca di mode gelap.
class KertasStruk extends StatelessWidget {
  final Tiket tiket;
  final String judul;
  const KertasStruk({super.key, required this.tiket, required this.judul});

  @override
  Widget build(BuildContext context) {
    final f = fs(context);
    final kecil = TextStyle(
      fontFamily: mono,
      fontSize: f * .76,
      height: 1.65,
      color: paperInk,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              judul,
              textAlign: TextAlign.center,
              style: kecil.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: f * .76 * .12,
              ),
            ),
          ),
          const _Dashed(),
          const SizedBox(height: 12),
          Text(
            tiket.pelanggan.isEmpty ? '—' : tiket.pelanggan,
            textAlign: TextAlign.center,
            style: heading(f * .76 * 3.4, height: 1.05, color: paperInk),
          ),
          const SizedBox(height: 10),
          Text(fmtWaktuCetak(tiket.waktu),
              textAlign: TextAlign.center, style: kecil),
          Text('Petugas: ${tiket.petugas}',
              textAlign: TextAlign.center, style: kecil),
          const _Putus(),
          if (tiket.isMinyak)
            Column(
              children: [
                Text(
                  '${tiket.jerigen}',
                  style: heading(f * .76 * 8.5, height: .88, color: paperInk)
                      .copyWith(letterSpacing: -f * .76 * 8.5 * .05),
                ),
                Text(
                  'JERIGEN MINYAK',
                  style: heading(f * .76 * 1.7, height: 1.1, color: paperInk)
                      .copyWith(letterSpacing: f * .76 * 1.7 * .06),
                ),
              ],
            )
          else
            for (final b in tiket.barisTeks)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(b, style: heading(f * .76 * 1.75, color: paperInk)),
              ),
          const _Putus(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL', style: kecil.copyWith(fontWeight: FontWeight.w700)),
              Text(tiket.totalLabel,
                  style: kecil.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tanda terima gudang · tusuk di paku setelah barang keluar',
            style: kecil.copyWith(
              fontSize: f * .68,
              color: paperMuted,
            ),
          ),
        ],
      ),
    );
  }
}
