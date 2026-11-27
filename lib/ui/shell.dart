import 'package:flutter/material.dart';

import '../brand.dart';
import '../theme.dart';
import 'daftar.dart';
import 'pengaturan.dart';
import 'pesanan.dart';
import 'setup.dart';
import 'widgets.dart';

const _tabs = ['pesanan', 'daftar', 'atur'];

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);

    if (!s.siapCetak) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (s.petugas.isEmpty) return const SetupGate();

    // Keyboard buka → sembunyikan tab bawah supaya Column tidak overflow.
    final kb = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        // NavigationBar mengurus inset bawahnya sendiri, supaya latarnya
        // menerus sampai ke bilah navigasi Android.
        bottom: kb,
        child: Stack(
          children: [
            Column(
              children: [
                _Header(f: f),
                Expanded(
                  child: switch (s.tab) {
                    'daftar' => const TabDaftar(),
                    'atur' => const TabPengaturan(),
                    _ => const TabPesanan(),
                  },
                ),
                if (!kb)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: divider)),
                    ),
                    child: NavigationBar(
                      selectedIndex: _tabs.indexOf(s.tab).clamp(0, 2),
                      onDestinationSelected: (i) => s.bukaTab(_tabs[i]),
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long),
                          label: 'Pesanan',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.view_list_outlined),
                          selectedIcon: Icon(Icons.view_list),
                          label: 'Daftar',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings),
                          label: 'Pengaturan',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (s.armed != null) const KeypadSheet(),
            if (s.printOpen) const PratinjauCetak(),
            // Toast di atas, bukan di bawah: bagian bawah layar penuh tombol
            // yang sering ditekan berturut-turut (numpad, Cetak tiket, tab),
            // dan toast di sana menutupi tepat tombol berikutnya.
            // Didengarkan sendiri: muncul/hilangnya toast hanya membangun
            // ulang kotak ini.
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: ValueListenableBuilder(
                valueListenable: s.toastNotifier,
                builder: (_, toast, _) => toast.isEmpty
                    ? const SizedBox.shrink()
                    : Material(
                        color: toastBg,
                        elevation: 6,
                        shadowColor: Colors.black.withValues(alpha: .3),
                        borderRadius: BorderRadius.circular(Sudut.md),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            toast,
                            style: TextStyle(
                              color: toastFg,
                              fontSize: f * .82,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final double f;
  const _Header({required this.f});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final label = s.sedangSync ? 'Sync…' : (s.online ? 'Sync' : 'Luring');
    final nada = s.online || s.sedangSync ? accent700 : waspada;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kAppName, style: heading(f * 1.2)),
                const SizedBox(height: 2),
                // Ketuk nama petugas untuk menggantinya di Pengaturan.
                Tap(
                  onTap: () => s.ubah(() => s.tab = 'atur'),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Petugas · ',
                          style: TextStyle(color: neutral600),
                        ),
                        TextSpan(
                          text: s.petugas.toUpperCase(),
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: ' · Ubah',
                          style: TextStyle(color: accent700),
                        ),
                      ],
                    ),
                    style: TextStyle(fontSize: f * .76),
                  ),
                ),
              ],
            ),
          ),
          // Chip status sekaligus tombol sync — bisa dijangkau dari tab mana
          // pun tanpa menambah elemen baru di header.
          Semantics(
            button: true,
            label: 'Sinkronkan sekarang',
            child: Tap(
              onTap: s.syncSekarang,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  child: ChipNada(
                    label,
                    warna: nada,
                    depan: s.sedangSync
                        ? SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: nada,
                            ),
                          )
                        : Icon(
                            s.online
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off,
                            size: f * .9,
                            color: nada,
                          ),
                  ),
                ),
              ),
            ),
          ),
          if (s.queue > 0) ...[
            const SizedBox(width: 6),
            ChipNada('${s.queue} antre', warna: badgeAntriFg),
          ],
        ],
      ),
    );
  }
}
