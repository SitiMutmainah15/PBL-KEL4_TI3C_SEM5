# PBL-KEL4_TI3C_SEM5

## Arsitektur yang Digunakan

EcoPlant menggunakan Flutter dengan Firebase sebagai layanan backend dan penyimpanan data.
Backend Laravel telah dihapus dari repositori dan tidak digunakan lagi. Inferensi model berjalan langsung di perangkat (*on-device*) menggunakan Random Forest (scikit-learn) yang diekspor ke `forest.json`.

Inisialisasi Firebase Core telah diterapkan pada aplikasi (`Firebase.initializeApp` dengan `firebase_options.dart` dan `google-services.json`). Layanan backend spesifik (seperti Cloud Firestore / Cloud Storage untuk riwayat deteksi) masih dalam proses integrasi bertahap. Lihat [arsitektur](doc/architecture.md) untuk detail rencana sistem.

Teks pendamping pada layar hasil (ringkasan kondisi, penanganan awal, dan saran memotret ulang) dibuat oleh model bahasa Groq. Aplikasi memanggil Groq langsung dari HP, jadi tidak ada backend yang perlu dijalankan. Foto pembanding diambil dari split uji dataset latih, tiga contoh per kelas.

## Menjalankan Aplikasi

```powershell
Copy-Item .env.example .env   # lalu isi GROQ_API_KEY
.\scripts\run-direct.ps1          # build debug, pasang ke HP, jalankan
.\scripts\run-direct.ps1 -Release # build APK release
```

Skrip membaca `GROQ_API_KEY` dari `.env` di root proyek dan menyuntikkannya lewat `--dart-define`, jadi kunci tidak ditulis di kode sumber dan tidak di-commit. Setelah APK terpasang, HP cukup tersambung ke internet tanpa laptop menyala.

Kunci tetap tertanam di dalam APK dan bisa diambil oleh siapa pun yang membongkarnya. Bagikan APK hanya ke anggota kelompok atau penguji, jangan secara publik.

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
│   │   ├── images/             # Aset gambar aplikasi
│   │   ├── models/             # Model forest.json, label, dan metadata
│   │   └── references/         # Foto pembanding per kelas dari dataset
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
│   ├── artifacts_rf/           # Hasil training: forest.json, label, metadata, evaluasi
│   ├── dataset/                # Split lama 60:20:20; sumber 12 foto pembanding aplikasi
│   ├── dataset_retrain/        # Dataset latih siap pakai (split grup 60:20:20)
│   ├── OriginalSet/            # Dataset mentah asli BananaLSD
│   │   ├── cordana/            # Kelas cordana
│   │   ├── healthy/            # Kelas daun sehat
│   │   ├── pestalotiopsis/     # Kelas pestalotiopsis
│   │   └── sigatoka/           # Kelas sigatoka
│   └── train_random_forest.py  # Skrip pelatihan Random Forest + ekspor forest.json
└── README.md                   # Dokumentasi utama proyek
```

Folder lokal seperti `ecoplant/.dart_tool/`, `ecoplant/build/`, dan `.venv/` tidak ditampilkan di atas karena berisi cache, virtual environment, hasil build, atau dependensi lokal.
