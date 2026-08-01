// Model data. toJson/fromJson ditulis tangan — hanya 4 model, code-gen tidak sepadan.

class Item {
  final String nama;
  final int qty;
  const Item(this.nama, this.qty);

  Item copyWith({int? qty}) => Item(nama, qty ?? this.qty);

  Map<String, dynamic> toJson() => {'nama': nama, 'qty': qty};
  factory Item.fromJson(Map<String, dynamic> j) =>
      Item(j['nama'] as String, (j['qty'] as num).toInt());
}

/// Jejak audit satu kali penyuntingan tiket: nama & baris pesanan SEBELUM diubah.
class Revisi {
  final String pelanggan;
  final List<String> baris;
  const Revisi(this.pelanggan, this.baris);

  Map<String, dynamic> toJson() => {'pelanggan': pelanggan, 'baris': baris};
  factory Revisi.fromJson(Map<String, dynamic> j) => Revisi(
    j['pelanggan'] as String,
    (j['baris'] as List).map((e) => e as String).toList(),
  );
}

const statusTerkirim = 'Terkirim';
const statusAntri = 'Menunggu unggah';

class Tiket {
  final String id;
  final String pelanggan;
  final DateTime waktu;
  final String petugas;
  final String mode; // 'sak' | 'minyak'
  final List<Item> items;
  final int jerigen;
  final String status;
  final List<Revisi> revisi;

  const Tiket({
    required this.id,
    required this.pelanggan,
    required this.waktu,
    required this.petugas,
    required this.mode,
    this.items = const [],
    this.jerigen = 0,
    this.status = statusAntri,
    this.revisi = const [],
  });

  bool get isMinyak => mode == 'minyak';

  /// Tanggal lokal sebagai kunci pengelompokan (YYYY-MM-DD).
  String get tanggalKunci =>
      '${waktu.year.toString().padLeft(4, '0')}-'
      '${waktu.month.toString().padLeft(2, '0')}-'
      '${waktu.day.toString().padLeft(2, '0')}';

  String get jam =>
      '${waktu.hour.toString().padLeft(2, '0')}:'
      '${waktu.minute.toString().padLeft(2, '0')}';

  /// Baris yang dicetak di struk: "20 SAK CAKRA KEMBAR" / "6 JERIGEN MINYAK".
  List<String> get barisTeks => isMinyak
      ? ['$jerigen JERIGEN MINYAK']
      : items.map((i) => '${i.qty} SAK ${i.nama}').toList();

  String get totalLabel =>
      isMinyak ? '$jerigen jerigen' : '${items.fold(0, (a, b) => a + b.qty)} sak';

  Tiket copyWith({
    String? pelanggan,
    List<Item>? items,
    int? jerigen,
    String? status,
    List<Revisi>? revisi,
  }) => Tiket(
    id: id,
    pelanggan: pelanggan ?? this.pelanggan,
    waktu: waktu,
    petugas: petugas,
    mode: mode,
    items: items ?? this.items,
    jerigen: jerigen ?? this.jerigen,
    status: status ?? this.status,
    revisi: revisi ?? this.revisi,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'pelanggan': pelanggan,
    'waktu': waktu.toIso8601String(),
    'petugas': petugas,
    'mode': mode,
    'items': items.map((e) => e.toJson()).toList(),
    'jerigen': jerigen,
    'status': status,
    'revisi': revisi.map((e) => e.toJson()).toList(),
  };

  factory Tiket.fromJson(Map<String, dynamic> j) => Tiket(
    id: j['id'] as String,
    pelanggan: j['pelanggan'] as String,
    waktu: DateTime.parse(j['waktu'] as String),
    petugas: j['petugas'] as String,
    mode: j['mode'] as String,
    items: ((j['items'] ?? []) as List)
        .map((e) => Item.fromJson(e as Map<String, dynamic>))
        .toList(),
    jerigen: ((j['jerigen'] ?? 0) as num).toInt(),
    status: j['status'] as String? ?? statusAntri,
    revisi: ((j['revisi'] ?? []) as List)
        .map((e) => Revisi.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class Merek {
  final String nama;
  final String kategori; // 'Terigu' | 'Gula'
  const Merek(this.nama, this.kategori);

  Map<String, dynamic> toJson() => {'nama': nama, 'kategori': kategori};
  factory Merek.fromJson(Map<String, dynamic> j) =>
      Merek(j['nama'] as String, j['kategori'] as String);
}

/// Seed merek dari rancangan, dipakai saat pertama kali app dijalankan.
const seedMerek = <Merek>[
  Merek('CAKRA KEMBAR', 'Terigu'),
  Merek('SEGITIGA BIRU', 'Terigu'),
  Merek('KUNCI BIRU', 'Terigu'),
  Merek('LENCANA MERAH', 'Terigu'),
  Merek('PAYUNG', 'Terigu'),
  Merek('GERBANG', 'Terigu'),
  Merek('PIRAMIDA', 'Terigu'),
  Merek('RODA BIRU', 'Terigu'),
  Merek('BERUANG BIRU', 'Terigu'),
  Merek('TALI EMAS', 'Terigu'),
  Merek('GULAKU', 'Gula'),
  Merek('ROSE BRAND', 'Gula'),
  Merek('GULA PASIR', 'Gula'),
  Merek('NUSAKITA', 'Gula'),
  Merek('DAHLIA', 'Gula'),
  Merek('MELATI', 'Gula'),
  Merek('ACI GA', 'Gula'),
  Merek('KRISTAL PUTIH', 'Gula'),
  Merek('TEBU MAS', 'Gula'),
  Merek('MANIS KITA', 'Gula'),
];
