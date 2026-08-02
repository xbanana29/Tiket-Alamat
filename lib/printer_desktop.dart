import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Cetak ESC/POS mentah ke printer USB di desktop.
///
/// Bluetooth SPP tidak ada di desktop, jadi jalurnya lewat sistem cetak bawaan:
/// - **Linux** → CUPS (`lp -o raw`). Printer USB ESC/POS biasanya sudah terdaftar
///   sebagai antrean; `raw` membuat CUPS meneruskan byte apa adanya tanpa
///   menerjemahkannya jadi PostScript.
/// - **Windows** → winspool lewat `dart:ffi` dengan datatype `RAW`. Tidak ada
///   perintah bawaan Windows yang bisa mengirim byte mentah ke printer dengan
///   andal, jadi API-nya dipanggil langsung.
///
/// ponytail: dua jalur pendek langsung ke sistem cetak OS, bukan paket USB
/// lintas platform. Tidak ada dependensi baru selain `ffi` yang memang sudah
/// ikut terpasang.
class PrinterDesktop {
  /// macOS ikut jalur CUPS: `permission_handler` tidak punya implementasi
  /// macOS, jadi jalur Bluetooth akan melempar MissingPluginException di sana.
  /// CUPS sendiri sudah bawaan macOS.
  static bool get _cups => Platform.isLinux || Platform.isMacOS;

  static bool get didukung => _cups || Platform.isWindows;

  /// Nama antrean printer yang terpasang di sistem.
  static Future<List<String>> daftar() async {
    if (_cups) return _daftarCups();
    if (Platform.isWindows) return _daftarWindows();
    return const [];
  }

  static Future<void> kirim(String antrean, List<int> bytes) async {
    if (_cups) return _kirimCups(antrean, bytes);
    if (Platform.isWindows) return _kirimWindows(antrean, bytes);
    throw const CetakGagal(
      'Cetak USB hanya tersedia di Linux, macOS, dan Windows.',
    );
  }

  // ---------------- Linux & macOS / CUPS ----------------

  static Future<List<String>> _daftarCups() async {
    final ProcessResult r;
    try {
      // `lpstat -a` mencetak satu baris per antrean yang menerima pekerjaan.
      r = await Process.run('lpstat', ['-a']);
    } on ProcessException {
      throw const CetakGagal(
        'Perintah `lpstat` tidak ada. Di Linux pasang: sudo apt install cups-client',
      );
    }
    if (r.exitCode != 0) return const [];
    return LineSplitter.split(r.stdout.toString())
        .map((baris) => baris.split(RegExp(r'\s+')).first.trim())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  static Future<void> _kirimCups(String antrean, List<int> bytes) async {
    final Process p;
    try {
      p = await Process.start('lp', ['-d', antrean, '-o', 'raw', '-']);
    } on ProcessException {
      throw const CetakGagal(
        'Perintah `lp` tidak ada. Di Linux pasang: sudo apt install cups-client',
      );
    }
    p.stdin.add(bytes);
    await p.stdin.close();
    final galat = await p.stderr.transform(const Utf8Decoder(allowMalformed: true)).join();
    if (await p.exitCode != 0) {
      throw CetakGagal('lp gagal: ${galat.trim().isEmpty ? "tanpa pesan" : galat.trim()}');
    }
  }

  // ---------------- Windows / winspool ----------------

  static Future<List<String>> _daftarWindows() async {
    // Enumerasi lewat FFI butuh membongkar array struct berukuran variabel;
    // satu perintah PowerShell jauh lebih pendek dan hasilnya sama.
    final r = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      '(Get-Printer).Name',
    ]);
    if (r.exitCode != 0) return const [];
    return LineSplitter.split(r.stdout.toString())
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static void _kirimWindows(String antrean, List<int> bytes) {
    final spool = DynamicLibrary.open('winspool.drv');

    final openPrinter = spool.lookupFunction<
        Int32 Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>),
        int Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>)>('OpenPrinterW');
    final startDoc = spool.lookupFunction<
        Int32 Function(IntPtr, Uint32, Pointer<_DocInfo1>),
        int Function(int, int, Pointer<_DocInfo1>)>('StartDocPrinterW');
    final startPage = spool.lookupFunction<Int32 Function(IntPtr),
        int Function(int)>('StartPagePrinter');
    final writePrinter = spool.lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>),
        int Function(int, Pointer<Uint8>, int, Pointer<Uint32>)>('WritePrinter');
    final endPage = spool.lookupFunction<Int32 Function(IntPtr),
        int Function(int)>('EndPagePrinter');
    final endDoc = spool.lookupFunction<Int32 Function(IntPtr),
        int Function(int)>('EndDocPrinter');
    final closePrinter = spool.lookupFunction<Int32 Function(IntPtr),
        int Function(int)>('ClosePrinter');

    final namaPrinter = antrean.toNativeUtf16();
    final pegangan = calloc<IntPtr>();
    final info = calloc<_DocInfo1>();
    final namaDok = 'Tiket Alamat'.toNativeUtf16();
    // "RAW" = kirim apa adanya; tanpa ini Windows menerjemahkan jadi GDI dan
    // perintah ESC/POS ikut tercetak sebagai teks sampah.
    final tipe = 'RAW'.toNativeUtf16();
    final data = calloc<Uint8>(bytes.length);
    final ditulis = calloc<Uint32>();

    try {
      if (openPrinter(namaPrinter, pegangan, nullptr) == 0) {
        throw CetakGagal('Tidak bisa membuka printer "$antrean".');
      }
      final h = pegangan.value;
      try {
        info.ref.pDocName = namaDok;
        info.ref.pOutputFile = nullptr;
        info.ref.pDatatype = tipe;
        if (startDoc(h, 1, info) == 0) {
          throw const CetakGagal('Printer menolak memulai dokumen.');
        }
        if (startPage(h) == 0) {
          throw const CetakGagal('Printer menolak memulai halaman.');
        }
        data.asTypedList(bytes.length).setAll(0, Uint8List.fromList(bytes));
        if (writePrinter(h, data, bytes.length, ditulis) == 0 ||
            ditulis.value != bytes.length) {
          throw const CetakGagal('Data tidak terkirim penuh ke printer.');
        }
        endPage(h);
        endDoc(h);
      } finally {
        closePrinter(h);
      }
    } finally {
      calloc.free(namaPrinter);
      calloc.free(pegangan);
      calloc.free(info);
      calloc.free(namaDok);
      calloc.free(tipe);
      calloc.free(data);
      calloc.free(ditulis);
    }
  }
}

/// DOC_INFO_1W — struktur yang diminta StartDocPrinterW level 1.
final class _DocInfo1 extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

class CetakGagal implements Exception {
  final String pesan;
  const CetakGagal(this.pesan);
  @override
  String toString() => pesan;
}
