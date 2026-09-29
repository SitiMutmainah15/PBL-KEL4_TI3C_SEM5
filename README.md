# PBL-KEL4_TI3C_SEM5

## Arsitektur yang Digunakan

EcoPlant menggunakan Flutter dengan Firebase sebagai layanan backend dan penyimpanan data.
Backend Laravel telah dihapus dari repositori dan tidak digunakan lagi. Inferensi model direncanakan berjalan langsung di perangkat (*on-device*) menggunakan TensorFlow Lite (TFLite).

Inisialisasi Firebase Core telah diterapkan pada aplikasi (`Firebase.initializeApp` dengan `firebase_options.dart` dan `google-services.json`). Layanan backend spesifik (seperti Cloud Firestore / Cloud Storage untuk riwayat deteksi) dan model TFLite saat ini masih dalam proses integrasi bertahap. Lihat [arsitektur](doc/architecture.md) untuk detail rencana sistem.

## Struktur Folder

Berikut struktur utama proyek. Folder dependensi, cache, hasil build, dan metadata Git tidak dirinci.

```text
PBL-KEL4_TI3C_SEM5/
├── .vscode/                    # Konfigurasi workspace VS Code
├── doc/                        # Dokumentasi proyek
│   └── architecture.md         # Dokumentasi arsitektur sistem
├── ecoplant/                   # Aplikasi Flutter EcoPlant
│   ├── android/                # Proyek platform Android (konfigurasi Google Services & Gradle)
│   ├── assets/                 # Folder aset aplikasi
│   │   └── images/             # Aset gambar aplikasi
│   ├── ios/                    # Proyek platform iOS
│   ├── lib/                    # Kode sumber Dart
│   │   ├── core/               # Tema, konstanta, dan widget bersama
│   │   ├── features/           # Modul fitur aplikasi
│   │   │   ├── detection/      # Model domain deteksi dan layar hasil
│   │   │   ├── history/        # Layar dan repository riwayat
│   │   │   ├── home/           # Layar beranda
│   │   │   └── scan/           # Layar, controller, dan kamera pemindaian
│   │   ├── app.dart            # Konfigurasi utama aplikasi Flutter
│   │   ├── firebase_options.dart # Konfigurasi platform Firebase
│   │   └── main.dart           # Titik masuk aplikasi (inisialisasi Firebase & Riverpod)
│   ├── linux/                  # Proyek platform Linux
│   ├── macos/                  # Proyek platform macOS
│   ├── test/                   # Pengujian unit & widget aplikasi
│   ├── web/                    # Proyek platform web
│   ├── windows/                # Proyek platform Windows
│   ├── analysis_options.yaml   # Aturan linting dan analisis kode Dart
│   ├── firebase.json           # Konfigurasi Firebase CLI
│   ├── IMPLEMENTATION.md       # Catatan implementasi teknis UI & arsitektur
│   ├── pubspec.yaml            # Dependensi dan metadata proyek Flutter
│   └── README.md               # Panduan aplikasi Flutter EcoPlant
├── qa/                         # Folder pemeriksaan kualitas
├── training/                   # Pelatihan model machine learning
│   ├── artifacts/              # Artefak data (laporan QA & manifest split dataset)
│   │   ├── data_qa_report.json # Laporan pemeriksaan integritas data & deduplikasi
│   │   └── split_manifest.json # Daftar pembagian dataset per kelas & split
│   ├── dataset/                # Dataset terbagi siap latih (split 60:20:20)
│   │   ├── train/              # Data latih (cordana, healthy, pestalotiopsis, sigatoka)
│   │   ├── val/                # Data validasi
│   │   └── test/               # Data uji
│   ├── OriginalSet/            # Dataset mentah asli BananaLSD
│   │   ├── cordana/            # Kelas cordana
│   │   ├── healthy/            # Kelas daun sehat
│   │   ├── pestalotiopsis/     # Kelas pestalotiopsis
│   │   └── sigatoka/           # Kelas sigatoka
│   └── train_banana.ipynb      # Jupyter Notebook pelatihan model daun pisang
└── README.md                   # Dokumentasi utama proyek
```

Folder lokal seperti `ecoplant/.dart_tool/`, `ecoplant/build/`, dan `.venv/` tidak ditampilkan di atas karena berisi cache, virtual environment, hasil build, atau dependensi lokal.
