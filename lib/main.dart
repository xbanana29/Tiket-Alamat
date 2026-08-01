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
  // Muat preferensi (termasuk darkMode) sebelum frame pertama bila memungkinkan.
  runApp(TiketAlamatApp(state: state));
  state.init().then((_) {
    // Setelah load, pastikan palet ikut darkMode tersimpan.
    applyPalette(state.darkMode ? AppPalette.dark : AppPalette.light);
  });
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
    // Dengarkan AppState (termasuk darkMode) lewat ListenableBuilder.
    return AppScope(
      state: widget.state,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (_, _) {
          final dark = widget.state.darkMode;
          return MaterialApp(
            title: kAppName,
            debugShowCheckedModeBanner: false,
            theme: buildTheme(dark: false),
            darkTheme: buildTheme(dark: true),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) {
              // Sinkronkan token warna global ke theme aktif.
              applyPalette(
                Theme.of(context).extension<AppPalette>() ??
                    (dark ? AppPalette.dark : AppPalette.light),
              );
              final overlay = dark
                  ? SystemUiOverlayStyle.light.copyWith(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: AppPalette.dark.bg,
                    )
                  : SystemUiOverlayStyle.dark.copyWith(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: AppPalette.light.bg,
                    );
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlay,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const Shell(),
          );
        },
      ),
    );
  }
}
