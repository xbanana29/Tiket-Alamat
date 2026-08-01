import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persistensi: satu file JSON di direktori dokumen aplikasi.
///
/// ponytail: satu file JSON, pindah ke sqflite kalau tiket sudah puluhan ribu
/// atau filter tanggal terasa lambat. Semua filter di app berjalan di memori,
/// jadi SQL belum memberi apa-apa selain migrasi skema.
class Store {
  File? _file;
  Timer? _debounce;
  Map<String, dynamic>? _pending;

  Future<Map<String, dynamic>> load() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = _file = File('${dir.path}/data.json');
    if (!await f.exists()) return {};
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      // File korup — jangan bikin app gagal start; mulai dari kosong dan
      // sisihkan file lama supaya masih bisa diselamatkan manual.
      await f.rename('${f.path}.rusak');
      return {};
    }
  }

  /// Tulis dengan debounce ~300 ms; panggilan beruntun digabung.
  void save(Map<String, dynamic> data) {
    _pending = data;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), flush);
  }

  Future<void> flush() async {
    final data = _pending;
    final f = _file;
    if (data == null || f == null) return;
    _pending = null;
    _debounce?.cancel();
    // Tulis ke file sementara lalu rename: kalau app mati di tengah tulis,
    // data.json lama tetap utuh.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }
}
