import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiket_gudang/models.dart';
import 'package:tiket_gudang/printer.dart';

/// Catatan kaki struk pernah tercetak 3 baris: dikirim sebagai dua panggilan
/// teks, dan yang pertama 35 karakter — padahal kertas 58 mm hanya muat 32 pada
/// font A, jadi melipat lagi.
///
/// Pelipatan itu terjadi di dalam printer dan tidak terlihat di byte, jadi yang
/// diperiksa di sini: catatan kaki dikirim sebagai SATU baris, memakai font B,
/// dan panjangnya masih di bawah kapasitas font B.
void main() {
  // CapabilityProfile membaca aset paket, jadi binding harus siap dulu.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// ESC M 1 — pilih font B.
  const pilihFontB = [0x1B, 0x4D, 0x01];

  /// Kapasitas font B (lihat generator esc_pos_utils_plus).
  const muat58 = 42;
  const muat80 = 64;

  final tiket = Tiket(
    id: '1',
    pelanggan: 'TOKO UJI',
    waktu: DateTime(2026, 8, 2, 10, 30),
    petugas: 'Rudi',
    mode: 'sak',
    items: const [Item('CAKRA KEMBAR', 10)],
  );

  Future<List<int>> bytes(int lebarMm) =>
      Printer().bangunStruk(tiket: tiket, lebarMm: lebarMm, copies: 1);

  /// Baris teks yang tercetak, tanpa byte perintah.
  List<String> baris(List<int> b) => const Utf8Decoder(allowMalformed: true)
      .convert(b)
      .replaceAll(RegExp(r'[\x00-\x09\x0B-\x1F\x7F]'), '')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  List<String> kaki(List<String> l) => l
      .where((x) =>
          x.toLowerCase().contains('tanda terima') ||
          x.toLowerCase().contains('paku') ||
          x.toLowerCase().contains('barang keluar'))
      .toList();

  test('catatan kaki dikirim sebagai satu baris, bukan dipecah sendiri', () async {
    for (final mm in [58, 80]) {
      final k = kaki(baris(await bytes(mm)));
      expect(k.length, 1, reason: '$mm mm terpecah jadi ${k.length} baris: $k');
    }
  });

  test('catatan kaki memakai font B', () async {
    // Tanpa font B, 57 karakter tidak akan pernah muat 2 baris di 58 mm.
    final b = await bytes(58);
    final ada = List.generate(b.length - 2, (i) => b.sublist(i, i + 3))
        .any((w) => w[0] == pilihFontB[0] && w[1] == pilihFontB[1] && w[2] == pilihFontB[2]);
    expect(ada, isTrue, reason: 'perintah pilih font B tidak ditemukan');
  });

  test('panjangnya muat 2 baris di 58 mm dan 1 baris di 80 mm', () async {
    final teks = kaki(baris(await bytes(58))).single;
    expect(teks.length, lessThanOrEqualTo(muat58 * 2));
    expect(teks.length, lessThanOrEqualTo(muat80));
  });

  test('isi catatan kaki tetap utuh', () async {
    final teks = kaki(baris(await bytes(80))).single;
    expect(teks, contains('Tanda terima gudang'));
    expect(teks, contains('tusuk di paku'));
    expect(teks, contains('barang keluar'));
  });
}
