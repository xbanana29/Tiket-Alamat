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

  /// Ikut bergantung pada Theme: warna UI dibaca dari palet global, jadi
  /// setiap pembaca AppState harus dibangun ulang saat tema berganti —
  /// termasuk saat mode Sistem mengikuti tema HP.
  static AppState of(BuildContext c) {
    Theme.of(c);
    return c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  }
}

/// Ukuran font dasar layar, mengikuti pengaturan "Ukuran huruf".
double fs(BuildContext c) =>
    (kBaseFontSize * AppScope.of(c).scale).roundToDouble();

/// Area yang bisa diketuk tanpa efek ripple.
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

/// Pilihan segmen (tab kecil, ukuran huruf, lebar kertas, rangkap,
/// kategori) — SegmentedButton Material 3 bergaya AmePOS: terpilih diberi
/// tint hijau, bukan dibalik hitam.
///
/// [berbingkai] false = segmen mengisi satu baris penuh di bawah header, jadi
/// diberi jarak dari tepi layar.
class Segmen extends StatelessWidget {
  final List<String> labels;
  final int terpilih;
  final ValueChanged<int> onPilih;
  final double fontSize;
  final bool berbingkai;

  const Segmen({
    super.key,
    required this.labels,
    required this.terpilih,
    required this.onPilih,
    required this.fontSize,
    this.berbingkai = true,
    // Tidak dipakai lagi; tetap diterima supaya pemanggil lama tidak pecah.
    EdgeInsets? padding,
    TextAlign? align,
  });

  @override
  Widget build(BuildContext c) {
    final tombol = SegmentedButton<int>(
      segments: [
        for (var i = 0; i < labels.length; i++)
          ButtonSegment(
            value: i,
            label: Text(labels[i], maxLines: 1, softWrap: false),
          ),
      ],
      selected: {terpilih},
      onSelectionChanged: (v) => onPilih(v.first),
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Archivo',
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
    if (berbingkai) return tombol;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: tombol,
    );
  }
}

/// Label kecil di atas sebuah isian.
class LabelMikro extends StatelessWidget {
  final String teks;
  final Color? color;
  const LabelMikro(this.teks, {super.key, this.color});

  @override
  Widget build(BuildContext c) {
    final f = fs(c);
    return Text(teks, style: micro(f, color: color ?? neutral600));
  }
}

/// Judul bagian bergaya AmePOS: huruf kapital kecil berwarna hijau.
class JudulBagian extends StatelessWidget {
  final String teks;
  const JudulBagian(this.teks, {super.key});

  @override
  Widget build(BuildContext c) {
    final f = fs(c);
    return Text(
      teks.toUpperCase(),
      style: TextStyle(
        fontSize: f * .74,
        fontWeight: FontWeight.w700,
        letterSpacing: f * .74 * .07,
        color: accent700,
      ),
    );
  }
}

/// Chip status: tint 14% dari warnanya, teks berwarna sama — seperti
/// `OnlineStatusChip` AmePOS.
class ChipNada extends StatelessWidget {
  final String label;
  final Color warna;
  final Color? latar;
  final Widget? depan;
  const ChipNada(
    this.label, {
    super.key,
    required this.warna,
    this.latar,
    this.depan,
  });

  @override
  Widget build(BuildContext c) {
    final f = fs(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: latar ?? warna.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(Sudut.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (depan != null) ...[depan!, const SizedBox(width: 6)],
          Text(
            label,
            style: TextStyle(
              fontSize: f * .74,
              fontWeight: FontWeight.w600,
              color: warna,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol penuh lebar (Mulai sesi, Simpan, Tes cetak): hijau berisi untuk
/// aksi utama, bergaris untuk aksi [sekunder] — FilledButton/OutlinedButton
/// AmePOS.
class TombolAksi extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool sekunder;
  const TombolAksi(
    this.label, {
    super.key,
    required this.onTap,
    this.sekunder = false,
  });

  @override
  Widget build(BuildContext c) {
    final f = fs(c);
    final gaya = TextStyle(
      fontFamily: 'Archivo',
      fontSize: f * .92,
      fontWeight: FontWeight.w600,
    );
    final isi = Text(label, textAlign: TextAlign.center);
    return SizedBox(
      width: double.infinity,
      child: sekunder
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(textStyle: gaya),
              child: isi,
            )
          : FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(textStyle: gaya),
              child: isi,
            ),
    );
  }
}

/// Kolom teks. Gaya datang dari inputDecorationTheme.
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
      style: TextStyle(
        fontSize: fontSize ?? f * .95,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      decoration: InputDecoration(hintText: hint),
    );
  }
}

/// Lembar bawah: sudut atas membulat, judul + tombol tutup, isi bisa
/// digulir, footer aksi. Seperti bottom sheet AmePOS online.
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
    final latar = Theme.of(c).dialogTheme.backgroundColor ?? surface;
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
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Sudut.xl),
              ),
              child: ColoredBox(
                color: latar,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: neutral500.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              judul,
                              style: heading(f * 1.1, height: 1.2),
                            ),
                          ),
                          IconButton(
                            onPressed: onTutup,
                            tooltip: 'Tutup',
                            icon: Icon(Icons.close, color: neutral600),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Container(color: isiWarna ?? latar, child: isi),
                    ),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer dua tombol: batal (garis) + aksi utama (hijau).
class FooterDua extends StatelessWidget {
  final String kiri;
  final String kanan;
  final VoidCallback onKiri;
  final VoidCallback onKanan;

  /// Aksi kanan merusak (hapus): tombolnya merah, bukan hijau.
  final bool bahaya;
  const FooterDua({
    super.key,
    required this.kiri,
    required this.kanan,
    required this.onKiri,
    required this.onKanan,
    this.bahaya = false,
  });

  @override
  Widget build(BuildContext c) {
    final f = fs(c);
    final gaya = TextStyle(
      fontFamily: 'Archivo',
      fontSize: f * .92,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onKiri,
              style: OutlinedButton.styleFrom(textStyle: gaya),
              child: Text(kiri),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: onKanan,
              style: FilledButton.styleFrom(
                textStyle: gaya,
                backgroundColor: bahaya ? Theme.of(c).colorScheme.error : null,
                foregroundColor: bahaya
                    ? Theme.of(c).colorScheme.onError
                    : null,
              ),
              child: Text(kanan),
            ),
          ),
        ],
      ),
    );
  }
}

/// Papan angka 1-9 / C / 0 / aksi terakhir — tombol berisi bersudut 8
/// dengan jarak 3, seperti `OnlineNumKeypad` AmePOS.
class Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onClear;
  final VoidCallback onAkhir;

  /// '⌫' hapus satu digit, '✓' konfirmasi, '✕' batalkan barang.
  final String labelAkhir;
  final bool akhirMerah;
  final int kolom;

  const Numpad({
    super.key,
    required this.onDigit,
    required this.onClear,
    required this.onAkhir,
    required this.labelAkhir,
    this.akhirMerah = true,
    this.kolom = 4,
    // Tidak dipakai lagi; tetap diterima supaya pemanggil lama tidak pecah.
    double? tinggiPad,
  });

  @override
  Widget build(BuildContext c) {
    final f = fs(c);
    final ikonAkhir = switch (labelAkhir) {
      '⌫' => Icons.backspace_outlined,
      '✕' => Icons.close,
      _ => Icons.check,
    };
    final batal = labelAkhir == '✕';
    final tombol = <Widget>[
      for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
        _Kunci(
          onTap: () => onDigit(d),
          latar: tombolBg,
          child: _angka(f, d, tombolFg),
        ),
      _Kunci(
        onTap: onClear,
        latar: neutral200,
        semantik: 'Kosongkan',
        child: _angka(f, 'C', ink),
      ),
      _Kunci(
        onTap: () => onDigit('0'),
        latar: tombolBg,
        child: _angka(f, '0', tombolFg),
      ),
      _Kunci(
        onTap: onAkhir,
        latar: !akhirMerah ? neutral200 : (batal ? bahaya : accent),
        semantik: switch (labelAkhir) {
          '⌫' => 'Hapus satu angka',
          '✕' => 'Batalkan barang',
          _ => 'Simpan jumlah',
        },
        child: Icon(
          ikonAkhir,
          size: f * 1.5,
          color: !akhirMerah
              ? ink
              : (batal ? Theme.of(c).colorScheme.onError : onAccent),
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.all(5),
      child: GridView.count(
        crossAxisCount: kolom,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1 / .5,
        children: tombol,
      ),
    );
  }

  Widget _angka(double f, String d, Color warna) => Text(
    d,
    style: TextStyle(
      fontSize: f * 1.4,
      fontWeight: FontWeight.w600,
      color: warna,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class _Kunci extends StatelessWidget {
  final VoidCallback onTap;
  final Color latar;
  final Widget child;
  final String? semantik;
  const _Kunci({
    required this.onTap,
    required this.latar,
    required this.child,
    this.semantik,
  });

  @override
  Widget build(BuildContext c) {
    final r = BorderRadius.circular(Sudut.sm);
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Semantics(
        button: true,
        label: semantik,
        child: Material(
          color: latar,
          borderRadius: r,
          child: InkWell(
            onTap: onTap,
            borderRadius: r,
            // Ketukan beruntun di numpad: highlight cepat tanpa ripple yang
            // tertinggal di tombol sebelumnya.
            splashFactory: NoSplash.splashFactory,
            highlightColor: accent.withValues(alpha: .18),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
