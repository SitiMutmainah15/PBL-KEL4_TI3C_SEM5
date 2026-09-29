# EcoPlant AI

Aplikasi Flutter Android untuk identifikasi awal kondisi daun pisang.
Tahap saat ini: UI dan service stub, sesuai persetujuan pengguna.
Analisis TFLite dan penyimpanan Firebase belum dihubungkan; tidak ada prediksi
atau riwayat palsu pada aplikasi.

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
