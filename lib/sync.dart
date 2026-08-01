import 'package:pocketbase/pocketbase.dart';

import 'models.dart';

/// Unggah tiket ke PocketBase. Koleksi `tiket`, lihat pb_schema.json di root repo.
///
/// ponytail: push langsung + retry saat konektivitas kembali, tanpa background
/// worker. Kalau perlu sync saat app tertutup, baru tambah workmanager.
/// True bila galat ini tidak akan hilang hanya dengan mencoba lagi: server
/// sudah menerima requestnya dan menolak **isinya** (validasi field, enum di
/// luar daftar, unique bentrok).
///
/// 401/403 (auth) dan 429 (rate limit) sengaja **tidak** termasuk — itu masalah
/// server-wide yang menolak semua tiket, jadi antrian harus berhenti, bukan
/// melewati tiket satu per satu. Galat jaringan punya `statusCode` 0.
bool ditolakPermanen(Object e) {
  if (e is! ClientException) return false;
  final c = e.statusCode;
  return c >= 400 && c < 500 && c != 401 && c != 403 && c != 408 && c != 429;
}

class Sync {
  String _url = '';
  PocketBase? _pb;

  PocketBase _client(String url) {
    if (_pb == null || _url != url) {
      _url = url;
      _pb = PocketBase(url);
    }
    return _pb!;
  }

  /// Kirim satu tiket. Melempar bila gagal — pemanggil biarkan status tetap antri.
  Future<void> push(String url, Tiket t) async {
    if (url.trim().isEmpty) throw Exception('URL server kosong');
    final body = {
      'tiket_id': t.id,
      'pelanggan': t.pelanggan,
      'waktu': t.waktu.toUtc().toIso8601String(),
      'petugas': t.petugas,
      'mode': t.mode,
      'items': t.items.map((e) => e.toJson()).toList(),
      'jerigen': t.jerigen,
      'revisi': t.revisi.map((e) => e.toJson()).toList(),
    };
    final coll = _client(url).collection('tiket');
    // Upsert manual: tiket yang diedit lalu di-push ulang tidak boleh dobel.
    try {
      final ada = await coll.getFirstListItem("tiket_id='${t.id}'");
      await coll.update(ada.id, body: body);
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        await coll.create(body: body);
      } else {
        rethrow;
      }
    }
  }
}
