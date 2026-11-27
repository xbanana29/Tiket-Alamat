import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Tema mengikuti AmePOS varian online/HP (amepos/app/lib/online/theme/
// online_theme.dart): Material 3 dengan seed hijau, kartu dan tombol
// membulat, mode Sistem/Terang/Gelap. Nama token lama (ink, bg, accent, …)
// dipertahankan supaya pemanggil di seluruh UI ikut berganti tanpa diubah satu
// per satu.

/// Hijau brand AmePOS.
const kAksen = Color(0xFF00A86B);
const kAksenGelap = Color(0xFF2DD4A0);

/// Radius baku AmePOS online.
abstract final class Sudut {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
}

class AppPalette extends ThemeExtension<AppPalette> {
  /// Teks utama.
  final Color ink;

  /// Latar layar.
  final Color bg;

  /// Kartu dan panel di atas [bg].
  final Color surface;

  /// Hijau brand: tombol utama, status, seleksi.
  final Color accent;

  /// Latar elemen terpilih (tint hijau).
  final Color accent200;

  /// Teks aksi dan teks di atas [accent200].
  final Color accent700;
  final Color accent800;

  /// Teks/ikon di atas [accent].
  final Color onAccent;

  final Color neutral100;
  final Color neutral200;
  final Color neutral500;
  final Color neutral600;
  final Color neutral700;
  final Color neutral800;
  final Color hijau;
  final Color fieldFill;
  final Color sheetScrim;
  final Color toastBg;
  final Color toastFg;

  /// Tombol numpad (secondaryContainer di AmePOS).
  final Color tombolBg;
  final Color tombolFg;

  /// Garis dan bingkai tipis.
  final Color garis;

  /// Merah untuk aksi merusak dan galat.
  final Color bahaya;

  /// Kuning tua untuk peringatan (antrean, luring).
  final Color waspada;

  /// Kertas struk pratinjau — selalu "kertas putih" di terang & gelap.
  final Color paper;
  final Color paperInk;
  final Color paperMuted;
  final Brightness brightness;

  const AppPalette({
    required this.ink,
    required this.bg,
    required this.surface,
    required this.accent,
    required this.accent200,
    required this.accent700,
    required this.accent800,
    required this.onAccent,
    required this.neutral100,
    required this.neutral200,
    required this.neutral500,
    required this.neutral600,
    required this.neutral700,
    required this.neutral800,
    required this.hijau,
    required this.fieldFill,
    required this.sheetScrim,
    required this.toastBg,
    required this.toastFg,
    required this.tombolBg,
    required this.tombolFg,
    required this.garis,
    required this.bahaya,
    required this.waspada,
    required this.paper,
    required this.paperInk,
    required this.paperMuted,
    required this.brightness,
  });

  /// Diturunkan dari ColorScheme yang sama dengan ThemeData, jadi warna
  /// komponen Material dan widget buatan sendiri selalu sepakat.
  factory AppPalette.dari(ColorScheme s, {required bool gelap}) {
    final aksen = gelap ? kAksenGelap : kAksen;
    Color atas(Color c, double a) =>
        Color.alphaBlend(c.withValues(alpha: a), s.surface);
    final waspada = gelap ? const Color(0xFFF5B544) : const Color(0xFFB45309);
    return AppPalette(
      ink: s.onSurface,
      bg: s.surface,
      surface: gelap ? atas(s.surfaceContainerHighest, .45) : Colors.white,
      accent: aksen,
      accent200: atas(aksen, gelap ? .28 : .14),
      accent700: gelap ? aksen : const Color(0xFF04593B),
      accent800: gelap ? s.onSurface : const Color(0xFF04593B),
      onAccent: gelap ? const Color(0xFF052E1F) : Colors.white,
      neutral100: s.surfaceContainerLow,
      neutral200: s.surfaceContainerHigh,
      neutral500: s.outline,
      neutral600: s.onSurfaceVariant,
      neutral700: s.onSurfaceVariant,
      neutral800: s.onSurface,
      hijau: aksen,
      fieldFill: atas(s.surfaceContainerHighest, gelap ? .5 : .35),
      sheetScrim: s.scrim.withValues(alpha: gelap ? .55 : .32),
      toastBg: s.inverseSurface,
      toastFg: s.onInverseSurface,
      tombolBg: s.secondaryContainer,
      tombolFg: s.onSecondaryContainer,
      garis: atas(s.outlineVariant, gelap ? .35 : .7),
      bahaya: s.error,
      waspada: waspada,
      paper: Colors.white,
      paperInk: const Color(0xFF14302A),
      paperMuted: const Color(0xFF6B7C76),
      brightness: gelap ? Brightness.dark : Brightness.light,
    );
  }

  Color get divider => garis;

  /// Chip status: tint 14% dari warna nadanya, teks berwarna nadanya —
  /// sama dengan `OnlineStatusChip` AmePOS.
  Color get badgeAntriBg => waspada.withValues(alpha: .14);
  Color get badgeAntriFg => waspada;
  Color get badgeOkBg => accent.withValues(alpha: .14);
  Color get badgeOkFg => accent700;
  Color get badgeTolakBg => bahaya.withValues(alpha: .14);
  Color get badgeTolakFg => bahaya;

  static final _skemaTerang = ColorScheme.fromSeed(
    seedColor: kAksen,
    surface: const Color(0xFFF7FAF8),
  );
  static final _skemaGelap = ColorScheme.fromSeed(
    seedColor: kAksenGelap,
    brightness: Brightness.dark,
    surface: const Color(0xFF111714),
  );

  static final light = AppPalette.dari(_skemaTerang, gelap: false);
  static final dark = AppPalette.dari(_skemaGelap, gelap: true);

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < 0.5 ? this : other;
  }
}

/// Palet aktif — di-set MaterialApp.builder dari tema yang sedang dipakai.
AppPalette _p = AppPalette.light;

void applyPalette(AppPalette p) => _p = p;

// Token global (ikut terang/gelap).
Color get ink => _p.ink;
Color get bg => _p.bg;
Color get surface => _p.surface;
Color get accent => _p.accent;
Color get accent200 => _p.accent200;
Color get accent700 => _p.accent700;
Color get accent800 => _p.accent800;
Color get onAccent => _p.onAccent;
Color get neutral100 => _p.neutral100;
Color get neutral200 => _p.neutral200;
Color get neutral500 => _p.neutral500;
Color get neutral600 => _p.neutral600;
Color get neutral700 => _p.neutral700;
Color get neutral800 => _p.neutral800;
Color get hijau => _p.hijau;
Color get divider => _p.divider;
Color get fieldFill => _p.fieldFill;
Color get sheetScrim => _p.sheetScrim;
Color get toastBg => _p.toastBg;
Color get toastFg => _p.toastFg;
Color get tombolBg => _p.tombolBg;
Color get tombolFg => _p.tombolFg;
Color get bahaya => _p.bahaya;
Color get waspada => _p.waspada;
Color get paper => _p.paper;
Color get paperInk => _p.paperInk;
Color get paperMuted => _p.paperMuted;
Color get badgeAntriBg => _p.badgeAntriBg;
Color get badgeAntriFg => _p.badgeAntriFg;
Color get badgeOkBg => _p.badgeOkBg;
Color get badgeOkFg => _p.badgeOkFg;
Color get badgeTolakBg => _p.badgeTolakBg;
Color get badgeTolakFg => _p.badgeTolakFg;
bool get isDarkPalette => _p.brightness == Brightness.dark;

const kBaseFontSize = 15.0;
const kFontScales = [0.82, 1.0, 1.14, 1.3];

const mono = 'monospace';

/// Tema dibangun sekali saja. Membangun ThemeData mahal, dan dulu ini terjadi
/// dua kali (terang + gelap) setiap AppState berubah.
final temaTerangApp = buildTheme(dark: false);
final temaGelapApp = buildTheme(dark: true);

ThemeData buildTheme({required bool dark}) {
  final p = dark ? AppPalette.dark : AppPalette.light;
  final s = dark ? AppPalette._skemaGelap : AppPalette._skemaTerang;
  final bulat = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Sudut.md),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: s,
    fontFamily: 'Archivo',
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    dividerColor: p.garis,
    dividerTheme: DividerThemeData(color: p.garis, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Archivo',
          fontWeight: FontWeight.w600,
        ),
        shape: bulat,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: BorderSide(color: p.garis),
        textStyle: const TextStyle(
          fontFamily: 'Archivo',
          fontWeight: FontWeight.w600,
        ),
        shape: bulat,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent700,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: 'Archivo',
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sudut.sm),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: p.accent200,
        selectedForegroundColor: p.accent800,
        foregroundColor: p.ink,
        side: BorderSide(color: p.garis),
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: 'Archivo',
          fontWeight: FontWeight.w600,
        ),
        shape: bulat,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.accent200,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (st) => TextStyle(
          fontFamily: 'Archivo',
          fontSize: 12,
          fontWeight: st.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: st.contains(WidgetState.selected) ? p.accent800 : p.neutral600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (st) => IconThemeData(
          color: st.contains(WidgetState.selected) ? p.accent800 : p.neutral600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sudut.lg),
        side: BorderSide(color: p.garis),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xFF17201C) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sudut.xl),
      ),
      titleTextStyle: TextStyle(
        color: p.ink,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        fontFamily: 'Archivo',
      ),
      contentTextStyle: TextStyle(color: p.ink, fontFamily: 'Archivo'),
    ),
    listTileTheme: ListTileThemeData(
      textColor: p.ink,
      iconColor: p.neutral600,
      subtitleTextStyle: TextStyle(color: p.neutral600, fontFamily: 'Archivo'),
      shape: bulat,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: p.fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Sudut.md),
        borderSide: BorderSide(color: p.garis),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Sudut.md),
        borderSide: BorderSide(color: p.garis),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Sudut.md),
        borderSide: BorderSide(color: p.accent, width: 2),
      ),
      hintStyle: TextStyle(color: p.neutral500, fontWeight: FontWeight.w400),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: .3),
      selectionHandleColor: p.accent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
  );
}

/// Label kecil di atas sebuah isian.
TextStyle micro(double fs, {Color? color, double ls = .02}) => TextStyle(
  fontSize: fs * .74,
  letterSpacing: fs * .74 * ls,
  color: color ?? neutral600,
  fontWeight: FontWeight.w500,
);

TextStyle heading(double size, {Color? color, double height = 1.15}) =>
    TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color ?? ink,
      height: height,
    );
