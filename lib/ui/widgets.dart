import 'package:flutter/material.dart';

import '../brand.dart';
import '../state.dart';
import '../theme.dart';

/// Watermark perusahaan — dipakai di setup (awal app) & pengaturan.
class WatermarkBy extends StatelessWidget {
  final double? fontSize;
  final TextAlign align;
  const WatermarkBy({super.key, this.fontSize, this.align = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    final f = fontSize ?? fs(context) * .68;
    return Text(
      kWatermark,
      textAlign: align,
      style: TextStyle(
        fontSize: f,
        color: neutral500,
        fontWeight: FontWeight.w500,
        letterSpacing: f * .04,
        height: 1.3,
      ),
    );
  }
}


/// Akses AppState tanpa paket state-management: satu InheritedNotifier.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Ukuran font dasar layar, mengikuti pengaturan "Ukuran huruf".
double fs(BuildContext c) => (kBaseFontSize * AppScope.of(c).scale).roundToDouble();

/// Area yang bisa diketuk tanpa efek ripple — rancangan pakai div polos.
class Tap extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const Tap({super.key, this.onTap, required this.child});

  @override
  Widget build(BuildContext c) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: child,
  );
}

/// Baris tombol segmen (inversi saat terpilih) — dipakai untuk tab, pilihan font,
/// lebar kertas, rangkap, kategori.
class Segmen extends StatelessWidget {
  final List<String> labels;
  final int terpilih;
  final ValueChanged<int> onPilih;
  final double fontSize;
  final EdgeInsets padding;
  final bool berbingkai;
  final TextAlign align;

  const Segmen({
    super.key,
    required this.labels,
    required this.terpilih,
    required this.onPilih,
    required this.fontSize,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    this.berbingkai = true,
    this.align = TextAlign.center,
  });

  @override
  Widget build(BuildContext c) {
    final row = Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Tap(
              onTap: () => onPilih(i),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: i == terpilih ? ink : bg,
                  border: i == labels.length - 1
                      ? null
                      : Border(right: BorderSide(color: divider)),
                ),
                child: Text(
                  labels[i],
                  textAlign: align,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: fontSize * .06,
                    color: i == terpilih ? bg : ink,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (!berbingkai) return row;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: ink, width: 2)),
      child: row,
    );
  }
}

/// Label mikro uppercase di atas sebuah kolom pengaturan.
class LabelMikro extends StatelessWidget {
  final String teks;
  final Color? color;
  const LabelMikro(this.teks, {super.key, this.color});

  @override
  Widget build(BuildContext c) {
    final f = fs(c);
    return Text(
      teks.toUpperCase(),
      style: micro(f, color: color ?? neutral600),
    );
  }
}

/// Tombol utama merah (Cetak tiket, Simpan, Mulai sesi).
class TombolAksi extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? warna;
  final Color teks;
  const TombolAksi(
    this.label, {
    super.key,
    required this.onTap,
    this.warna,
    this.teks = Colors.white,
  });

  @override
  Widget build(BuildContext c) {
    final f = fs(c);
    return Tap(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        color: warna ?? accent,
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: f * .88,
            fontWeight: FontWeight.w800,
            letterSpacing: f * .88 * .06,
            color: teks,
          ),
        ),
      ),
    );
  }
}

/// Kolom teks bergaya rancangan (border tipis, radius 0).
class Isian extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final double? fontSize;
  final TextCapitalization cap;
  const Isian({
    super.key,
    required this.controller,
    this.hint,
    this.fontSize,
    this.cap = TextCapitalization.characters,
  });

  @override
  Widget build(BuildContext c) {
    final f = fs(c);
    return TextField(
      controller: controller,
      textCapitalization: cap,
      // Nama toko & merek bukan kata kamus — autocorrect malah merusaknya
      // ("REJEKI" jadi "REJEKINYA") dan itu ikut tercetak di tiket.
      autocorrect: false,
      enableSuggestions: false,
      cursorColor: accent,
      style: TextStyle(
        fontSize: fontSize ?? f * .95,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      decoration: InputDecoration(hintText: hint),
    );
  }
}

/// Sheet bawah bergaya rancangan: header judul + ✕, isi bisa digulir, footer aksi.
class SheetBawah extends StatelessWidget {
  final String judul;
  final VoidCallback onTutup;
  final Widget isi;
  final Widget footer;
  final double maxTinggi;
  final Color? isiWarna;

  const SheetBawah({
    super.key,
    required this.judul,
    required this.onTutup,
    required this.isi,
    required this.footer,
    this.maxTinggi = .88,
    this.isiWarna,
  });

  @override
  Widget build(BuildContext c) {
    final f = fs(c);
    // Material diperlukan karena sheet ini juga dipakai lewat showDialog,
    // di luar Scaffold — TextField di dalamnya butuh ancestor Material.
    return Material(
      color: sheetScrim,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(c).size.height * maxTinggi,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                border: Border(top: BorderSide(color: ink, width: 2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: ink, width: 2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            judul.toUpperCase(),
                            style: heading(f, height: 1.1),
                          ),
                        ),
                        Tap(
                          onTap: onTutup,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '✕',
                              style: TextStyle(
                                fontSize: f * .9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Container(color: isiWarna ?? bg, child: isi),
                  ),
                  footer,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer dua tombol: Batal (polos) + aksi utama (merah).
class FooterDua extends StatelessWidget {
  final String kiri;
  final String kanan;
  final VoidCallback onKiri;
  final VoidCallback onKanan;
  const FooterDua({
    super.key,
    required this.kiri,
    required this.kanan,
    required this.onKiri,
    required this.onKanan,
  });

  @override
  Widget build(BuildContext c) {
    final f = fs(c);
    final gaya = TextStyle(
      fontSize: f * .85,
      fontWeight: FontWeight.w700,
      letterSpacing: f * .85 * .06,
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ink, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tap(
              onTap: onKiri,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: divider)),
                ),
                child: Text(
                  kiri.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: gaya,
                ),
              ),
            ),
          ),
          Expanded(
            child: TombolAksi(kanan, onTap: onKanan),
          ),
        ],
      ),
    );
  }
}

/// Papan angka 1-9 / C / 0 / aksi terakhir.
class Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onClear;
  final VoidCallback onAkhir;
  final String labelAkhir;
  final bool akhirMerah;
  final int kolom;
  final double tinggiPad;

  const Numpad({
    super.key,
    required this.onDigit,
    required this.onClear,
    required this.onAkhir,
    required this.labelAkhir,
    this.akhirMerah = true,
    this.kolom = 4,
    this.tinggiPad = 14,
  });

  @override
  Widget build(BuildContext c) {
    final f = fs(c);
    final tombol = <Widget>[
      for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
        _tombol(f, d, bg, ink, () => onDigit(d)),
      _tombol(f, 'C', neutral200, ink, onClear),
      _tombol(f, '0', bg, ink, () => onDigit('0')),
      _tombol(
        f,
        labelAkhir,
        akhirMerah ? accent : neutral200,
        akhirMerah ? Colors.white : ink,
        onAkhir,
      ),
    ];
    return GridView.count(
      crossAxisCount: kolom,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1 / .48,
      children: tombol,
    );
  }

  Widget _tombol(double f, String label, Color warna, Color teks, VoidCallback t) =>
      Tap(
        onTap: t,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: warna,
            border: Border(
              right: BorderSide(color: divider),
              bottom: BorderSide(color: divider),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: f * 1.25,
              fontWeight: FontWeight.w800,
              color: teks,
            ),
          ),
        ),
      );
}
