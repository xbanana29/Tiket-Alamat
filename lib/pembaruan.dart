import 'dart:convert';
import 'dart:io';

/// Repo publik tempat rilis diterbitkan.
const kRepoRilis = 'xbanana29/Tiket-Alamat';
const kHalamanRilis = 'https://github.com/$kRepoRilis/releases/latest';

class Rilis {
  final String versi; // tanpa awalan "v"
  final String catatan;
  final String? unduhanApk;
  const Rilis({
    required this.versi,
    required this.catatan,
    this.unduhanApk,
  });
}

/// Bandingkan dua versi semver sederhana ("1.2.10" > "1.2.9").
///
/// Perbandingan teks biasa salah di sini: "1.2.10" < "1.2.9" secara abjad.
int bandingVersi(String a, String b) {
  List<int> pecah(String v) => v
      .split(RegExp(r'[^0-9]+'))
      .where((e) => e.isNotEmpty)
      .map(int.parse)
      .toList();
  final x = pecah(a), y = pecah(b);
  for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
    final p = i < x.length ? x[i] : 0;
    final q = i < y.length ? y[i] : 0;
    if (p != q) return p.compareTo(q);
  }
  return 0;
}

bool adaVersiBaru(String sekarang, String terbaru) =>
    bandingVersi(terbaru, sekarang) > 0;

/// Ambil rilis terbaru dari GitHub. Melempar bila jaringan/API bermasalah.
///
/// ponytail: satu GET tanpa auth ke API publik, tanpa paket tambahan.
/// Kalau repo dijadikan privat lagi, endpoint ini ikut mati.
Future<Rilis> cekRilisTerbaru() async {
  final klien = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await klien.getUrl(
      Uri.parse('https://api.github.com/repos/$kRepoRilis/releases/latest'),
    );
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    req.headers.set(HttpHeaders.userAgentHeader, 'TiketAlamat');
    final res = await req.close();
    if (res.statusCode == 404) {
      throw const PembaruanGagal('Belum ada rilis di GitHub.');
    }
    if (res.statusCode != 200) {
      throw PembaruanGagal('GitHub menjawab ${res.statusCode}.');
    }
    final j = jsonDecode(await res.transform(utf8.decoder).join())
        as Map<String, dynamic>;
    final tag = (j['tag_name'] as String? ?? '').replaceFirst('v', '');
    if (tag.isEmpty) throw const PembaruanGagal('Rilis tanpa nomor versi.');

    String? apk;
    for (final a in (j['assets'] as List? ?? const [])) {
      final nama = (a as Map)['name'] as String? ?? '';
      if (nama.toLowerCase().endsWith('.apk')) {
        apk = a['browser_download_url'] as String?;
        break;
      }
    }
    return Rilis(
      versi: tag,
      catatan: (j['body'] as String? ?? '').trim(),
      unduhanApk: apk,
    );
  } on SocketException {
    throw const PembaruanGagal('Tidak ada koneksi ke GitHub.');
  } finally {
    klien.close(force: true);
  }
}

class PembaruanGagal implements Exception {
  final String pesan;
  const PembaruanGagal(this.pesan);
  @override
  String toString() => pesan;
}
