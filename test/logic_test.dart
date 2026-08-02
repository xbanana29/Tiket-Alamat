import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart' show ClientException;
import 'package:tiket_gudang/models.dart';
import 'package:tiket_gudang/printer.dart';
import 'package:tiket_gudang/state.dart';
import 'package:tiket_gudang/store.dart';
import 'package:tiket_gudang/sync.dart';

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

/// Store yang tidak menyentuh disk — unit test tak punya path_provider.
class _StoreHampa extends Store {
  @override
  Future<Map<String, dynamic>> load() async => {};
  @override
  void save(Map<String, dynamic> data) {}
  @override
  Future<void> flush() async {}
}

/// Sync palsu: melempar galat yang sudah ditentukan untuk id tertentu.
class _SyncPalsu extends Sync {
  final Map<String, Object> galat; // id -> galat yang dilempar
  final terkirim = <String>[];
  _SyncPalsu(this.galat);

  @override
  Future<void> push(String url, Tiket t) async {
    final e = galat[t.id];
    if (e != null) throw e;
    terkirim.add(t.id);
  }
}

Tiket _antri(String id) => Tiket(
  id: id,
  pelanggan: 'TOKO $id',
  waktu: DateTime(2026, 8, 1, 9, 41),
  petugas: 'Andi',
  mode: 'sak',
  items: const [Item('GULAKU', 1)],
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

  group('ditolakPermanen', () {
    test('validasi 400/422 permanen; auth, rate limit, jaringan tidak', () {
      expect(ditolakPermanen(ClientException(statusCode: 400)), isTrue);
      expect(ditolakPermanen(ClientException(statusCode: 422)), isTrue);
      // Ini menolak SEMUA tiket, bukan hanya satu — antrian harus berhenti.
      expect(ditolakPermanen(ClientException(statusCode: 401)), isFalse);
      expect(ditolakPermanen(ClientException(statusCode: 403)), isFalse);
      expect(ditolakPermanen(ClientException(statusCode: 429)), isFalse);
      expect(ditolakPermanen(ClientException(statusCode: 500)), isFalse);
      expect(ditolakPermanen(ClientException(statusCode: 0)), isFalse); // jaringan
      expect(ditolakPermanen(Exception('apa saja')), isFalse);
    });
  });

  group('unggahAntrian', () {
    AppState buat(_SyncPalsu s, List<Tiket> riwayat) {
      final app = AppState(store: _StoreHampa(), sync: s)..riwayat = riwayat;
      return app;
    }

    test('tiket yang ditolak server tidak memblokir sisa antrian', () async {
      final s = _SyncPalsu({'b': ClientException(statusCode: 400)});
      final app = buat(s, [_antri('a'), _antri('b'), _antri('c')]);

      await app.unggahAntrian(diam: true);

      // 'c' ada DI BELAKANG record cacat — dulu ini tidak pernah terkirim.
      expect(s.terkirim, ['a', 'c']);
      expect(app.riwayat.singleWhere((t) => t.id == 'c').status, statusTerkirim);
      // Ditandai supaya petugas tahu tiket mana yang bermasalah.
      expect(app.riwayat.singleWhere((t) => t.id == 'b').status, statusDitolak);
      // Tetap dihitung belum terkirim — masih hanya ada di HP ini.
      expect(app.queue, 1);
      expect(app.jumlahDitolak, 1);
    });

    test('tiket Ditolak tetap dicoba lagi dan bisa pulih', () async {
      final s = _SyncPalsu({'a': ClientException(statusCode: 400)});
      final app = buat(s, [_antri('a')]);

      await app.unggahAntrian(diam: true);
      expect(app.riwayat.single.status, statusDitolak);

      // Admin memperbaiki skema server → sinkronisasi berikutnya harus
      // mengambil tiket itu lagi, bukan menganggapnya jalan buntu.
      s.galat.clear();
      await app.unggahAntrian(diam: true);

      expect(s.terkirim, ['a']);
      expect(app.riwayat.single.status, statusTerkirim);
      expect(app.queue, 0);
      expect(app.jumlahDitolak, 0);
    });

    test('galat jaringan tetap menghentikan antrian', () async {
      final s = _SyncPalsu({'b': ClientException(statusCode: 0)});
      final app = buat(s, [_antri('a'), _antri('b'), _antri('c')]);

      await app.unggahAntrian(diam: true);

      expect(s.terkirim, ['a']); // berhenti di 'b', 'c' tidak dicoba
      expect(app.queue, 2);
    });

    test('auth ditolak menghentikan antrian, bukan melewati satu per satu',
        () async {
      final s = _SyncPalsu({
        'a': ClientException(statusCode: 403),
        'b': ClientException(statusCode: 403),
      });
      final app = buat(s, [_antri('a'), _antri('b')]);

      await app.unggahAntrian(diam: true);

      expect(s.terkirim, isEmpty);
      expect(app.queue, 2);
    });
  });

  group('gabungTiket', () {
    Tiket t(String id, {String pelanggan = 'A', String status = statusTerkirim, int menit = 0}) =>
        Tiket(
          id: id,
          pelanggan: pelanggan,
          waktu: DateTime(2026, 8, 1, 9, menit),
          petugas: 'Andi',
          mode: 'sak',
          items: const [Item('GULAKU', 1)],
          status: status,
        );

    test('tiket perangkat lain ditambahkan', () {
      final h = gabungTiket([t('a')], [t('b')]);
      expect(h.map((e) => e.id).toSet(), {'a', 'b'});
    });

    test('versi server menang untuk tiket yang sudah terkirim', () {
      final h = gabungTiket([t('a', pelanggan: 'LAMA')],
          [t('a', pelanggan: 'DIUBAH DI HP LAIN')]);
      expect(h.single.pelanggan, 'DIUBAH DI HP LAIN');
    });

    test('lokal yang belum terkirim TIDAK ditimpa server', () {
      // Ketikan petugas yang belum sempat naik tidak boleh hilang.
      final h = gabungTiket(
        [t('a', pelanggan: 'BELUM NAIK', status: statusAntri)],
        [t('a', pelanggan: 'VERSI SERVER')],
      );
      expect(h.single.pelanggan, 'BELUM NAIK');
      expect(h.single.status, statusAntri);
    });

    test('tiket Ditolak juga tidak ditimpa server', () {
      final h = gabungTiket(
        [t('a', pelanggan: 'DITOLAK TAPI PUNYAKU', status: statusDitolak)],
        [t('a', pelanggan: 'VERSI SERVER')],
      );
      expect(h.single.pelanggan, 'DITOLAK TAPI PUNYAKU');
    });

    test('hasil urut terbaru dulu', () {
      final h = gabungTiket([t('a', menit: 10)], [t('b', menit: 30), t('c', menit: 20)]);
      expect(h.map((e) => e.id), ['b', 'c', 'a']);
    });

    test('tidak menduplikasi saat ditarik dua kali', () {
      final server = [t('a'), t('b')];
      final sekali = gabungTiket([], server);
      final duakali = gabungTiket(sekali, server);
      expect(duakali.length, 2);
    });
  });

  group('gabungMerek', () {
    final lama = DateTime(2026, 8, 1, 10);
    final baru = DateTime(2026, 8, 1, 12);

    test('merek perangkat lain ditambahkan', () {
      final h = gabungMerek(
        [Merek('A', 'Terigu', diubah: lama)],
        [Merek('B', 'Gula', diubah: lama)],
      );
      expect(h.map((e) => e.nama), ['A', 'B']);
    });

    test('perubahan paling baru yang menang', () {
      final h = gabungMerek(
        [Merek('A', 'Terigu', diubah: lama)],
        [Merek('A', 'Gula', diubah: baru)],
      );
      expect(h.single.kategori, 'Gula');
    });

    test('perubahan lama dari server tidak menimpa yang baru di lokal', () {
      final h = gabungMerek(
        [Merek('A', 'Gula', diubah: baru)],
        [Merek('A', 'Terigu', diubah: lama)],
      );
      expect(h.single.kategori, 'Gula');
    });

    test('penghapusan ikut tersinkron, bukan dihidupkan lagi', () {
      // Perangkat lain menghapus; perangkat ini masih menyimpannya.
      final h = gabungMerek(
        [Merek('A', 'Terigu', diubah: lama)],
        [Merek('A', 'Terigu', dihapus: true, diubah: baru)],
      );
      expect(h.single.dihapus, isTrue);
    });

    test('merek dihapus tetap ada di daftar agar bisa diteruskan', () {
      final h = gabungMerek(
        [Merek('A', 'Terigu', dihapus: true, diubah: baru)],
        const [],
      );
      expect(h.length, 1);
    });

    test('menambah ulang nama yang pernah dihapus menghidupkannya', () {
      final h = gabungMerek(
        [Merek('A', 'Terigu', diubah: baru)], // ditambah lagi di sini
        [Merek('A', 'Terigu', dihapus: true, diubah: lama)],
      );
      expect(h.single.dihapus, isFalse);
    });
  });

  group('buangNisanYatim', () {
    final t = DateTime(2026, 8, 2);

    test('nisan yang barisnya sudah lenyap di server ikut dibuang', () {
      // Kalau ditahan, ia akan diunggah ulang dan pembersihan di Admin UI
      // seolah membatalkan dirinya sendiri.
      final h = buangNisanYatim(
        [Merek('A', 'Terigu', dihapus: true, diubah: t)],
        <String>{},
      );
      expect(h, isEmpty);
    });

    test('nisan tetap disimpan selama barisnya masih ada di server', () {
      final h = buangNisanYatim(
        [Merek('A', 'Terigu', dihapus: true, diubah: t)],
        {'A'},
      );
      expect(h.single.dihapus, isTrue);
    });

    test('merek aktif tidak pernah dibuang walau server belum punya', () {
      // Justru perangkat inilah yang harus mengirimkannya.
      final h = buangNisanYatim([Merek('A', 'Terigu', diubah: t)], <String>{});
      expect(h.single.nama, 'A');
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
