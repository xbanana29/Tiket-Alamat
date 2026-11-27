import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart' show TextEditingController;

import 'brand.dart';
import 'models.dart';
import 'printer.dart';
import 'store.dart';
import 'sync.dart';
import 'theme.dart' show kFontScales;

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
  final baru = asli.copyWith(
    pelanggan: pelanggan,
    items: items,
    jerigen: jerigen,
  );
  final berubah = !listEquals(asli.barisTeks, baru.barisTeks);
  final namaBerubah = asli.pelanggan != pelanggan;
  if (!berubah && !namaBerubah) return baru;
  return baru.copyWith(
    revisi: [
      ...asli.revisi,
      Revisi(asli.pelanggan, berubah ? asli.barisTeks : const []),
    ],
  );
}

/// Berapa hari tiket yang sudah terkirim disimpan di HP.
///
/// Salinan utuhnya ada di server, dan tab Daftar menarik ulang tanggal mana
/// pun yang dibuka. Tanpa batas ini `data.json` tumbuh selamanya dan seluruh
/// isinya di-encode ulang tiap kali ada yang disimpan.
const kSimpanRiwayatHari = 30;

/// Buang tiket terkirim yang lebih tua dari [hari] hari.
///
/// Tiket yang **belum terkirim** tidak pernah dibuang, setua apa pun —
/// satu-satunya salinannya ada di HP ini.
List<Tiket> pangkasRiwayat(
  List<Tiket> riwayat,
  DateTime sekarang, {
  int hari = kSimpanRiwayatHari,
}) {
  final batas = DateTime(sekarang.year, sekarang.month, sekarang.day - hari);
  return riwayat
      .where((t) => belumTerkirim(t.status) || !t.waktu.isBefore(batas))
      .toList();
}

bool _samaHari(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Isi tiket identik (termasuk status), dibandingkan lewat bentuk JSON-nya.
bool samaIsiTiket(Tiket a, Tiket b) =>
    jsonEncode(a.toJson()) == jsonEncode(b.toJson());

bool _samaMerek(List<Merek> a, List<Merek> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i], y = b[i];
    if (x.nama != y.nama ||
        x.kategori != y.kategori ||
        x.diubah != y.diubah ||
        x.terkirim != y.terkirim) {
      return false;
    }
  }
  return true;
}

/// Jalankan satu tugas async paling banyak satu sekaligus.
///
/// Panggilan yang datang saat tugas berjalan tidak memulai salinan kedua —
/// ia menunggu yang sedang berjalan, dan tugasnya diulang sekali setelah
/// selesai supaya perubahan yang datang di tengah jalan tetap terbawa.
class SatuJalan {
  Future<void>? _jalan;
  bool _lagi = false;

  bool get berjalan => _jalan != null;

  /// Minta satu putaran lagi setelah putaran ini selesai.
  void ulangi() => _lagi = true;

  Future<void> jalankan(Future<void> Function() tugas) {
    final j = _jalan;
    if (j != null) {
      _lagi = true;
      return j;
    }
    return _jalan = _putar(tugas);
  }

  Future<void> _putar(Future<void> Function() tugas) async {
    try {
      do {
        _lagi = false;
        await tugas();
      } while (_lagi);
    } finally {
      _jalan = null;
    }
  }
}

/// Gabungkan tiket dari server ke dalam riwayat lokal.
///
/// Aturan tabrakan, sengaja sederhana:
/// - Tiket lokal yang **belum terkirim** selalu menang. Isinya ada perubahan
///   yang belum sampai ke server; menimpanya dengan versi server = kehilangan
///   ketikan petugas.
/// - Selain itu versi server yang menang, karena perangkat lain mungkin baru
///   mengubahnya.
/// - Tiket yang hanya ada di server ditambahkan.
///
/// Urutan hasil: terbaru dulu, sama seperti riwayat lokal.
List<Tiket> gabungTiket(List<Tiket> lokal, List<Tiket> server) {
  final hasil = <String, Tiket>{for (final t in lokal) t.id: t};
  for (final s in server) {
    final ada = hasil[s.id];
    if (ada != null && belumTerkirim(ada.status)) continue; // lokal menang
    hasil[s.id] = s;
  }
  final urut = hasil.values.toList()
    ..sort((a, b) => b.waktu.compareTo(a.waktu));
  return urut;
}

/// Buang tiket yang sudah tidak ada lagi di server.
///
/// `gabungTiket` hanya menambahkan dari server, tidak pernah mengurangi — jadi
/// tiket yang dihapus lewat Admin UI tetap tertinggal di HP selamanya:
/// statusnya sudah `Terkirim` sehingga tidak pernah diunggah ulang, dan tidak
/// ada apa pun yang memberitahu HP bahwa barisnya sudah lenyap.
///
/// Dua pagar pengaman:
/// - hanya untuk [tanggal] yang baru saja ditarik; tanggal lain tidak ikut
///   dinilai karena tarikan memang cuma satu hari
/// - tiket yang **belum terkirim** tidak pernah dibuang — satu-satunya salinan
///   tiket itu ada di HP ini
List<Tiket> buangTiketTerhapus(
  List<Tiket> lokal,
  List<Tiket> server,
  String tanggal,
) {
  final adaDiServer = {for (final t in server) t.id};
  return lokal.where((t) {
    if (t.tanggalKunci != tanggal) return true;
    if (belumTerkirim(t.status)) return true;
    return adaDiServer.contains(t.id);
  }).toList();
}

/// Gabungkan daftar merek dua perangkat.
///
/// Kuncinya `nama`. Kalau merek yang sama ada di dua tempat, yang `diubah`-nya
/// paling baru menang. Baris yang datang dari server ditandai sudah terkirim,
/// karena itulah yang membedakan "belum diunggah" dari "sudah dihapus di sana".
List<Merek> gabungMerek(List<Merek> lokal, List<Merek> server) {
  final hasil = <String, Merek>{for (final m in lokal) m.nama: m};
  for (final s in server) {
    final ada = hasil[s.nama];
    // Apa pun yang datang dari server, menurut definisi sudah ada di server.
    final dariServer = s.copyWith(terkirim: true);
    if (ada == null || s.diubah.isAfter(ada.diubah)) {
      hasil[s.nama] = dariServer;
    } else {
      hasil[s.nama] = ada.copyWith(terkirim: true);
    }
  }
  final urut = hasil.values.toList()..sort((a, b) => a.nama.compareTo(b.nama));
  return urut;
}

/// Merek bawaan pabrik yang belum pernah disentuh petugas.
///
/// Seed dibuat tanpa `diubah`, jadi stempelnya tetap di titik nol. Begitu
/// ditambah/diubah/dihapus lewat UI, stempelnya terisi waktu nyata.
bool merekBawaan(Merek m) => m.diubah.millisecondsSinceEpoch == 0;

/// Hasil penyelarasan: daftar yang dipakai perangkat, dan baris yang perlu
/// dikirim ke server.
typedef HasilSelaras = ({List<Merek> daftar, List<Merek> kirim});

/// Tentukan daftar merek akhir dan apa yang perlu diunggah.
///
/// Dua aturan yang mencegah daftar gudang tercemar:
///
/// 1. **Merek bawaan tidak pernah dikirim.** Kalau dikirim, HP yang baru
///    dipasang ulang akan menyumbangkan 20 merek contoh ke daftar bersama —
///    dan semua HP lain ikut kebanjiran.
/// 2. **HP yang isinya masih bawaan semua mengambil alih daftar server.**
///    Perangkat baru bergabung ke gudang yang sudah punya daftar, bukan
///    mencampurkan contoh pabrik ke dalamnya.
HasilSelaras selaraskanMerek(List<Merek> lokal, List<Merek> server) {
  if (server.isNotEmpty && lokal.every(merekBawaan)) {
    final daftar = [for (final m in server) m.copyWith(terkirim: true)]
      ..sort((a, b) => a.nama.compareTo(b.nama));
    return (daftar: daftar, kirim: const []);
  }

  final diServer = {for (final m in server) m.nama: m};
  final gabungan = gabungMerek(lokal, server);
  // Server kosong lebih mungkin berarti "belum ada isinya" daripada "semua
  // merek baru saja dihapus". Membuang seluruh daftar lokal karenanya terlalu
  // mahal untuk ditebak — HP justru yang mengisi.
  final daftar = server.isEmpty
      ? gabungan
      : buangMerekTerhapus(gabungan, diServer.keys.toSet());
  final kirim = daftar.where((m) {
    if (merekBawaan(m)) return false;
    final s = diServer[m.nama];
    return s == null || m.diubah.isAfter(s.diubah);
  }).toList();
  return (daftar: daftar, kirim: kirim);
}

/// Mode tema dari data tersimpan.
///
/// Versi lama menyimpan `darkMode: bool`, dan selalu menulis `false` walau
/// petugas tidak pernah menyentuhnya. Karena itu `false` dibaca sebagai
/// "ikut sistem", bukan "terang" — hanya pilihan gelap yang pasti disengaja.
ThemeMode bacaTemaMode(Map<String, dynamic> j) {
  final nama = j['temaMode'] as String?;
  if (nama != null) {
    return ThemeMode.values.firstWhere(
      (m) => m.name == nama,
      orElse: () => ThemeMode.system,
    );
  }
  return j['darkMode'] == true ? ThemeMode.dark : ThemeMode.system;
}

/// Buang merek yang pernah terkirim tapi sudah tidak ada lagi di server.
///
/// Inilah yang membuat penghapusan sungguhan bisa menular: begitu barisnya
/// hilang di server — dihapus dari HP lain atau lewat Admin UI — perangkat ini
/// ikut membuangnya.
///
/// Merek yang **belum pernah terkirim** tidak disentuh: ketidakhadirannya di
/// server berarti belum sempat diunggah, bukan sudah dihapus.
List<Merek> buangMerekTerhapus(List<Merek> daftar, Set<String> adaDiServer) =>
    daftar.where((m) {
      if (adaDiServer.contains(m.nama)) return true;
      // Tidak ada di server. Yang dipertahankan hanya merek buatan petugas yang
      // memang belum sempat diunggah.
      //
      // Merek tanpa stempel waktu ikut dibuang: itu contoh bawaan pabrik atau
      // sisa data lama yang tidak pernah ikut sinkronisasi — tanpa aturan ini
      // keduanya terjebak selamanya, tidak pernah dikirim (karena dianggap
      // bawaan) dan tidak pernah dibuang.
      return !m.terkirim && !merekBawaan(m);
    }).toList();

const _hari = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

String fmtTanggal(DateTime d) =>
    '${_hari[d.weekday % 7]}, ${d.day} ${namaBulanPendek[d.month - 1]} ${d.year}';

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

  /// Sistem (ikut tema HP), terang, atau gelap — sama dengan AmePOS.
  ///
  /// Didengarkan MaterialApp sendiri: hanya perubahan tema yang membangun
  /// ulang MaterialApp, bukan setiap `notifyListeners`.
  final temaMode = ValueNotifier(ThemeMode.system);

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

  // Tiga nilai di bawah berubah tiap ketukan numpad atau tiap toast. Masing-
  // masing punya ValueNotifier sendiri supaya hanya widget yang menampilkannya
  // yang dibangun ulang — bukan seluruh aplikasi lewat AppScope.

  /// Buffer numpad Minyak.
  final minyakBufNotifier = ValueNotifier('');
  String get minyakBuf => minyakBufNotifier.value;
  set minyakBuf(String v) => minyakBufNotifier.value = v;
  int get minyakQty => int.tryParse(minyakBuf) ?? 0;

  String? armed; // merek yang sedang diisi qty-nya

  /// Buffer numpad "Jumlah sak".
  final bufNotifier = ValueNotifier('');
  String get buf => bufNotifier.value;
  set buf(String v) => bufNotifier.value = v;

  bool online = false;

  final toastNotifier = ValueNotifier('');
  String get toast => toastNotifier.value;

  String histFilter = 'semua';
  String daftarView = 'tiket';
  String aturView = 'utama';
  DateTime tanggal = DateTime.now();
  bool printOpen = false;
  bool siapCetak = false; // data sudah dimuat dari disk

  Timer? _toastTimer;
  StreamSubscription? _netSub;

  double get scale => kFontScales[fontStep];
  int get totalSak => items.fold(0, (a, b) => a + b.qty);
  bool get isMinyak => mode == 'minyak';

  // Turunan `riwayat` disimpan dan dihitung ulang hanya saat daftarnya
  // diganti. Ini bergantung pada aturan yang sudah dipakai di seluruh file:
  // `riwayat` selalu **diganti** dengan list baru, tidak pernah diubah di
  // tempat (`add`/`remove`).
  List<Tiket>? _statusDari;
  int _queue = 0;
  int _ditolak = 0;

  void _hitungStatus() {
    if (identical(_statusDari, riwayat)) return;
    _statusDari = riwayat;
    _queue = 0;
    _ditolak = 0;
    for (final t in riwayat) {
      if (belumTerkirim(t.status)) _queue++;
      if (t.status == statusDitolak) _ditolak++;
    }
  }

  /// Tiket yang belum sampai ke server — termasuk yang ditolak, karena itu juga
  /// belum tersimpan di mana pun selain HP ini.
  int get queue {
    _hitungStatus();
    return _queue;
  }

  /// Tiket yang ditolak server. Dipakai untuk peringatan di Pengaturan.
  int get jumlahDitolak {
    _hitungStatus();
    return _ditolak;
  }

  int qtyOf(String nama) =>
      items.where((i) => i.nama == nama).fold(0, (a, b) => a + b.qty);

  List<Tiket>? _hariDari;
  DateTime? _hariTanggal;
  List<Tiket> _hariIni = const [];

  List<Tiket> get tiketHariIni {
    final tgl = _hariTanggal;
    if (!identical(_hariDari, riwayat) ||
        tgl == null ||
        !_samaHari(tgl, tanggal)) {
      _hariDari = riwayat;
      _hariTanggal = tanggal;
      _hariIni = List.unmodifiable(
        riwayat.where((t) => _samaHari(t.waktu, tanggal)),
      );
    }
    return _hariIni;
  }

  List<Tiket> get tiketTerpilih => histFilter == 'semua'
      ? tiketHariIni
      : tiketHariIni.where((t) => t.mode == histFilter).toList();

  // ---------- siklus hidup ----------

  Future<void> init() async {
    final j = await _store.load();
    if (j.isNotEmpty) {
      petugas = j['petugas'] as String? ?? '';
      fontStep = (j['fontStep'] as num?)?.toInt() ?? 1;
      temaMode.value = bacaTemaMode(j);
      printerWidth = (j['printerWidth'] as num?)?.toInt() ?? 58;
      copies = (j['copies'] as num?)?.toInt() ?? 1;
      paperFeed = ((j['paperFeed'] as num?)?.toInt() ?? 0).clamp(0, 3);
      serverUrl = j['serverUrl'] as String? ?? serverUrl;
      printerMac = j['printerMac'] as String?;
      printerNama = j['printerNama'] as String? ?? '';
      final b = j['brands'] as List?;
      if (b != null) {
        brands = b
            .map((e) => Merek.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      riwayat = pangkasRiwayat(
        ((j['riwayat'] ?? []) as List)
            .map((e) => Tiket.fromJson(e as Map<String, dynamic>))
            .toList(),
        DateTime.now(),
      );
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
    if (online) {
      // Berurutan: kirim dulu, baru tarik tiket perangkat lain untuk hari
      // ini. Dijalankan bersamaan, unggah memicu tarikan kedua.
      unawaited(
        unggahAntrian(
          diam: true,
          tarikSesudah: false,
        ).then((_) => tarikTiket()),
      );
      unawaited(selarasMerek()); // daftar merek bersama
    }
  }

  bool _adaJaringan(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);

  void _simpan() {
    _store.save({
      'petugas': petugas,
      'fontStep': fontStep,
      'temaMode': temaMode.value.name,
      'printerWidth': printerWidth,
      'copies': copies,
      'paperFeed': paperFeed,
      'serverUrl': serverUrl,
      'printerMac': printerMac,
      'printerNama': printerNama,
      'brands': brands.map((e) => e.toJson()).toList(),
      // Tiket lama yang sedang dilihat tetap ada di memori selama sesi ini,
      // tapi tidak ikut ditulis ke disk.
      'riwayat': pangkasRiwayat(
        riwayat,
        DateTime.now(),
      ).map((e) => e.toJson()).toList(),
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
    temaMode.dispose();
    minyakBufNotifier.dispose();
    bufNotifier.dispose();
    toastNotifier.dispose();
    _store.flush();
    super.dispose();
  }

  /// Hanya membangun ulang kotak toast, bukan seluruh aplikasi.
  void tampilToast(String t) {
    toastNotifier.value = t;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      toastNotifier.value = '';
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

  // Ketukan numpad cukup mengubah ValueNotifier-nya; tidak perlu
  // notifyListeners.
  void tekan(String d) => buf = tekanDigit(buf, d);

  void hapusBuf() => buf = '';

  void konfirmasiQty() {
    final q = int.tryParse(buf) ?? 0;
    final nama = armed;
    if (nama == null) return tutupKeypad();

    if (q > 0) {
      ubah(() {
        items = upsertItem(items, nama, q);
        armed = null;
        buf = '';
      });
      tampilToast('$nama · $q sak');
      return;
    }

    // Konfirmasi 0 pada merek yang sudah dipilih = batalkan barangnya.
    // Sebelumnya keypad hanya tertutup dan tile tetap tercentang, jadi tidak
    // ada cara membatalkan tanpa menebak bahwa baris di struk bisa diketuk.
    if (qtyOf(nama) > 0) {
      ubah(() {
        items = items.where((i) => i.nama != nama).toList();
        armed = null;
        buf = '';
      });
      tampilToast('$nama dibatalkan');
      return;
    }

    tutupKeypad();
  }

  void hapusItem(int i) => ubah(() => items = List.of(items)..removeAt(i));
  void kosongkanItems() => ubah(() => items = []);

  void tekanMinyak(String d) => minyakBuf = tekanDigit(minyakBuf, d);

  void hapusMinyakDigit() => minyakBuf = minyakBuf.isEmpty
      ? ''
      : minyakBuf.substring(0, minyakBuf.length - 1);

  void resetMinyak() => minyakBuf = '';

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

  /// Hanya petugas tertentu yang boleh menghapus tiket — lihat
  /// [kPetugasBolehHapus] soal seberapa kuat pagar ini sebenarnya.
  bool get bolehHapusTiket =>
      petugas.trim().toLowerCase() == kPetugasBolehHapus.toLowerCase();

  /// Hapus tiket dari HP ini dan dari server sekaligus.
  ///
  /// Perangkat lain ikut membuangnya saat menarik tanggal yang sama, lewat
  /// [buangTiketTerhapus].
  Future<void> hapusTiket(Tiket t) async {
    if (!bolehHapusTiket) {
      tampilToast('Hanya $kPetugasBolehHapus yang boleh menghapus tiket');
      return;
    }
    final sudahDiServer = !belumTerkirim(t.status);
    ubah(
      () => riwayat = riwayat.where((r) => r.id != t.id).toList(),
      simpan: true,
    );
    tampilToast('Tiket ${t.pelanggan} dihapus');

    // Tiket yang belum pernah terkirim tidak ada di server — tidak ada yang
    // perlu dihapus di sana.
    if (!sudahDiServer || !online) return;
    try {
      await _sync.hapusTiket(serverUrl, t.id);
    } on Object catch (e) {
      // Gagal di sini berarti tiketnya akan muncul lagi saat sync berikutnya,
      // jadi jangan ditelan diam-diam.
      tampilToast('Gagal hapus di server: $e');
    }
  }

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

  /// Simpan merek. [namaLama] null berarti tambah baru.
  ///
  /// Memakai nama, bukan indeks: `brands` menyimpan juga baris yang sudah
  /// dihapus (agar penghapusan ikut tersinkron), jadi indeks daftar di layar
  /// tidak sama dengan indeks di sini.
  void simpanMerek(String? namaLama, String nama, String kategori) {
    final n = nama.trim().toUpperCase();
    if (n.isEmpty) {
      tampilToast('Nama merek kosong');
      return;
    }
    if (brands.any((b) => b.nama == n && b.nama != namaLama)) {
      tampilToast('$n sudah ada');
      return;
    }
    final sekarang = DateTime.now();
    final gantiNama = namaLama != null && namaLama != n;

    ubah(() {
      final l = List.of(brands);
      if (gantiNama) l.removeWhere((b) => b.nama == namaLama);
      final i = l.indexWhere((b) => b.nama == n);
      final baru = Merek(n, kategori, diubah: sekarang);
      if (i >= 0) {
        l[i] = baru;
      } else {
        l.add(baru);
      }
      brands = l;
    }, simpan: true);

    tampilToast(namaLama == null ? '$n ditambahkan' : '$n disimpan');
    // Ganti nama = baris lama benar-benar dihapus di server, bukan disisakan.
    if (gantiNama) unawaited(_hapusDiServer(namaLama));
    unawaited(selarasMerek());
  }

  /// Hapus sungguhan: barisnya lenyap dari HP ini dan dari server.
  void hapusMerek(String nama) {
    ubah(
      () => brands = brands.where((b) => b.nama != nama).toList(),
      simpan: true,
    );
    tampilToast('$nama dihapus');
    unawaited(_hapusDiServer(nama));
  }

  /// Hapus di server. Gagal di sini berarti merek bisa muncul lagi saat sync
  /// berikutnya, jadi kegagalannya dilaporkan — bukan ditelan diam-diam.
  Future<void> _hapusDiServer(String nama) async {
    if (!online) return;
    try {
      await _sync.hapusMerek(serverUrl, nama);
    } on Object catch (e) {
      tampilToast('Gagal hapus $nama di server: $e');
    }
  }

  // ---------- sync ----------

  /// Pindah tab. Membuka Daftar sekalian menarik tiket perangkat lain.
  void bukaTab(String t) {
    ubah(() => tab = t);
    if (t == 'daftar') unawaited(tarikTiket());
    if (t == 'atur') unawaited(selarasMerek());
  }

  /// Geser tanggal yang dilihat di Daftar; [hari] null berarti kembali hari ini.
  void pilihTanggal({int? hari}) {
    ubah(
      () => tanggal = hari == null
          ? DateTime.now()
          : tanggal.add(Duration(days: hari)),
    );
    unawaited(tarikTiket());
  }

  bool _sedangSync = false;
  bool get sedangSync => _sedangSync;

  /// Satu tombol untuk semuanya: kirim tiket yang mengantre, tarik tiket
  /// perangkat lain untuk tanggal yang sedang dilihat, lalu selaraskan merek.
  ///
  /// Ini jalan keluar saat petugas tahu ada perubahan di HP lain tapi tidak
  /// mau menunggu pemicu otomatis (buka tab, geser tanggal, buka app).
  Future<void> syncSekarang() async {
    if (_sedangSync) return;
    if (!online) {
      tampilToast('Luring — sambungkan internet dulu');
      return;
    }
    ubah(() => _sedangSync = true);
    final sebelumTiket = riwayat.length;
    final sebelumMerek = brands.length;
    try {
      // Tarikan dijalankan di sini, bukan dipicu unggah, supaya hitungan di
      // bawah dibuat setelah tarikan benar-benar selesai.
      await unggahAntrian(diam: true, tarikSesudah: false);
      await tarikTiket(diam: true);
      await selarasMerek(diam: true);

      final tiketBaru = riwayat.length - sebelumTiket;
      final merekBaru = brands.length - sebelumMerek;
      final bagian = <String>[
        if (tiketBaru > 0) '$tiketBaru tiket baru',
        if (merekBaru != 0) '${merekBaru.abs()} merek berubah',
        if (queue > 0) '$queue masih antre',
      ];
      tampilToast(bagian.isEmpty ? 'Sudah terbaru' : bagian.join(' · '));
    } on Object catch (e) {
      tampilToast('Sync gagal: $e');
    } finally {
      ubah(() => _sedangSync = false);
    }
  }

  final _selaras = SatuJalan();

  /// Selaraskan daftar merek dengan server: tarik dulu, lalu kirim hanya baris
  /// yang versinya lebih baru di sini (atau belum ada di sana).
  ///
  /// Tarik-lalu-kirim, bukan kirim-semua: perangkat yang sudah punya merek
  /// sebelum sync menyala tetap mengunggahnya tanpa petugas harus menyentuh
  /// satu per satu, dan perangkat yang sudah sinkron tidak mengirim apa pun.
  ///
  /// Paling banyak satu penyelarasan berjalan sekaligus — lihat [SatuJalan].
  ///
  /// ponytail: satu request per baris yang berubah. Pakai batch API kalau
  /// daftar merek sudah ratusan dan terasa lambat.
  Future<void> selarasMerek({bool diam = true}) {
    if (!online) return Future.value();
    return _selaras.jalankan(() => _selarasSekali(diam));
  }

  Future<void> _selarasSekali(bool diam) async {
    if (!online) return;
    final awal = brands;
    try {
      final dariServer = await _sync.tarikMerek(serverUrl);
      final hasil = selaraskanMerek(awal, dariServer);

      for (final m in hasil.kirim) {
        await _sync.pushMerek(serverUrl, m);
      }
      // Petugas menambah/mengubah merek selagi request berjalan. Menimpa
      // `brands` dengan hasil yang dihitung dari daftar lama akan membuang
      // perubahan itu — hitung ulang saja.
      if (!identical(brands, awal)) {
        _selaras.ulangi();
        return;
      }
      if (!_samaMerek(brands, hasil.daftar)) {
        ubah(() => brands = hasil.daftar, simpan: true);
      }
      if (!diam) {
        tampilToast(
          hasil.kirim.isNotEmpty
              ? 'Merek tersinkron · ${hasil.kirim.length} terkirim'
              : 'Merek sudah terbaru',
        );
      }
    } on Object catch (e) {
      if (!diam) tampilToast('Gagal sync merek: $e');
    }
  }

  final _tarik = SatuJalan();
  bool _sedangTarik = false;

  /// Sedang mengambil tiket perangkat lain — dipakai untuk indikator di Daftar.
  bool get sedangTarik => _sedangTarik;

  /// Ambil tiket semua perangkat untuk [tanggal] yang sedang dilihat.
  ///
  /// Dipanggil otomatis saat tab Daftar dibuka, tanggal digeser, dan setelah
  /// unggah — supaya petugas tidak perlu tahu ada tombol sinkronisasi.
  ///
  /// Panggilan saat tarikan masih berjalan tidak dibuang: tarikan diulang
  /// sekali setelahnya. Dulu panggilan itu diabaikan, sehingga menggeser
  /// tanggal dua kali dengan cepat membuat tanggal kedua tidak pernah ditarik.
  Future<void> tarikTiket({bool diam = true}) {
    if (!online) {
      if (!diam) tampilToast('Luring — tidak bisa ambil dari server');
      return Future.value();
    }
    return _tarik.jalankan(() => _tarikSekali(diam));
  }

  Future<void> _tarikSekali(bool diam) async {
    if (!online) return;
    final tanggalDiminta = tanggal;
    final kunci = kunciTanggal(tanggalDiminta);
    ubah(() => _sedangTarik = true);
    try {
      final dariServer = await _sync.tarik(serverUrl, tanggalDiminta);
      // Petugas bisa sudah menggeser tanggal saat request berjalan; hasil yang
      // basi tidak boleh menimpa apa yang sedang dilihat.
      if (kunci != kunciTanggal(tanggal)) {
        _tarik.ulangi();
        return;
      }
      final lokal = {for (final t in riwayat) t.id: t};
      final baru = dariServer.where((t) => !lokal.containsKey(t.id)).length;
      final hasil = buangTiketTerhapus(
        gabungTiket(riwayat, dariServer),
        dariServer,
        kunci,
      );
      final dibuang = riwayat.length + baru - hasil.length;
      // Isi tiket yang sudah ada bisa diubah HP lain tanpa jumlahnya berubah.
      final adaYangBeda = dariServer.any((s) {
        final l = lokal[s.id];
        return l != null && !belumTerkirim(l.status) && !samaIsiTiket(l, s);
      });
      // Tanpa perubahan, jangan menulis ulang seluruh riwayat ke disk.
      if (baru > 0 || dibuang > 0 || adaYangBeda) {
        riwayat = hasil;
        _simpan();
      }
      if (!diam) {
        tampilToast(switch ((baru, dibuang)) {
          (0, 0) => 'Sudah terbaru',
          (final b, 0) => '$b tiket baru dari server',
          (0, final d) => '$d tiket dihapus di server',
          (final b, final d) => '$b baru · $d dihapus',
        });
      }
    } on Object catch (e) {
      if (!diam) tampilToast('Gagal ambil dari server: $e');
    } finally {
      ubah(() => _sedangTarik = false);
    }
  }

  final _unggah = SatuJalan();

  /// Kirim tiket yang mengantre. [tarikSesudah] sekalian menarik tiket
  /// perangkat lain setelahnya.
  ///
  /// Paling banyak satu unggahan berjalan sekaligus — tanpa ini, sinyal
  /// kembali + cetak tiket + tombol sync bisa mengirim tiket yang sama dua
  /// kali bersamaan. Tiket yang dicetak saat unggahan berjalan ikut terkirim
  /// pada putaran ulang [SatuJalan].
  Future<void> unggahAntrian({bool diam = false, bool tarikSesudah = true}) =>
      _unggah.jalankan(() => _unggahSekali(diam, tarikSesudah));

  Future<void> _unggahSekali(bool diam, bool tarikSesudah) async {
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
          .map(
            (r) => r.id == id && r.status != status
                ? r.copyWith(status: status)
                : r,
          )
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
    // Sekalian ambil punya perangkat lain — sekali tekan "Unggah sekarang"
    // menyelesaikan kedua arah. Kalau server tak terjangkau, tarikan juga
    // pasti gagal; tidak usah dicoba.
    if (tarikSesudah && (berhasil > 0 || galat == null)) {
      unawaited(tarikTiket());
    }
    if (diam) return;

    tampilToast(switch ((galat, ditolak)) {
      (final g?, _) => 'Gagal unggah: $g',
      (_, > 0) => '$berhasil terunggah · $ditolak ditolak server',
      _ => '$berhasil tiket terunggah ke PocketBase',
    });
  }
}
