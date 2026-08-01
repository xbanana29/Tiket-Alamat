import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Palet neo-brutalist (radius 0, border tegas). Light & dark.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color ink;
  final Color bg;
  final Color surface;
  final Color accent;
  final Color accent200;
  final Color accent700;
  final Color accent800;
  final Color neutral100;
  final Color neutral200;
  final Color neutral500;
  final Color neutral600;
  final Color neutral700;
  final Color neutral800;
  final Color hijau;
  final Color fieldFill;
  final Color sheetScrim;
  final Color toastFg;
  /// Kertas struk pratinjau — selalu "kertas putih" di light & dark.
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
    required this.neutral100,
    required this.neutral200,
    required this.neutral500,
    required this.neutral600,
    required this.neutral700,
    required this.neutral800,
    required this.hijau,
    required this.fieldFill,
    required this.sheetScrim,
    required this.toastFg,
    required this.paper,
    required this.paperInk,
    required this.paperMuted,
    required this.brightness,
  });

  Color get divider => ink.withValues(alpha: brightness == Brightness.dark ? .35 : .4);

  /// Badge status antrian — teks tetap terbaca di kedua mode.
  Color get badgeAntriBg =>
      brightness == Brightness.dark ? const Color(0xFF3D2A08) : accent200;
  Color get badgeAntriFg =>
      brightness == Brightness.dark ? const Color(0xFFFFA31A) : accent800;
  Color get badgeOkBg => neutral200;
  Color get badgeOkFg => ink;

  static const light = AppPalette(
    ink: Color(0xFF201E1D),
    bg: Color(0xFFF3F2F2),
    surface: Color(0xFFEAE9E9),
    accent: Color(0xFFEC3013),
    accent200: Color(0xFFFFE0D9),
    accent700: Color(0xFFAE1800),
    accent800: Color(0xFF7C1405),
    neutral100: Color(0xFFF8F4F4),
    neutral200: Color(0xFFE7E3E3),
    neutral500: Color(0xFF8A8585),
    neutral600: Color(0xFF6E6A6A),
    neutral700: Color(0xFF4F4C4C),
    neutral800: Color(0xFF3B3939),
    hijau: Color(0xFF2F7D32),
    fieldFill: Color(0xFFFFFFFF),
    sheetScrim: Color(0x99201E1D),
    toastFg: Color(0xFFF3F2F2),
    paper: Color(0xFFFFFFFF),
    paperInk: Color(0xFF201E1D),
    paperMuted: Color(0xFF6E6A6A),
    brightness: Brightness.light,
  );

  /// Dark mode — palet brand:
  /// #FFA31A aksen, #808080 abu, #292929 surface, #1B1B1B bg, #FFFFFF teks.
  static const dark = AppPalette(
    ink: Color(0xFFFFFFFF), // #ffffff
    bg: Color(0xFF1B1B1B), // #1b1b1b
    surface: Color(0xFF292929), // #292929
    accent: Color(0xFFFFA31A), // #ffa31a
    accent200: Color(0xFF3D2A08), // aksen redup di atas bg gelap
    accent700: Color(0xFFFFB84D), // aksen lebih terang (hover/link)
    accent800: Color(0xFFFFA31A), // #ffa31a
    neutral100: Color(0xFF292929), // #292929
    neutral200: Color(0xFF292929), // #292929
    neutral500: Color(0xFF808080), // #808080
    neutral600: Color(0xFF808080), // #808080
    neutral700: Color(0xFFB0B0B0), // abu lebih terang dari #808080
    neutral800: Color(0xFFE0E0E0), // hampir putih
    hijau: Color(0xFFFFA31A), // status daring pakai aksen brand
    fieldFill: Color(0xFF292929), // #292929
    sheetScrim: Color(0xCC1B1B1B),
    toastFg: Color(0xFF1B1B1B), // teks di toast (bg putih/ink)
    paper: Color(0xFFFFFFFF),
    paperInk: Color(0xFF1B1B1B),
    paperMuted: Color(0xFF808080),
    brightness: Brightness.dark,
  );

  @override
  AppPalette copyWith({
    Color? ink,
    Color? bg,
    Color? surface,
    Color? accent,
    Color? accent200,
    Color? accent700,
    Color? accent800,
    Color? neutral100,
    Color? neutral200,
    Color? neutral500,
    Color? neutral600,
    Color? neutral700,
    Color? neutral800,
    Color? hijau,
    Color? fieldFill,
    Color? sheetScrim,
    Color? toastFg,
    Color? paper,
    Color? paperInk,
    Color? paperMuted,
    Brightness? brightness,
  }) =>
      AppPalette(
        ink: ink ?? this.ink,
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        accent: accent ?? this.accent,
        accent200: accent200 ?? this.accent200,
        accent700: accent700 ?? this.accent700,
        accent800: accent800 ?? this.accent800,
        neutral100: neutral100 ?? this.neutral100,
        neutral200: neutral200 ?? this.neutral200,
        neutral500: neutral500 ?? this.neutral500,
        neutral600: neutral600 ?? this.neutral600,
        neutral700: neutral700 ?? this.neutral700,
        neutral800: neutral800 ?? this.neutral800,
        hijau: hijau ?? this.hijau,
        fieldFill: fieldFill ?? this.fieldFill,
        sheetScrim: sheetScrim ?? this.sheetScrim,
        toastFg: toastFg ?? this.toastFg,
        paper: paper ?? this.paper,
        paperInk: paperInk ?? this.paperInk,
        paperMuted: paperMuted ?? this.paperMuted,
        brightness: brightness ?? this.brightness,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < 0.5 ? this : other;
  }
}

/// Palet aktif — di-set MaterialApp.builder. UI pakai getter di bawah.
AppPalette _p = AppPalette.light;

void applyPalette(AppPalette p) => _p = p;

// Token global (kompatibel file lama; ikut dark/light).
Color get ink => _p.ink;
Color get bg => _p.bg;
Color get surface => _p.surface;
Color get accent => _p.accent;
Color get accent200 => _p.accent200;
Color get accent700 => _p.accent700;
Color get accent800 => _p.accent800;
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
Color get toastFg => _p.toastFg;
Color get paper => _p.paper;
Color get paperInk => _p.paperInk;
Color get paperMuted => _p.paperMuted;
Color get badgeAntriBg => _p.badgeAntriBg;
Color get badgeAntriFg => _p.badgeAntriFg;
Color get badgeOkBg => _p.badgeOkBg;
Color get badgeOkFg => _p.badgeOkFg;
bool get isDarkPalette => _p.brightness == Brightness.dark;

const kBaseFontSize = 15.0;
const kFontScales = [0.82, 1.0, 1.14, 1.3];

const mono = 'monospace';

ThemeData buildTheme({required bool dark}) {
  final p = dark ? AppPalette.dark : AppPalette.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    fontFamily: 'Archivo',
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: Colors.white,
      secondary: p.neutral700,
      onSecondary: p.bg,
      error: p.accent700,
      onError: Colors.white,
      surface: p.bg,
      onSurface: p.ink,
    ),
    extensions: [p],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    splashFactory: NoSplash.splashFactory,
    dividerColor: p.divider,
    dialogTheme: DialogThemeData(
      backgroundColor: p.bg,
      titleTextStyle: TextStyle(
        color: p.ink,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        fontFamily: 'Archivo',
      ),
      contentTextStyle: TextStyle(color: p.ink, fontFamily: 'Archivo'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    listTileTheme: ListTileThemeData(
      textColor: p.ink,
      iconColor: p.ink,
      subtitleTextStyle: TextStyle(color: p.neutral600, fontFamily: 'Archivo'),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: p.fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: p.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: p.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: p.ink, width: 2),
      ),
      hintStyle: TextStyle(color: p.neutral500, fontWeight: FontWeight.w400),
    ),
  );
}

TextStyle micro(double fs, {Color? color, double ls = .08}) => TextStyle(
  fontSize: fs * .68,
  letterSpacing: fs * .68 * ls,
  color: color ?? neutral600,
  fontWeight: FontWeight.w400,
);

TextStyle heading(double size, {Color? color, double height = 1.15}) =>
    TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color ?? ink,
      height: height,
    );
