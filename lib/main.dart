import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';
import 'state.dart';
import 'theme.dart';
import 'ui/shell.dart';
import 'ui/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Rancangan berbentuk potret 390×844; lanskap tidak pernah dirancang.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState();
  runApp(TiketAlamatApp(state: state));
  // Mode tema yang dimuat dari disk memicu MaterialApp membangun ulang, dan
  // palet ikut diterapkan di `builder` — tidak perlu disetel di sini.
  state.init();
}

/// Batasi lebar isi ke ukuran ponsel dan taruh di tengah.
///
/// Rancangannya 390×844. Di jendela desktop yang bisa selebar apa pun, numpad
/// dan nota ikut melar sampai tidak proporsional. Diletakkan di `builder`
/// MaterialApp supaya dialog dan sheet — yang muncul di dalam Navigator — ikut
/// terbatas, bukan hanya isi halaman.
///
/// Di ponsel batas ini tidak pernah tercapai, jadi tampilannya tidak berubah.
class _BingkaiPonsel extends StatelessWidget {
  final Widget child;
  const _BingkaiPonsel({required this.child});

  static const _lebarMaksimum = 430.0;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width <= _lebarMaksimum) return child;
    return ColoredBox(
      // Latar di kiri-kanan dibuat lebih gelap/terang dari bg supaya panelnya
      // terbaca sebagai satu bidang, bukan tampilan yang gagal melebar.
      color: neutral200,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _lebarMaksimum),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.symmetric(vertical: BorderSide(color: divider)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class TiketAlamatApp extends StatefulWidget {
  final AppState state;
  const TiketAlamatApp({super.key, required this.state});

  @override
  State<TiketAlamatApp> createState() => _TiketAlamatAppState();
}

class _TiketAlamatAppState extends State<TiketAlamatApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Socket SPP sering mati saat app di-background/tutup, tapi cache lokal
    // masih bilang "terhubung". Paksa reconnect di cetak berikutnya.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      widget.state.printer.tandaiPutus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // MaterialApp hanya mendengarkan mode tema. Sisa AppState sampai ke widget
    // lewat AppScope, jadi ketukan numpad atau toast tidak lagi membangun
    // ulang MaterialApp beserta temanya.
    return AppScope(
      state: widget.state,
      child: ValueListenableBuilder(
        valueListenable: widget.state.temaMode,
        builder: (_, mode, _) {
          return MaterialApp(
            title: kAppName,
            debugShowCheckedModeBanner: false,
            theme: temaTerangApp,
            darkTheme: temaGelapApp,
            themeMode: mode,
            // Tanpa animasi: palet global diambil dari tema di bawah, dan
            // tema yang sedang dianimasikan masih membawa palet lama di
            // frame-frame pertamanya.
            themeAnimationDuration: Duration.zero,
            builder: (context, child) {
              // Tema yang benar-benar dipakai — termasuk mode Sistem, yang
              // ikut berubah saat tema HP diganti. Setiap widget yang membaca
              // AppScope juga bergantung pada Theme (lihat AppScope.of), jadi
              // semuanya dibangun ulang dengan palet baru di frame yang sama.
              final p = Theme.of(context).extension<AppPalette>()!;
              applyPalette(p);
              final dark = p.brightness == Brightness.dark;
              // Nama SystemUiOverlayStyle.light/.dark menyesatkan: `.dark`
              // menyetel ikon navigasi jadi PUTIH. Kecerahan ikon karena itu
              // ditulis eksplisit, tidak mengandalkan preset.
              final overlay = SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: dark
                    ? Brightness.light
                    : Brightness.dark,
                statusBarBrightness: dark ? Brightness.dark : Brightness.light,
                // Sewarna NavigationBar di atasnya, supaya keduanya terbaca
                // sebagai satu bidang.
                systemNavigationBarColor: p.surface,
                systemNavigationBarIconBrightness: dark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarDividerColor: p.surface,
              );
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlay,
                child: _BingkaiPonsel(child: child ?? const SizedBox.shrink()),
              );
            },
            home: const Shell(),
          );
        },
      ),
    );
  }
}
