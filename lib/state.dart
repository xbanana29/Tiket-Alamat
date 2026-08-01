import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextEditingController;

import 'models.dart';
import 'printer.dart';
import 'store.dart';
import 'sync.dart';

/// Naikkan angka pada string buffer numpad: maksimal 2 digit, buang nol depan,
/// clamp ke 99. Sama persis dengan `press()` di rancangan.
String tekanDigit(String buf, String digit) {
  var nb = (buf + digit).replaceFirst(RegExp(r'^0+'), '');
  if (nb.length > 2) nb = nb.substring(0, 2);
  final n = int.tryParse(nb) ?? 0;
  return n == 0 ? '' : n.clamp(0, 99).toString();
}

/// Tambah/perbarui item berdasarkan nama (upsert), qty di-clamp 1..99.
List<Item> upsertItem(List<Item> items, String nama, int qty) {
  if (qty <= 0) return items;
  final hasil = List<Item>.from(items);
  final i = hasil.indexWhere((x) => x.nama == nama);
  final it = Item(nama, qty.clamp(1, 99));
  if (i >= 0) {
    hasil[i] = it;
  } else {
    hasil.add(it);
  }
  return hasil;
}

/// Rekap total sak per merek untuk sekumpulan tiket, urut menurun.
List<MapEntry<String, int>> rekapMerek(List<Tiket> tiket) {
  final map = <String, int>{};
  for (final t in tiket) {
    if (t.isMinyak) continue;
    for (final i in t.items) {
      map[i.nama] = (map[i.nama] ?? 0) + i.qty;
    }
  }
  final rows = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return rows;
}

/// Hasil penyuntingan tiket: bila nama atau baris berubah, catat revisi.
Tiket terapkanEdit(
  Tiket asli, {
  required String pelanggan,
  required List<Item> items,
  required int jerigen,
}) {
  final barisBaru = asli.isMinyak
      ? ['$jerigen JERIGEN MINYAK']
      : items.map((i) => '${i.qty} SAK ${i.nama}').toList();
  final berubah = !listEquals(asli.barisTeks, barisBaru);
  final namaBerubah = asli.pelanggan != pelanggan;
  final revisi = (berubah || namaBerubah)
      ? [
          ...asli.revisi,
          Revisi(asli.pelanggan, berubah ? asli.barisTeks : const []),
        ]
      : asli.revisi;
  return asli.copyWith(
    pelanggan: pelanggan,
    items: items,
    jerigen: jerigen,
    revisi: revisi,
  );
}

String kunciTanggal(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _hari = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
const _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String fmtTanggal(DateTime d) =>
    '${_hari[d.weekday % 7]}, ${d.day} ${_bulan[d.month - 1]} ${d.year}';

class AppState extends ChangeNotifier {
  AppState({Store? store, Sync? sync, Printer? printer})
    : _store = store ?? Store(),
      _sync = sync ?? Sync(),
      printer = printer ?? Printer();

  final Store _store;
  final Sync _sync;
  final Printer printer;

  // --- data tersimpan ---
  String petugas = '';
  List<Merek> brands = List.of(seedMerek);
  List<Tiket> riwayat = [];
  int fontStep = 1;
  bool darkMode = false;
  int printerWidth = 58;
  int copies = 1;
  /// Baris kosong sebelum potong kertas (0–3). Printer thermal sering
  /// mendorong kertas ekstra; turunkan bila sisa blank terlalu panjang.
  int paperFeed = 0;
  String serverUrl = 'https://pb.rejekiamerta.com';
  String? printerMac;
  String printerNama = '';

  // --- state sesi (tidak disimpan) ---
  String tab = 'pesanan';
  String mode = 'sak';

  /// Controller jadi sumber kebenaran nama pelanggan — pratinjau struk cukup
  /// mendengarkannya lewat ValueListenableBuilder, tak perlu rebuild seluruh tab.
  final pelangganCtl = TextEditingController();
  String get pelanggan => pelangganCtl.text;

  List<Item> items = [];
  int minyakQty = 0;
  String minyakBuf = '';
  String? armed; // merek yang sedang diisi qty-nya
  String buf = '';
  bool online = false;
  String toast = '';
  String histFilter = 'semua';
  String daftarView = 'tiket';
  String aturView = 'utama';
  DateTime tanggal = DateTime.now();
  bool printOpen = false;
  bool siapCetak = false; // data sudah dimuat dari disk

  Timer? _toastTimer;
  StreamSubscription? _netSub;

  double get scale => [0.82, 1.0, 1.14, 1.3][fontStep];
  int get totalSak => items.fold(0, (a, b) => a + b.qty);
  bool get isMinyak => mode == 'minyak';
  /// Tiket yang belum sampai ke server — termasuk yang ditolak, karena itu juga
  /// belum tersimpan di mana pun selain HP ini.
  int get queue => riwayat.where((t) => belumTerkirim(t.status)).length;

  /// Tiket yang ditolak server. Dipakai untuk peringatan di Pengaturan.
  int get jumlahDitolak =>
      riwayat.where((t) => t.status == statusDitolak).length;

  int qtyOf(String nama) =>
      items.where((i) => i.nama == nama).fold(0, (a, b) => a + b.qty);

  List<Tiket> get tiketHariIni {
    final k = kunciTanggal(tanggal);
    return riwayat.where((t) => t.tanggalKunci == k).toList();
  }

  List<Tiket> get tiketTerpilih => tiketHariIni
      .where((t) => histFilter == 'semua' || t.mode == histFilter)
      .toList();

  // ---------- siklus hidup ----------

  Future<void> init() async {
    final j = await _store.load();
    if (j.isNotEmpty) {
      petugas = j['petugas'] as String? ?? '';
      fontStep = (j['fontStep'] as num?)?.toInt() ?? 1;
      darkMode = j['darkMode'] as bool? ?? false;
      printerWidth = (j['printerWidth'] as num?)?.toInt() ?? 58;
      copies = (j['copies'] as num?)?.toInt() ?? 1;
      paperFeed = ((j['paperFeed'] as num?)?.toInt() ?? 0).clamp(0, 3);
      serverUrl = j['serverUrl'] as String? ?? serverUrl;
      printerMac = j['printerMac'] as String?;
      printerNama = j['printerNama'] as String? ?? '';
      final b = j['brands'] as List?;
      if (b != null) {
        brands = b.map((e) => Merek.fromJson(e as Map<String, dynamic>)).toList();
      }
      riwayat = ((j['riwayat'] ?? []) as List)
          .map((e) => Tiket.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    siapCetak = true;

    final c = Connectivity();
    online = _adaJaringan(await c.checkConnectivity());
    _netSub = c.onConnectivityChanged.listen((r) {
      final baru = _adaJaringan(r);
      if (baru == online) return;
      online = baru;
      notifyListeners();
      if (online) unawaited(unggahAntrian(diam: true));
    });
    notifyListeners();
    if (online) unawaited(unggahAntrian(diam: true));
  }

  bool _adaJaringan(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);

  void _simpan() {
    _store.save({
      'petugas': petugas,
      'fontStep': fontStep,
      'darkMode': darkMode,
      'printerWidth': printerWidth,
      'copies': copies,
      'paperFeed': paperFeed,
      'serverUrl': serverUrl,
      'printerMac': printerMac,
      'printerNama': printerNama,
      'brands': brands.map((e) => e.toJson()).toList(),
      'riwayat': riwayat.map((e) => e.toJson()).toList(),
    });
  }

  /// Ubah state lalu simpan + rebuild.
  void ubah(VoidCallback f, {bool simpan = false}) {
    f();
    if (simpan) _simpan();
    notifyListeners();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _netSub?.cancel();
    pelangganCtl.dispose();
    _store.flush();
    super.dispose();
  }

  void tampilToast(String t) {
    toast = t;
    notifyListeners();
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      toast = '';
      notifyListeners();
    });
  }

  // ---------- sesi ----------

  void mulaiSesi(String nama) => ubah(() {
    petugas = nama.trim().isEmpty ? 'Operator' : nama.trim();
  }, simpan: true);

  void akhiriSesi() => ubah(() {
    petugas = '';
    tab = 'pesanan';
  }, simpan: true);

  // ---------- pesanan ----------

  void bukaKeypad(String nama) => ubah(() {
    armed = nama;
    buf = '';
  });

  void tutupKeypad() => ubah(() {
    armed = null;
    buf = '';
  });

  void tekan(String d) => ubah(() => buf = tekanDigit(buf, d));

  void hapusBuf() => ubah(() => buf = '');

  void konfirmasiQty() {
    final q = int.tryParse(buf) ?? 0;
    final nama = armed;
    if (nama != null && q > 0) {
      ubah(() {
        items = upsertItem(items, nama, q);
        armed = null;
        buf = '';
      });
      tampilToast('$nama · $q sak');
    } else {
      tutupKeypad();
    }
  }

  void hapusItem(int i) => ubah(() => items = List.of(items)..removeAt(i));
  void kosongkanItems() => ubah(() => items = []);

  void tekanMinyak(String d) => ubah(() {
    minyakBuf = tekanDigit(minyakBuf, d);
    minyakQty = int.tryParse(minyakBuf) ?? 0;
  });

  void hapusMinyakDigit() => ubah(() {
    minyakBuf = minyakBuf.isEmpty
        ? ''
        : minyakBuf.substring(0, minyakBuf.length - 1);
    minyakQty = int.tryParse(minyakBuf) ?? 0;
  });

  void resetMinyak() => ubah(() {
    minyakBuf = '';
    minyakQty = 0;
  });

  /// Tiket yang sedang disusun — dipakai untuk pratinjau dan pencetakan.
  Tiket get draft => Tiket(
    id: '',
    pelanggan: pelanggan.trim().toUpperCase(),
    waktu: DateTime.now(),
    petugas: petugas,
    mode: mode,
    items: items,
    jerigen: minyakQty,
  );

  /// Validasi sebelum membuka pratinjau cetak. Mengembalikan false bila gagal.
  bool bukaPratinjau() {
    if (pelanggan.trim().isEmpty) {
      tampilToast('Isi nama pelanggan dulu');
      return false;
    }
    if (isMinyak ? minyakQty == 0 : items.isEmpty) {
      tampilToast('Belum ada barang');
      return false;
    }
    ubah(() => printOpen = true);
    return true;
  }

  /// Simpan tiket lalu cetak. Tiket TETAP tersimpan walau printer gagal —
  /// kertas bisa diulang, data tidak boleh hilang.
  Future<void> konfirmasiCetak() async {
    final t = Tiket(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      pelanggan: pelanggan.trim().toUpperCase(),
      waktu: DateTime.now(),
      petugas: petugas,
      mode: mode,
      items: List.of(items),
      jerigen: minyakQty,
      status: statusAntri,
    );
    ubah(() {
      riwayat = [t, ...riwayat];
      printOpen = false;
      items = [];
      minyakQty = 0;
      minyakBuf = '';
      pelangganCtl.clear();
    }, simpan: true);

    String? galat;
    try {
      await printer.cetak(
        mac: printerMac,
        tiket: t,
        lebarMm: printerWidth,
        copies: copies,
        paperFeed: paperFeed,
      );
    } on Object catch (e) {
      galat = e is PrinterError ? e.pesan : 'Gagal cetak: $e';
    }
    tampilToast(galat ?? 'Tiket tercetak · tersimpan');
    unawaited(unggahAntrian(diam: true));
  }

  Future<void> cetakUlang(Tiket t) async {
    try {
      await printer.cetak(
        mac: printerMac,
        tiket: t,
        lebarMm: printerWidth,
        copies: copies,
        paperFeed: paperFeed,
      );
      tampilToast('Mencetak ulang tiket ${t.pelanggan}');
    } on Object catch (e) {
      tampilToast(e is PrinterError ? e.pesan : 'Gagal cetak: $e');
    }
  }

  // ---------- edit tiket ----------

  void simpanEdit(
    String id, {
    required String pelanggan,
    required List<Item> items,
    required int jerigen,
  }) {
    final nama = pelanggan.trim().toUpperCase();
    if (nama.isEmpty) {
      tampilToast('Nama pelanggan kosong');
      return;
    }
    ubah(() {
      riwayat = riwayat
          .map(
            (r) => r.id != id
                ? r
                : terapkanEdit(
                    r,
                    pelanggan: nama,
                    items: items,
                    jerigen: jerigen,
                  ).copyWith(status: statusAntri),
          )
          .toList();
    }, simpan: true);
    tampilToast('Tiket $nama diperbarui · cetak ulang bila perlu');
    unawaited(unggahAntrian(diam: true));
  }

  // ---------- merek ----------

  void simpanMerek(int? idx, String nama, String kategori) {
    final n = nama.trim().toUpperCase();
    if (n.isEmpty) {
      tampilToast('Nama merek kosong');
      return;
    }
    final bentrok = brands.indexWhere((b) => b.nama == n);
    if (bentrok >= 0 && bentrok != idx) {
      tampilToast('$n sudah ada');
      return;
    }
    ubah(() {
      final l = List.of(brands);
      if (idx == null) {
        l.add(Merek(n, kategori));
      } else {
        l[idx] = Merek(n, kategori);
      }
      brands = l;
    }, simpan: true);
    tampilToast(idx == null ? '$n ditambahkan' : '$n disimpan');
  }

  void hapusMerek(int idx) {
    final n = brands[idx].nama;
    ubah(() => brands = List.of(brands)..removeAt(idx), simpan: true);
    tampilToast('$n dihapus');
  }

  // ---------- sync ----------

  Future<void> unggahAntrian({bool diam = false}) async {
    // Termasuk yang berstatus Ditolak: itu penanda, bukan jalan buntu — tiketnya
    // tetap dicoba lagi supaya ikut masuk begitu skema server diperbaiki.
    final antri = riwayat.where((t) => belumTerkirim(t.status)).toList();
    if (antri.isEmpty) {
      if (!diam) tampilToast('Semua sudah tersinkron');
      return;
    }
    var berhasil = 0;
    var ditolak = 0;
    var berubah = false;
    String? galat;

    void tandai(String id, String status) {
      riwayat = riwayat
          .map((r) => r.id == id && r.status != status
              ? r.copyWith(status: status)
              : r)
          .toList();
      berubah = true;
    }

    for (final t in antri) {
      try {
        await _sync.push(serverUrl, t);
        berhasil++;
        tandai(t.id, statusTerkirim);
      } on Object catch (e) {
        if (ditolakPermanen(e)) {
          // Server menolak isi tiket ini. Lewati saja — kalau dihentikan
          // (`break`), satu record cacat memblokir SELURUH antrian di
          // belakangnya sampai app di-update.
          ditolak++;
          tandai(t.id, statusDitolak);
          continue;
        }
        // Jaringan mati, server down, auth ditolak, kena rate limit — semuanya
        // menolak tiket berikutnya juga, jadi berhenti dan coba lagi nanti.
        galat = '$e';
        break;
      }
    }
    if (berubah) ubah(() {}, simpan: true);
    if (diam) return;

    tampilToast(switch ((galat, ditolak)) {
      (final g?, _) => 'Gagal unggah: $g',
      (_, > 0) => '$berhasil terunggah · $ditolak ditolak server',
      _ => '$berhasil tiket terunggah ke PocketBase',
    });
  }
}
