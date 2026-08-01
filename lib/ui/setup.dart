import 'package:flutter/material.dart';

import '../brand.dart';
import '../theme.dart';
import 'widgets.dart';

class SetupGate extends StatefulWidget {
  const SetupGate({super.key});
  @override
  State<SetupGate> createState() => _SetupGateState();
}

class _SetupGateState extends State<SetupGate> {
  final c = TextEditingController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = fs(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    color: neutral100,
                    border: Border.all(color: ink, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kAppNameUpper,
                        style: heading(f * 1.2)
                            .copyWith(letterSpacing: -f * .01),
                      ),
                      const SizedBox(height: 6),
                      WatermarkBy(fontSize: f * .72, align: TextAlign.left),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'SIAPA YANG\nBERTUGAS?',
                  style: heading(f * 1.9, height: 1.05)
                      .copyWith(letterSpacing: -f * 1.9 * .02),
                ),
                const SizedBox(height: 14),
                Text(
                  'Nama ini dicetak di tiket sebagai petugas input. '
                  'Tanpa kata sandi — cukup sekali di awal sesi.',
                  style: TextStyle(
                    fontSize: f * .82,
                    color: neutral700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Isian(
                  controller: c,
                  hint: 'Nama petugas',
                  fontSize: f,
                  cap: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                TombolAksi('Mulai sesi', onTap: () => s.mulaiSesi(c.text)),
                const SizedBox(height: 40),
                const WatermarkBy(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
