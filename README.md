# PBL-KEL4_TI3C_SEM5

## Arsitektur yang Digunakan

EcoPlant menggunakan Flutter dengan Firebase sebagai layanan backend dan penyimpanan data.
Backend Laravel telah dihapus dari repositori dan tidak digunakan lagi. Inferensi model direncanakan berjalan langsung di perangkat (*on-device*) menggunakan TensorFlow Lite (TFLite).

Inisialisasi Firebase Core telah diterapkan pada aplikasi (`Firebase.initializeApp` dengan `firebase_options.dart` dan `google-services.json`). Layanan backend spesifik (seperti Cloud Firestore / Cloud Storage untuk riwayat deteksi) dan model TFLite saat ini masih dalam proses integrasi bertahap. Lihat [arsitektur](doc/architecture.md) untuk detail rencana sistem.

Teks pendamping pada layar hasil (ringkasan kondisi, penanganan awal, dan saran memotret ulang) dibuat oleh model bahasa Groq. Kunci Groq tidak disimpan di aplikasi. Aplikasi mengirim foto, label, dan skor ke layanan `backend/` yang memegang kunci tersebut. Foto pembanding diambil dari split uji dataset latih, tiga contoh per kelas.

## Menjalankan Backend Caption

```powershell
cd backend
..\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env   # lalu isi GROQ_API_KEY
..\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8080
```

Emulator Android menjangkau host lewat `http://10.0.2.2:8080`, yang sudah menjadi nilai bawaan. Untuk perangkat fisik, bangun aplikasi dengan
`--dart-define=ECOPLANT_API_BASE_URL=http://<ip-komputer>:8080`. Rincian kontrak ada di [backend/README.md](backend/README.md).

Skrip `scripts/run-device.ps1` mengisi alamat itu otomatis dari IP LAN komputer, membangun APK, memasangnya ke HP yang tersambung, lalu menjalankan aplikasi:

```powershell
.\scripts\run-device.ps1
```

## Struktur Folder

Berikut struktur utama proyek. Folder dependensi, cache, hasil build, dan metadata Git tidak dirinci.

```text
PBL-KEL4_TI3C_SEM5/
├── .vscode/                    # Konfigurasi workspace VS Code
├── backend/                    # Layanan caption Groq untuk aplikasi Flutter
│   ├── app/                    # Kode FastAPI (config, Groq, validasi gambar)
│   ├── tests/                  # Pengujian endpoint dan validasi unggahan
│   ├── .env.example            # Contoh konfigurasi, kunci asli ada di .env
│   ├── README.md               # Cara menjalankan dan kontrak endpoint
│   └── requirements.txt        # Dependensi Python backend
├── doc/                        # Dokumentasi proyek
│   └── architecture.md         # Dokumentasi arsitektur sistem
├── ecoplant/                   # Aplikasi Flutter EcoPlant
│   ├── android/                # Proyek platform Android (konfigurasi Google Services & Gradle)
│   ├── assets/                 # Folder aset aplikasi
│   │   ├── images/             # Aset gambar aplikasi
│   │   ├── models/             # Model TFLite, label, dan metadata
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
