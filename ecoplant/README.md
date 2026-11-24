# EcoPlant AI

Aplikasi Flutter Android untuk identifikasi awal kondisi daun pisang.
Analisis memakai Random Forest (`forest.json`) secara on-device. Riwayat dan foto
asli disimpan lokal menggunakan SQLite dan direktori privat aplikasi, sehingga
fitur utama tetap tersedia tanpa koneksi internet. Firebase Core tetap
dikonfigurasi; penyimpanan riwayat tidak bergantung pada Firestore.

```powershell
flutter pub get
flutter run -d <android-device-id>
```

Verifikasi:

```powershell
dart format .
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

APK debug: `build/app/outputs/flutter-apk/app-debug.apk`.
Target minimum Android API 24, mengikuti plugin kamera/galeri.
Font memakai fallback sans-serif Android (Roboto).

Lihat [IMPLEMENTATION.md](IMPLEMENTATION.md) untuk cakupan, keputusan desain,
hasil pengujian, batasan, dan kebutuhan tahap integrasi berikutnya.
