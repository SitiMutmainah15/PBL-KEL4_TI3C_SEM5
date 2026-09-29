# PBL-KEL5_TI3C_SEM5

## Arsitektur yang digunakan

EcoPlant menggunakan Flutter dengan Firebase sebagai layanan penyimpanan data.
Backend Laravel tidak digunakan. Inferensi model direncanakan berjalan di perangkat
menggunakan TensorFlow Lite.

Integrasi Firebase belum diimplementasikan: aplikasi saat ini masih menggunakan
stub untuk analisis dan penyimpanan riwayat. Lihat [arsitektur](doc/architecture.md)
untuk rencana integrasi. Folder `laravel_api/` masih disimpan sebagai kode lama,
bukan bagian dari aplikasi aktif dan tidak perlu dijalankan.

## Struktur Folder

Berikut struktur utama proyek. Folder dependensi, cache, hasil build, dan metadata Git tidak dirinci.

```text
PBL-KEL4_TI3C_SEM5/
├── .vscode/                    # Konfigurasi workspace VS Code
├── doc/                        # Dokumentasi proyek
│   └── architecture.md         # Dokumentasi arsitektur
├── ecoplant/                   # Aplikasi Flutter EcoPlant
│   ├── android/                # Proyek platform Android
│   ├── assets/                 # Folder aset aplikasi
│   │   └── images/             # Aset gambar
│   ├── ios/                    # Proyek platform iOS
│   ├── lib/                    # Kode sumber Dart
│   │   ├── core/               # Tema dan widget bersama
│   │   ├── features/           # Modul fitur aplikasi
│   │   │   ├── detection/      # Model deteksi dan layar hasil
│   │   │   ├── history/        # Layar dan repository riwayat
│   │   │   ├── home/           # Layar beranda
│   │   │   └── scan/           # Layar, controller, dan kamera pemindaian
│   │   ├── app.dart            # Konfigurasi aplikasi
│   │   └── main.dart           # Titik masuk aplikasi
│   ├── linux/                  # Proyek platform Linux
│   ├── macos/                  # Proyek platform macOS
│   ├── test/                   # Pengujian aplikasi
│   ├── web/                    # Proyek platform web
│   ├── windows/                # Proyek platform Windows
│   ├── analysis_options.yaml   # Aturan analisis kode Dart
│   ├── IMPLEMENTATION.md       # Catatan implementasi
│   ├── pubspec.yaml            # Dependensi dan konfigurasi Flutter
│   └── README.md               # Panduan aplikasi Flutter
├── laravel_api/                # Kode lama, tidak digunakan
├── qa/                         # Folder pemeriksaan kualitas (saat ini kosong)
├── training/                   # Pelatihan model
│   ├── artifacts/              # Folder artefak pelatihan
│   ├── OriginalSet/            # Folder dataset
│   │   ├── cordana/            # Kelas cordana
│   │   ├── healthy/            # Kelas daun sehat
│   │   ├── pestalotiopsis/     # Kelas pestalotiopsis
│   │   └── sigatoka/           # Kelas sigatoka
│   └── train_banana.py         # Skrip pelatihan model daun pisang
└── README.md                   # Dokumentasi utama proyek
```

Folder lokal seperti `ecoplant/.dart_tool/`, `ecoplant/build/`, dan `laravel_api/vendor/` tidak ditampilkan di atas karena berisi cache, hasil build, atau dependensi.
