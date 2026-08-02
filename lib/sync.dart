import 'package:pocketbase/pocketbase.dart';

import 'models.dart';

/// Sinkronisasi tiket dengan PocketBase. Koleksi `tiket`, lihat pb_schema.json.
///
/// `waktu` selalu disimpan UTC di server dan dikembalikan ke waktu lokal saat
/// ditarik — supaya dua HP di zona waktu berbeda tetap sepakat soal urutan.
///
/// ponytail: push langsung + tarik per tanggal, tanpa background worker dan
/// tanpa realtime subscribe. Tambahkan kalau ternyata perlu update seketika.

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

  /// Ambil tiket milik SEMUA perangkat untuk satu tanggal (waktu lokal).
  ///
  /// Ditarik per tanggal, bukan seluruh riwayat: tab Daftar memang tampil per
  /// tanggal, jadi yang diambil persis yang sedang dilihat. Riwayat setahun
  /// tidak ikut terseret tiap sinkronisasi.
  Future<List<Tiket>> tarik(String url, DateTime tanggal) async {
    if (url.trim().isEmpty) throw Exception('URL server kosong');
    // `waktu` disimpan UTC di server, sedangkan tanggal yang dilihat petugas
    // waktu lokal — batasnya harus dikonversi, bukan dipotong mentah.
    final mulai = DateTime(tanggal.year, tanggal.month, tanggal.day).toUtc();
    final selesai = mulai.add(const Duration(days: 1));
    final rekaman = await _client(url).collection('tiket').getFullList(
          filter: 'waktu >= "${_pbWaktu(mulai)}" && waktu < "${_pbWaktu(selesai)}"',
        );
    return rekaman.map(_keTiket).toList();
  }

  /// Format tanggal yang dimengerti filter PocketBase: "YYYY-MM-DD HH:MM:SS".
  static String _pbWaktu(DateTime d) =>
      d.toUtc().toIso8601String().replaceFirst('T', ' ').substring(0, 19);

  Tiket _keTiket(RecordModel r) {
    final d = r.toJson();
    return Tiket(
      id: d['tiket_id'] as String,
      pelanggan: d['pelanggan'] as String,
      // Server mengirim "2026-08-01 19:35:42.705Z" — spasi, bukan 'T'.
      waktu: DateTime.parse((d['waktu'] as String).replaceFirst(' ', 'T'))
          .toLocal(),
      petugas: d['petugas'] as String? ?? '',
      mode: d['mode'] as String,
      items: ((d['items'] ?? []) as List)
          .map((e) => Item.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      jerigen: ((d['jerigen'] ?? 0) as num).toInt(),
      // Ada di server, berarti sudah terkirim.
      status: statusTerkirim,
      revisi: ((d['revisi'] ?? []) as List)
          .map((e) => Revisi.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  // ---------------- merek ----------------

  /// Ambil seluruh daftar merek dari server.
  Future<List<Merek>> tarikMerek(String url) async {
    if (url.trim().isEmpty) throw Exception('URL server kosong');
    final rekaman = await _client(url).collection('merek').getFullList();
    return rekaman.map((r) {
      final d = r.toJson();
      return Merek(
        d['nama'] as String,
        d['kategori'] as String,
        diubah: _waktuServer(d['diubah']),
      );
    }).toList();
  }

  /// Hapus merek dari server, sungguhan — barisnya lenyap, bukan ditandai.
  ///
  /// Butuh `deleteRule` koleksi `merek` terbuka; kalau masih terkunci
  /// superuser, server menjawab 403 dan galatnya diteruskan ke pemanggil
  /// supaya tidak gagal diam-diam.
  Future<void> hapusMerek(String url, String nama) async {
    if (url.trim().isEmpty) throw Exception('URL server kosong');
    final coll = _client(url).collection('merek');
    try {
      final ada = await coll.getFirstListItem('nama="$nama"');
      await coll.delete(ada.id);
    } on ClientException catch (e) {
      // Sudah tidak ada di server = tujuan tercapai.
      if (e.statusCode != 404) rethrow;
    }
  }

  /// Simpan satu merek (buat bila belum ada, perbarui bila sudah).
  Future<void> pushMerek(String url, Merek m) async {
    if (url.trim().isEmpty) throw Exception('URL server kosong');
    final body = {
      'nama': m.nama,
      'kategori': m.kategori,
      'diubah': m.diubah.toUtc().toIso8601String(),
    };
    final coll = _client(url).collection('merek');
    try {
      final ada = await coll.getFirstListItem('nama="${m.nama}"');
      await coll.update(ada.id, body: body);
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        await coll.create(body: body);
      } else {
        rethrow;
      }
    }
  }

  static DateTime _waktuServer(Object? v) {
    if (v is! String || v.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.parse(v.replaceFirst(' ', 'T')).toLocal();
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
