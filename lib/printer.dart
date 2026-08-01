import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'brand.dart';
import 'models.dart';

class PrinterError implements Exception {
  final String pesan;
  PrinterError(this.pesan);
  @override
  String toString() => pesan;
}

class Perangkat {
  final String nama;
  final String mac;
  const Perangkat(this.nama, this.mac);
}

/// Cetak ESC/POS ke printer thermal Bluetooth Classic (SPP), mis. RPP02N.
///
/// ponytail: hanya perangkat yang sudah di-pair di Setelan Android yang muncul —
/// paket ini tidak punya discovery. Kalau perlu pairing dari dalam app, baru
/// ganti ke flutter_bluetooth_serial.
class Printer {
  CapabilityProfile? _profile;
  /// MAC yang terakhir berhasil disambung di sesi proses ini.
  String? _macAktif;

  /// Android 12+ butuh izin runtime BLUETOOTH_CONNECT/SCAN.
  ///
  /// print_bluetooth_thermal hanya *memeriksa* izin — kode permintaannya
  /// dikomentari di plugin — jadi permintaannya harus dari sini.
  Future<void> mintaIzin() async {
    if (await PrintBluetoothThermal.isPermissionBluetoothGranted) return;
    final hasil = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    if (hasil.values.any((s) => s.isPermanentlyDenied)) {
      throw PrinterError(
        'Izin Bluetooth ditolak permanen. Aktifkan lewat Setelan aplikasi.',
      );
    }
    if (hasil.values.any((s) => !s.isGranted)) {
      throw PrinterError('Izin Bluetooth diperlukan untuk mencetak.');
    }
  }

  Future<List<Perangkat>> daftarPerangkat() async {
    await mintaIzin();
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw PrinterError('Bluetooth mati. Nyalakan dulu.');
    }
    final list = await PrintBluetoothThermal.pairedBluetooths;
    if (list.isEmpty) {
      throw PrinterError(
        'Belum ada printer ter-pair. Pasangkan dulu di Setelan → Bluetooth.',
      );
    }
    return list.map((b) => Perangkat(b.name, b.macAdress)).toList();
  }

  Future<bool> get terhubung => PrintBluetoothThermal.connectionStatus;

  /// Putus cache lokal — dipanggil saat app resume / socket dicurigai mati.
  void tandaiPutus() {
    _macAktif = null;
  }

  /// Sambungkan ke [mac]. Setelah app ditutup, socket SPP sering hang:
  /// plugin `connectionStatus` bisa true palsu, dan `connect` gagal bila
  /// `outputStream` residual masih ada — jadi putus dulu + retry.
  Future<void> hubungkan(String mac, {bool paksa = false}) async {
    await mintaIzin();
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw PrinterError('Bluetooth mati. Nyalakan dulu.');
    }

    if (!paksa &&
        _macAktif == mac &&
        await PrintBluetoothThermal.connectionStatus) {
      return;
    }

    await _sambungUlang(mac);
  }

  Future<void> _sambungUlang(String mac) async {
    _macAktif = null;
    // Plugin: connect() return false bila outputStream != null (bug residual).
    // Selalu disconnect dulu supaya socket bersih.
    try {
      await PrintBluetoothThermal.disconnect;
    } on Object {
      // abaikan — tujuan hanya membersihkan state native
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));

    for (var i = 0; i < 3; i++) {
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      if (ok) {
        _macAktif = mac;
        return;
      }
      try {
        await PrintBluetoothThermal.disconnect;
      } on Object {
        // ignore
      }
      // Printer butuh jeda lepas sesi lama (sering setelah swipe-close app).
      await Future<void>.delayed(Duration(milliseconds: 350 * (i + 1)));
    }
    throw PrinterError(
      'Gagal terhubung ke printer. Pastikan printer nyala dan dekat, lalu coba lagi.',
    );
  }

  Future<void> _tulisBytes(List<int> bytes, String mac) async {
    var ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (ok) return;
    // Socket putus diam-diam — paksa reconnect sekali lalu kirim ulang.
    await _sambungUlang(mac);
    ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) {
      _macAktif = null;
      throw PrinterError('Printer menolak data. Coba hubungkan ulang.');
    }
  }

  /// Cetak [copies] rangkap. Melempar [PrinterError] bila printer tak siap —
  /// pemanggil tetap menyimpan tiketnya, cetak boleh diulang belakangan.
  Future<void> cetak({
    required String? mac,
    required Tiket tiket,
    required int lebarMm,
    required int copies,
    int paperFeed = 0,
  }) async {
    if (mac == null || mac.isEmpty) {
      throw PrinterError('Printer belum dipilih. Buka Pengaturan → Printer.');
    }
    await hubungkan(mac);
    final bytes = await bangunStruk(
      tiket: tiket,
      lebarMm: lebarMm,
      copies: copies,
      paperFeed: paperFeed,
    );
    await _tulisBytes(bytes, mac);
  }

  Future<void> tesCetak({
    required String? mac,
    required int lebarMm,
    int paperFeed = 0,
  }) async {
    if (mac == null || mac.isEmpty) {
      throw PrinterError('Printer belum dipilih.');
    }
    await hubungkan(mac);
    final g = Generator(
      lebarMm == 80 ? PaperSize.mm80 : PaperSize.mm58,
      await _profil(),
    );
    final bytes = <int>[
      ...g.reset(),
      ...g.text(
        'TES CETAK',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
      ...g.text('$kAppName · $lebarMm mm',
          styles: const PosStyles(align: PosAlign.center)),
      ...g.hr(),
      ..._feedLaluPotong(g, paperFeed),
    ];
    await _tulisBytes(bytes, mac);
  }

  Future<CapabilityProfile> _profil() async =>
      _profile ??= await CapabilityProfile.load();

  Future<List<int>> bangunStruk({
    required Tiket tiket,
    required int lebarMm,
    required int copies,
    int paperFeed = 0,
  }) async {
    final g = Generator(
      lebarMm == 80 ? PaperSize.mm80 : PaperSize.mm58,
      await _profil(),
    );
    final bytes = <int>[];
    for (var i = 0; i < copies; i++) {
      bytes.addAll(_satuRangkap(g, tiket, copies, i, paperFeed));
    }
    return bytes;
  }

  List<int> _satuRangkap(
    Generator g,
    Tiket t,
    int copies,
    int index,
    int paperFeed,
  ) {
    const tengah = PosStyles(align: PosAlign.center);
    final b = <int>[...g.reset()];

    b.addAll(g.text(
      copies == 1
          ? 'TANDA AMBIL BARANG'
          : (index == 0 ? 'RANGKAP 1 - KULI MUAT' : 'RANGKAP 2 - PELANGGAN'),
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    b.addAll(g.hr());

    // Nama pelanggan besar — bagian paling penting, dibaca dari jauh oleh kuli muat.
    b.addAll(g.text(
      t.pelanggan,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    b.addAll(g.text(fmtWaktuCetak(t.waktu), styles: tengah));
    b.addAll(g.text('Petugas: ${t.petugas}', styles: tengah));
    b.addAll(g.hr(ch: '='));

    if (t.isMinyak) {
      // Teks biasa saja. size2 = batas andal GS! di RPP02N/sejenis
      // (size3–8 sering diabaikan printer → angka tetap kecil).
      b.addAll(g.text(
        '${t.jerigen}',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ));
      b.addAll(g.text(
        'JERIGEN MINYAK',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ));
    } else {
      for (final baris in t.barisTeks) {
        b.addAll(g.text(
          baris,
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ));
      }
    }

    b.addAll(g.hr(ch: '='));
    b.addAll(g.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: t.totalLabel.toUpperCase(),
        width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]));
    b.addAll(g.text('Tanda terima gudang - tusuk di paku'));
    b.addAll(g.text('setelah barang keluar'));
    b.addAll(_feedLaluPotong(g, paperFeed));
    return b;
  }

  /// [paperFeed] = baris kosong ekstra sebelum potong (0–3).
  List<int> _feedLaluPotong(Generator g, int paperFeed) {
    final n = paperFeed.clamp(0, 3);
    return [
      if (n > 0) ...g.feed(n),
      ...g.cut(),
    ];
  }
}

const _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// "1 Agu 2026 · 09:41" — dipakai di struk dan pratinjau.
String fmtWaktuCetak(DateTime d) =>
    '${d.day} ${_bulan[d.month - 1]} ${d.year} · '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
