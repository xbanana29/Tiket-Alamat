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
  final urut = hasil.values.toList()
    ..sort((a, b) => a.nama.compareTo(b.nama));
  return urut;
}

/// Merek bawaan pabrik yang belum pernah disentuh petugas.
///
/// Seed dibuat tanpa `diubah`, jadi stempelnya tetap di titik nol. Begitu
/// ditambah/diubah/dihapus lewat UI, stempelnya terisi waktu nyata.
bool merekBawaan(Merek m) =>
    m.diubah.millisecondsSinceEpoch == 0;

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
    final daftar = [
      for (final m in server) m.copyWith(terkirim: true),
    ]..sort((a, b) => a.nama.compareTo(b.nama));
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

  /// Merek yang tampil di layar. Tidak ada lagi baris tersembunyi — penghapusan
  /// sekarang sungguhan, jadi daftar ini sama dengan isi .
  List<Merek> get merekAktif => brands;

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
    if (online) {
      unawaited(unggahAntrian(diam: true));
      unawaited(tarikTiket()); // tiket perangkat lain untuk hari ini
      unawaited(selarasMerek()); // daftar merek bersama
    }
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
    ubah(() => brands = brands.where((b) => b.nama != nama).toList(),
        simpan: true);
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
    ubah(() => tanggal = hari == null
        ? DateTime.now()
        : tanggal.add(Duration(days: hari)));
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
    final sebelumMerek = merekAktif.length;
    try {
      await unggahAntrian(diam: true);
      await tarikTiket(diam: true);
      await selarasMerek(diam: true);

      final tiketBaru = riwayat.length - sebelumTiket;
      final merekBaru = merekAktif.length - sebelumMerek;
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

  /// Selaraskan daftar merek dengan server: tarik dulu, lalu kirim hanya baris
  /// yang versinya lebih baru di sini (atau belum ada di sana).
  ///
  /// Tarik-lalu-kirim, bukan kirim-semua: perangkat yang sudah punya merek
  /// sebelum sync menyala tetap mengunggahnya tanpa petugas harus menyentuh
  /// satu per satu, dan perangkat yang sudah sinkron tidak mengirim apa pun.
  ///
  /// ponytail: satu request per baris yang berubah. Pakai batch API kalau
  /// daftar merek sudah ratusan dan terasa lambat.
  Future<void> selarasMerek({bool diam = true}) async {
    if (!online) return;
    try {
      final dariServer = await _sync.tarikMerek(serverUrl);
      final hasil = selaraskanMerek(brands, dariServer);

      for (final m in hasil.kirim) {
        await _sync.pushMerek(serverUrl, m);
      }
      ubah(() => brands = hasil.daftar, simpan: true);
      if (!diam) {
        tampilToast(hasil.kirim.isNotEmpty
            ? 'Merek tersinkron · ${hasil.kirim.length} terkirim'
            : 'Merek sudah terbaru');
      }
    } on Object catch (e) {
      if (!diam) tampilToast('Gagal sync merek: $e');
    }
  }

  bool _sedangTarik = false;

  /// Sedang mengambil tiket perangkat lain — dipakai untuk indikator di Daftar.
  bool get sedangTarik => _sedangTarik;

  /// Ambil tiket semua perangkat untuk [tanggal] yang sedang dilihat.
  ///
  /// Dipanggil otomatis saat tab Daftar dibuka, tanggal digeser, dan setelah
  /// unggah — supaya petugas tidak perlu tahu ada tombol sinkronisasi.
  Future<void> tarikTiket({bool diam = true}) async {
    if (_sedangTarik || !online) {
      if (!diam && !online) tampilToast('Luring — tidak bisa ambil dari server');
      return;
    }
    final tanggalDiminta = tanggal;
    ubah(() => _sedangTarik = true);
    try {
      final dariServer = await _sync.tarik(serverUrl, tanggalDiminta);
      // Petugas bisa sudah menggeser tanggal saat request berjalan; hasil yang
      // basi tidak boleh menimpa apa yang sedang dilihat.
      if (kunciTanggal(tanggalDiminta) != kunciTanggal(tanggal)) return;
      final punyaLokal = riwayat.map((t) => t.id).toSet();
      final baru = dariServer.where((t) => !punyaLokal.contains(t.id)).length;
      final sebelum = riwayat.length;
      riwayat = buangTiketTerhapus(
        gabungTiket(riwayat, dariServer),
        dariServer,
        kunciTanggal(tanggalDiminta),
      );
      final dibuang = sebelum + baru - riwayat.length;
      _simpan();
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
    // Sekalian ambil punya perangkat lain — sekali tekan "Unggah sekarang"
    // menyelesaikan kedua arah.
    if (berhasil > 0 || ditolak == 0) unawaited(tarikTiket());
    if (diam) return;

    tampilToast(switch ((galat, ditolak)) {
      (final g?, _) => 'Gagal unggah: $g',
      (_, > 0) => '$berhasil terunggah · $ditolak ditolak server',
      _ => '$berhasil tiket terunggah ke PocketBase',
    });
  }
}
