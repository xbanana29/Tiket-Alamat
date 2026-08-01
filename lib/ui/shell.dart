import 'package:flutter/material.dart';


import '../brand.dart';
import '../theme.dart';
import 'daftar.dart';
import 'pengaturan.dart';
import 'pesanan.dart';
import 'setup.dart';
import 'widgets.dart';

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
                  Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: ink, width: 2)),
                    ),
                    child: Segmen(
                      labels: const ['Pesanan', 'Daftar', 'Pengaturan'],
                      terpilih: ['pesanan', 'daftar', 'atur'].indexOf(s.tab),
                      onPilih: (i) => s.ubah(
                        () => s.tab = ['pesanan', 'daftar', 'atur'][i],
                      ),
                      fontSize: f * .74,
                      berbingkai: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
              ],
            ),
            if (s.armed != null) const KeypadSheet(),
            if (s.printOpen) const PratinjauCetak(),
            if (s.toast.isNotEmpty)
              Positioned(
                left: 14,
                right: 14,
                bottom: kb ? 14 : 70,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  color: ink,
                  child: Text(
                    s.toast,
                    style: TextStyle(
                      color: toastFg,
                      fontSize: f * .8,
                      fontWeight: FontWeight.w600,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: ink, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kAppNameUpper,
                  style: heading(f * 1.15).copyWith(letterSpacing: -f * .01),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: neutral100,
                  border: Border.all(color: divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.online ? hijau : accent,
                        shape: BoxShape.rectangle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.online ? 'DARING' : 'LURING',
                      style: TextStyle(
                        fontSize: f * .68,
                        letterSpacing: f * .68 * .06,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (s.queue > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  color: accent,
                  child: Text(
                    '${s.queue} ANTRI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: f * .68,
                      fontWeight: FontWeight.w700,
                      letterSpacing: f * .68 * .04,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Tap(
            onTap: () => s.ubah(() => s.tab = 'atur'),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'PETUGAS · ',
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
                    text: ' · UBAH',
                    style: TextStyle(color: neutral600),
                  ),
                ],
              ),
              style: micro(f, ls: .06),
            ),
          ),
        ],
      ),
    );
  }
}
