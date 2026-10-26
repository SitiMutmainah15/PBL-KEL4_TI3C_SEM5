# Implementasi UI EcoPlant AI

Tahap ini mengikuti `../doc/agents.md`, `../doc/prd.md`, dan `../doc/design.md`.
`architecture.md` tidak dibaca sesuai batas yang diminta. Pengguna menyetujui UI
dan service stub tanpa prediksi palsu pada 24 September 2026.

## Yang tersedia

- Navigasi Beranda, Scan, dan Riwayat.
- Kamera Android dengan preview, panduan frame, shutter, penanganan izin/error,
  dan pelepasan kamera saat aplikasi tidak aktif.
- Pemilihan galeri, pemulihan hasil picker Android, validasi gambar, preview,
  ambil ulang, ganti foto, dan batal foto.
- Kontrak analisis serta tampilan loading/error. Tidak ada hasil sintetis di aplikasi.
- Layar hasil dan detail riwayat menerima `DetectionResult` dari layanan.
- Kontrak repository riwayat; tampilan loading, error/retry, kosong, dan daftar.
- Penanganan gagal simpan mempertahankan hasil. Berhasil simpan menginvalidasi
  daftar dan menonaktifkan penyimpanan ulang pada layar yang sama.
- Model version tersedia pada kontrak hasil; confidence divalidasi dalam 0..1.

## Caption dari model bahasa

Alamat backend ditentukan saat build. Bawaan `10.0.2.2` hanya berlaku di emulator,
sedangkan HP fisik butuh IP LAN komputer. Pakai `scripts/run-device.ps1` agar
alamat itu terisi otomatis. Tanpa itu, layar hasil berhenti di status memuat
karena permintaan menunggu alamat yang tidak ada.

Layar hasil kini mengambil teks pendamping dari layanan caption berbasis Groq
(`backend/`) alih-alih teks statis di aplikasi.

- Satu permintaan menghasilkan tiga bagian: ringkasan kondisi, penanganan awal,
  dan saran memotret ulang. Model tidak diminta menghitung ulang confidence.
- Prompt melarang diagnosis pasti, dosis, merek pestisida, dan em dash.
- Bila label yang disebut model bahasa berbeda dari keluaran TFLite, layar
  menampilkan catatan perbedaan dan tetap memakai label TFLite sebagai hasil utama.
- Tiga foto pembanding per kelas diambil dari `training/dataset/test/` dan
  dibundel sebagai aset. Ini pembanding tampilan, bukan hasil analisis foto pengguna.
- Status muat, gagal, dan coba lagi tersedia. Setelah gagal, pengguna dapat memilih
  menampilkan keterangan umum yang ditulis manusia (`baseline_condition.dart`),
  bukan teks karangan model.
- Permintaan yang sama tidak diulang selama sesi berjalan (cache di memori aplikasi);
  backend juga menyimpan cache ber-hash untuk foto dan label yang identik.
- Kunci Groq hanya ada di `backend/.env`. Aplikasi tidak pernah memegang kunci itu.

## Batas tahap ini

Stub analisis dan riwayat sengaja mengembalikan kegagalan yang jelas. Tidak ada
TFLite, Firebase, schema database, autentikasi, atau klaim akurasi yang dibuat.
Hasil/sukses penyimpanan hanya diuji menggunakan dependency override di `test/`.
Daftar riwayat production menampilkan layanan belum tersedia, bukan menganggap
kegagalan koneksi sebagai daftar kosong.

Foto hero memakai placeholder berlabel sampai aset foto pisang tersedia.
Percobaan pengunduhan foto public domain dari Wikimedia ditolak HTTP 429;
tidak ada foto eksternal yang dibundel.
Logo khusus belum diberikan; ikon launcher masih bawaan proyek. Informasi
penyakit dan penanganan spesifik memakai keterangan belum tersedia sampai konten
terkurasi disetujui. Halaman hasil tidak dapat dicapai dari stub analisis production.

Tahap integrasi berikut memerlukan model `.tflite`, urutan label dari metadata,
spesifikasi preprocessing training, bukti evaluasi, foto hero, konten penyakit,
serta konfigurasi proyek Firebase dan keputusan identitas pengguna. Temporary path foto belum menjadi
penyimpanan permanen; repository nyata harus menyalin/upload foto sebelum
mengonfirmasi penyimpanan. Tidak ada pengiriman foto pada tahap ini.

## Keputusan desain

ENERGY 2 / RHYTHM 2 / MOTION 1. Tema terang mengikuti canvas desain untuk alat
pertanian Android; tidak ditambahkan toggle tema di luar scope.
Roboto menggunakan fallback sans-serif Android yang diizinkan desain, tanpa
pengambilan font dari jaringan. Material Icons memberi simbol literal kamera,
galeri, beranda, riwayat, dan informasi. Cream memisahkan informasi pendukung;
forest gelap menjadi anchor hasil; leaf hanya untuk confidence. Radius 12/16/18,
padding layar 20, spacing kelipatan 4. Kartu dipakai untuk pengelompokan informasi.
Frame kamera dua lapis menjaga keterlihatan di latar foto terang/gelap. Tidak ada
gradient, glow, glass, dekorasi sparkle, atau animasi dekoratif.

## Verifikasi

Hasil terakhir: format lulus, analyzer tanpa temuan selain info nama berkas lama,
26 tes Flutter dan 11 tes backend lulus. Uji live ke Groq dan endpoint caption
dijalankan pada lingkungan ini.

Jalankan dari folder `ecoplant`:

```powershell
dart format .
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

Jalankan dari folder `backend`:

```powershell
..\.venv\Scripts\python.exe -m pytest
```

Tes menggunakan fixture sintetis yang hanya ada dalam folder `test/`:

- Home Scan Daun menuju Scan; tab dan Lihat semua membuka tujuan yang sesuai.
- Pemilihan galeri yang dibatalkan mempertahankan state.
- Foto tidak valid mempertahankan preview terakhir yang valid.
- Analisis memerlukan gambar dan menolak permintaan ganda saat proses berjalan.
- Loading analisis menuju hasil ketika layanan tes menyelesaikan permintaan.
- Scan Ulang kembali ke Scan dan menghapus foto.
- Riwayat loading/error/retry menuju list dan detail tanpa inferensi ulang.
- Gagal simpan mempertahankan hasil; retry berhasil; tombol menjadi Tersimpan.
- Layar mobile diuji pada 320, 390, dan 480 px dengan skala teks 200%.
- Tab/Enter mengaktifkan aksi utama.
- Caption: status muat, teks lengkap, foto pembanding, dan kartu saran foto.
- Caption gagal menampilkan pesan dan Coba Lagi yang memanggil ulang layanan.
- Keterangan umum hanya muncul setelah pengguna memilihnya.
- Foto yang dinilai sulit dibaca memakai judul kartu yang berbeda.
- Permintaan caption yang sama dipakai ulang; invalidasi memaksa permintaan baru.
- Setiap kelas punya tiga foto pembanding dan JSON caption wajib lengkap.
- Setiap berkas foto pembanding benar-benar terbaca dari bundel aset.
- Capture widget untuk tinjauan visual disimpan di `build/review/`.

Perhitungan kontras WCAG: putih/forest700 4.97:1; putih/forest900 9.93:1;
ink600/canvas 4.86:1; ink900/cream 14.16:1; forest900/cream 8.91:1;
error/cream 6.33:1; leaf500/forest900 5.24:1.

Build debug Android berhasil pada lingkungan ini. Flutter doctor masih memberi
peringatan command-line tools/lisensi Android; pub add juga melaporkan dukungan
symlink Windows belum aktif. Keduanya tidak menghalangi build APK debug yang
diuji. Belum ada uji kamera/izin/lifecycle pada perangkat Android fisik.

## Referensi dependensi

- [Riverpod](https://pub.dev/packages/flutter_riverpod): state dan dependency overrides.
- [camera](https://pub.dev/packages/camera): preview/capture native, izin dan lifecycle.
- [image_picker](https://pub.dev/packages/image_picker): galeri dan recovery Android.
- [http](https://pub.dev/packages/http): unggah multipart foto ke layanan caption.

Versi terkunci pada `pubspec.lock`, sesuai SDK proyek. File registrasi plugin
platform lain diperbarui otomatis oleh Flutter, bukan pengembangan fitur desktop/web.
