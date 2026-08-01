import 'package:flutter_test/flutter_test.dart';
import 'package:tiket_gudang/models.dart';
import 'package:tiket_gudang/printer.dart';
import 'package:tiket_gudang/state.dart';

// ponytail: satu file test untuk logika yang bisa salah diam-diam.
// Widget test dilewati — UI diverifikasi langsung di perangkat.

Tiket _tiket({
  String pelanggan = 'TOKO A',
  String mode = 'sak',
  List<Item> items = const [],
  int jerigen = 0,
  List<Revisi> revisi = const [],
}) => Tiket(
  id: '1',
  pelanggan: pelanggan,
  waktu: DateTime(2026, 8, 1, 9, 41),
  petugas: 'Andi',
  mode: mode,
  items: items,
  jerigen: jerigen,
  revisi: revisi,
);

void main() {
  group('numpad', () {
    test('buang nol depan, maksimal 2 digit, clamp 99', () {
      expect(tekanDigit('', '0'), '');
      expect(tekanDigit('', '7'), '7');
      expect(tekanDigit('0', '5'), '5');
      expect(tekanDigit('1', '2'), '12');
      expect(tekanDigit('12', '3'), '12'); // digit ke-3 diabaikan
      expect(tekanDigit('9', '9'), '99');
    });
  });

  group('upsertItem', () {
    test('menambah merek baru', () {
      final r = upsertItem([], 'GULAKU', 5);
      expect(r.single.nama, 'GULAKU');
      expect(r.single.qty, 5);
    });

    test('mengganti qty merek yang sudah ada, bukan menduplikasi', () {
      var r = upsertItem([], 'GULAKU', 5);
      r = upsertItem(r, 'GULAKU', 12);
      expect(r.length, 1);
      expect(r.single.qty, 12);
    });

    test('qty 0 diabaikan, qty >99 di-clamp', () {
      expect(upsertItem([], 'X', 0), isEmpty);
      expect(upsertItem([], 'X', 500).single.qty, 99);
    });
  });

  group('terapkanEdit', () {
    test('tidak ada perubahan → tidak mencatat revisi', () {
      final t = _tiket(items: [const Item('GULAKU', 5)]);
      final h = terapkanEdit(
        t,
        pelanggan: 'TOKO A',
        items: [const Item('GULAKU', 5)],
        jerigen: 0,
      );
      expect(h.revisi, isEmpty);
    });

    test('qty berubah → revisi menyimpan baris lama', () {
      final t = _tiket(items: [const Item('GULAKU', 5)]);
      final h = terapkanEdit(
        t,
        pelanggan: 'TOKO A',
        items: [const Item('GULAKU', 9)],
        jerigen: 0,
      );
      expect(h.revisi.single.baris, ['5 SAK GULAKU']);
      expect(h.barisTeks, ['9 SAK GULAKU']);
    });

    test('hanya nama berubah → revisi dicatat tanpa baris', () {
      final t = _tiket(items: [const Item('GULAKU', 5)]);
      final h = terapkanEdit(
        t,
        pelanggan: 'TOKO B',
        items: [const Item('GULAKU', 5)],
        jerigen: 0,
      );
      expect(h.revisi.single.pelanggan, 'TOKO A');
      expect(h.revisi.single.baris, isEmpty);
    });

    test('minyak: jerigen berubah', () {
      final t = _tiket(mode: 'minyak', jerigen: 6);
      final h = terapkanEdit(t, pelanggan: 'TOKO A', items: [], jerigen: 10);
      expect(h.revisi.single.baris, ['6 JERIGEN MINYAK']);
      expect(h.barisTeks, ['10 JERIGEN MINYAK']);
    });

    test('revisi menumpuk, tidak menimpa yang lama', () {
      var t = _tiket(items: [const Item('GULAKU', 5)]);
      t = terapkanEdit(t, pelanggan: 'TOKO A', items: [const Item('GULAKU', 6)], jerigen: 0);
      t = terapkanEdit(t, pelanggan: 'TOKO A', items: [const Item('GULAKU', 7)], jerigen: 0);
      expect(t.revisi.map((r) => r.baris.single),
          ['5 SAK GULAKU', '6 SAK GULAKU']);
    });
  });

  group('rekapMerek', () {
    test('menjumlah lintas tiket dan mengurutkan menurun', () {
      final r = rekapMerek([
        _tiket(items: [const Item('GULAKU', 5), const Item('PAYUNG', 20)]),
        _tiket(items: [const Item('GULAKU', 8)]),
        _tiket(mode: 'minyak', jerigen: 9), // minyak tidak masuk rekap sak
      ]);
      expect(r.map((e) => '${e.key}=${e.value}'), ['PAYUNG=20', 'GULAKU=13']);
    });
  });

  group('struk', () {
    test('baris sak dan minyak sesuai format cetak', () {
      expect(
        _tiket(items: [const Item('CAKRA KEMBAR', 20)]).barisTeks,
        ['20 SAK CAKRA KEMBAR'],
      );
      expect(_tiket(mode: 'minyak', jerigen: 6).barisTeks, ['6 JERIGEN MINYAK']);
      expect(_tiket(items: [const Item('X', 3)]).totalLabel, '3 sak');
      expect(_tiket(mode: 'minyak', jerigen: 6).totalLabel, '6 jerigen');
    });

    test('waktu cetak berformat Indonesia', () {
      expect(fmtWaktuCetak(DateTime(2026, 8, 1, 9, 41)), '1 Agu 2026 · 09:41');
    });

    test('tanggal daftar berformat hari Indonesia', () {
      expect(fmtTanggal(DateTime(2026, 8, 1)), 'Sabtu, 1 Agu 2026');
      expect(fmtTanggal(DateTime(2026, 8, 2)), 'Minggu, 2 Agu 2026');
    });
  });

  group('persistensi', () {
    test('tiket bolak-balik lewat JSON tanpa kehilangan data', () {
      final t = _tiket(
        items: [const Item('GULAKU', 5)],
        revisi: [const Revisi('TOKO LAMA', ['4 SAK GULAKU'])],
      );
      final ulang = Tiket.fromJson(t.toJson());
      expect(ulang.pelanggan, t.pelanggan);
      expect(ulang.waktu, t.waktu);
      expect(ulang.items.single.qty, 5);
      expect(ulang.revisi.single.baris.single, '4 SAK GULAKU');
      expect(ulang.tanggalKunci, '2026-08-01');
      expect(ulang.jam, '09:41');
    });
  });
}
