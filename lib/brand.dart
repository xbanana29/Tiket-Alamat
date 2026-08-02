/// Identitas aplikasi — satu sumber untuk UI & cetak.
const kAppName = 'Tiket Alamat';
const kAppNameUpper = 'TIKET ALAMAT';
const kWatermark = 'by CV Rejeki Amerta Jaya';

/// Petugas yang boleh menghapus tiket.
///
/// **Ini pagar terhadap kekeliruan, bukan terhadap niat.** Nama petugas adalah
/// teks bebas yang diketik sendiri di awal sesi, jadi siapa pun yang tahu nama
/// ini bisa mengetiknya dan mendapat hak yang sama. Gunanya mencegah petugas
/// biasa menghapus tiket karena salah tekan — bukan mengunci akses.
///
/// Kalau nanti butuh kunci sungguhan, yang diperlukan akun ber-password di
/// PocketBase dan aturan server yang memeriksanya, bukan pemeriksaan di sini.
const kPetugasBolehHapus = 'xbanana';
