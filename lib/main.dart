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
  // darkMode yang dimuat dari disk memicu MaterialApp membangun ulang, dan
  // palet ikut diterapkan di `builder` — tidak perlu disetel di sini.
  state.init();
}

/// Warna bilah navigasi Android — sengaja beda tipis dari latar aplikasi
/// supaya batas bawah layar tetap terbaca.
const _navTerang = Color(0xFFE4E2E2);
const _navGelap = Color(0xFF141414);

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
              border: Border.symmetric(
                vertical: BorderSide(color: divider),
              ),
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
    // MaterialApp hanya mendengarkan darkMode. Sisa AppState sampai ke widget
    // lewat AppScope, jadi ketukan numpad atau toast tidak lagi membangun
    // ulang MaterialApp beserta temanya.
    return AppScope(
      state: widget.state,
      child: ValueListenableBuilder(
        valueListenable: widget.state.temaGelap,
        builder: (_, dark, _) {
          return MaterialApp(
            title: kAppName,
            debugShowCheckedModeBanner: false,
            theme: temaTerangApp,
            darkTheme: temaGelapApp,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) {
              // Palet global sudah diganti oleh setter `AppState.darkMode`.
              final overlay = dark
                  // Nama SystemUiOverlayStyle.light/.dark menyesatkan: `.dark`
                  // menyetel ikon navigasi jadi PUTIH. Dipakai bersama warna
                  // navbar terang, tombol navigasi Android jadi tak terlihat.
                  // Kecerahan ikon karena itu ditulis eksplisit, tidak
                  // mengandalkan preset.
                  ? const SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.light,
                      statusBarBrightness: Brightness.dark,
                      systemNavigationBarColor: _navGelap,
                      systemNavigationBarIconBrightness: Brightness.light,
                      systemNavigationBarDividerColor: _navGelap,
                    )
                  : const SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.dark,
                      statusBarBrightness: Brightness.light,
                      // Sedikit lebih gelap dari latar aplikasi supaya navbar
                      // punya batas yang terlihat, bukan menyatu jadi bidang
                      // putih tanpa ujung.
                      systemNavigationBarColor: _navTerang,
                      systemNavigationBarIconBrightness: Brightness.dark,
                      systemNavigationBarDividerColor: _navTerang,
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
