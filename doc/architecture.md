# ARCHITECTURE — EcoPlant AI

## 1. Architecture Goals

Arsitektur EcoPlant AI harus:
- sederhana untuk proyek PBL,
- mudah diuji,
- memisahkan UI, domain logic, data, dan ML inference,
- menjalankan model di perangkat,
- memungkinkan penyimpanan riwayat,
- tidak menambah kompleksitas yang tidak diperlukan.

---

## 2. Technology Stack

### Mobile
- Flutter
- Dart

### State Management
- Riverpod

### ML Runtime
- Random Forest (scikit-learn) diekspor ke `forest.json`
- Traversal pohon di Dart (`lib/features/detection/forest.dart`), tanpa runtime native

### Backend / Persistence
- Firebase, sesuai keputusan pengguna pada 29 September 2026.
  - Rencana: Cloud Firestore untuk metadata riwayat.
  - Rencana: Cloud Storage for Firebase bila gambar disimpan di cloud.
- Tidak menggunakan backend Laravel.
- Status implementasi: repository riwayat masih stub; konfigurasi dan integrasi
  Firebase belum tersedia di aplikasi.

### Caption Service
- Aplikasi Flutter memanggil Groq API langsung (`GroqCaptionService`), tanpa backend perantara.
- Groq API dengan model visi `qwen/qwen3.8-27b` sebagai penyusun teks pendamping.
- Kunci Groq disimpan di `.env` root proyek dan disuntikkan saat build lewat `--dart-define` oleh `scripts/run-direct.ps1`. Kunci ikut tertanam di APK, jadi APK tidak dibagikan secara publik.
- Caption bukan hasil analisis utama. Label dan skor tetap berasal dari Random Forest.

### ML Development
- Python
- Python
- scikit-learn (Random Forest, 200 pohon)
- Export `forest.json` + `labels.json`

---

## 3. High-Level Architecture

```text
┌───────────────────────────────────────────────┐
│                 Flutter UI                    │
│ Home | Scan | Result | History | Detail       │
└───────────────────────┬───────────────────────┘
                        │
┌───────────────────────▼───────────────────────┐
│              Presentation / Riverpod          │
│ screen state | actions | async state          │
└───────────────┬───────────────────┬───────────┘
                │                   │
┌───────────────▼──────────┐  ┌─────▼───────────┐
│     Detection Domain     │  │  History Domain │
│ validate input           │  │ save / fetch    │
│ map result               │  │ open detail     │
└───────────────┬──────────┘  └─────┬───────────┘
                │                   │
┌───────────────▼──────────┐  ┌─────▼───────────┐
│      ML Data Source      │  │ Firebase Source │
│ preprocessing            │  │ db / storage    │
│ forest.json traversal    │  │ repository      │
└───────────────┬──────────┘  └─────────────────┘
                │
┌───────────────▼──────────┐
│ forest.json + labels     │
└──────────────────────────┘

┌───────────────────────────────────────────────┐
│      GroqCaptionService (di aplikasi)         │
│ perkecil foto | prompt | cache per hasil      │
└───────────────────────┬───────────────────────┘
                        │ HTTPS
┌───────────────────────▼───────────────────────┐
│           Groq API (model visi)               │
│ ringkasan | penanganan | saran foto           │
└───────────────────────────────────────────────┘
```

Teks pendamping pada layar hasil datang langsung dari Groq. Bila Groq tidak
tersedia, layar tetap menampilkan hasil Random Forest dan menawarkan keterangan umum yang
ditulis manusia. Foto pembanding per kelas dibundel sebagai aset dari split uji dataset.

---

## 4. Architectural Style

Gunakan **feature-first + layered separation**.

Tidak perlu menerapkan clean architecture secara dogmatis dengan terlalu banyak abstraction. Prinsip utamanya:

- UI tidak menelusuri pohon Random Forest langsung.
- UI tidak melakukan query Firebase langsung.
- Repository/service tidak mengatur layout.
- ML preprocessing berada di satu tempat.
- Mapping class label berada di satu source of truth.

---

## 5. Recommended Project Structure

```text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│       ├── app_colors.dart
│       ├── app_spacing.dart
│       ├── app_radius.dart
│       └── app_theme.dart
│
├── core/
│   ├── errors/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── home/
│   │   └── presentation/
│   │
│   ├── detection/
│   │   ├── domain/
│   │   │   ├── detection_result.dart
│   │   │   └── disease_class.dart
│   │   ├── data/
│   │   │   ├── ml_inference_service.dart
│   │   │   ├── image_preprocessor.dart
│   │   │   └── disease_info_repository.dart
│   │   └── presentation/
│   │       ├── scan_page.dart
│   │       ├── result_page.dart
│   │       └── detection_controller.dart
│   │
│   └── history/
│       ├── domain/
│       ├── data/
│       │   ├── history_repository.dart
│       │   └── firebase_history_repository.dart
│       └── presentation/
│           ├── history_page.dart
│           └── history_detail_page.dart
│
└── main.dart

assets/
├── ml/
│   ├── forest.json
│   ├── labels.json
│   └── model_metadata.json
├── data/
│   └── disease_info.json
└── images/
```

---

## 6. Detection Pipeline

```text
Camera/Gallery
      ↓
Image Decode
      ↓
Validate readable image
      ↓
Resize 64×64 nearest
      ↓
Ekstraksi 48 fitur histogram RGB 0–1
      ↓
Traversal 200 pohon (forest.json)
      ↓
Rata-rata probabilitas daun
      ↓
Label mapping
      ↓
Top prediction + confidence
      ↓
DetectionResult
      ↓
Result UI
```

---

## 7. ML Contract

ML team dan Flutter team harus sepakat pada contract berikut.

### Model asset
- `forest.json` (pohon + threshold + probabilitas daun)
- `model_metadata.json` (dokumentasi versi dan kontrak input)

### Labels
`labels.json` contoh:

```json
[
  "Healthy",
  "Sigatoka",
  "Cordana",
  "Pestalotiopsis"
]
```

Urutan ini **harus sama dengan output index model final**.

### Input contract
Dokumentasikan:
- width,
- height,
- channels,
- rentang piksel,
- cara ekstraksi fitur.

Nilai yang dipakai sekarang (`model_metadata.json`):
- 64×64 RGB, interpolasi nearest,
- rentang 0–1 (`piksel / 255`),
- histogram 16 bin per kanal dengan `density=True`,
- 48 fitur, urutan R(16), G(16), B(16).

Implementasi **tidak boleh mengasumsikan formula** lain sampai pipeline training final dikunci.

### Output contract
Dokumentasikan:
- panjang vektor probabilitas (= jumlah label),
- probabilitas rata-rata 200 pohon, jumlah 1,
- label order,
- model version (`version` di `forest.json`).

---

## 8. Model Versioning

Setiap model final harus memiliki metadata:

```text
model_name: EcoPlant Banana Leaf Classifier
model_version: banana-rf-<hash>
architecture: Random Forest (200 pohon, fitur histogram RGB)
classes: 4
input: 64x64 RGB, 48 fitur histogram
trained_at: YYYY-MM-DD
dataset: BananaLSD (split grup dataset_retrain)
```

Jika model berubah:
- update metadata,
- update test results,
- pastikan Flutter mapping tetap sesuai.

---

## 9. State Management

Gunakan Riverpod untuk state yang benar-benar aplikasi butuhkan.

### Detection state

```text
idle
selectingImage
imageReady
processing
success
failure
```

State minimal membawa:
- selected image,
- detection result,
- error message.

### History state
- loading
- data
- empty
- error

Jangan menyimpan seluruh business logic di Widget.

---

## 10. Firebase Design

Firebase dipilih sebagai layanan penyimpanan. Desain berikut merupakan rencana integrasi, belum implementasi aktif.

### Rencana koleksi Cloud Firestore: `detections`

```text
id                string (document ID)
user_id           string (Firebase Auth UID, sesuai keputusan identitas)
predicted_class   string
confidence        number
image_url         string nullable
model_version     string
created_at        timestamp
```

### Important
- Jangan simpan service account private key atau kredensial Admin SDK di aplikasi.
- Gunakan environment/config yang aman.
- Jika menggunakan per-user cloud history, gunakan Firebase Authentication + Security Rules yang membatasi akses berdasarkan UID.
- Jangan menambahkan layar login hanya untuk memenuhi kebutuhan teknis tanpa keputusan produk.

### Recommended MVP behavior
- Inference tetap on-device.
- Jika penyimpanan cloud gagal, tampilkan hasil seperti biasa.
- Save failure bersifat non-blocking.

---

## 11. Authentication Decision

Proposal tidak menetapkan fitur login.

Karena itu:
- UI login **bukan bagian MVP secara default**.
- Jika cloud history harus dipisahkan per pengguna, gunakan pendekatan autentikasi paling ringan yang disetujui tim, misalnya anonymous auth.
- Jika tim memutuskan tanpa auth, jangan membuat data cloud menjadi publik tanpa kontrol akses yang jelas.

Keputusan ini harus dikunci sebelum implementasi persistence final.

---

## 12. Disease Information Source

Informasi penyakit dan saran awal sebaiknya disimpan sebagai data statis yang terkurasi.

Contoh:

```json
{
  "Sigatoka": {
    "title": "Sigatoka",
    "summary": "...",
    "generalHandling": [
      "...",
      "..."
    ],
    "disclaimer": "..."
  }
}
```

Jangan menghasilkan saran penyakit secara realtime menggunakan LLM.

---

## 13. Dependency Rules

### Allowed direction

```text
presentation → domain → data abstraction
data implementation → external SDK
```

### Forbidden
- Widget → Firebase SDK langsung.
- Widget → service inferensi Random Forest langsung.
- Result screen melakukan preprocessing.
- History repository memanggil model ML.
- Domain model bergantung pada widget/UI.

---

## 14. Error Handling

Gunakan error domain yang dapat dipetakan ke user-friendly message.

Contoh:
- `CameraPermissionDenied`
- `ImageReadFailed`
- `ModelLoadFailed`
- `InferenceFailed`
- `HistorySaveFailed`
- `HistoryLoadFailed`

UI tidak perlu menampilkan stack trace.

---

## 15. Offline Behavior

### Must work offline
- membuka app,
- memilih foto lokal,
- mengambil foto,
- preprocessing,
- inference Random Forest,
- menampilkan hasil dan disease info statis.

### May require network
- menyimpan riwayat ke Firebase,
- mengambil riwayat cloud,
- membuka image URL cloud.

Jangan membuat koneksi internet sebagai syarat menjalankan klasifikasi.

---

## 16. Security

- Jangan commit `.env`.
- Jangan commit secret atau service account private key.
- Security Rules wajib membatasi akses data pengguna di Cloud Firestore dan Cloud Storage.
- Validasi tipe dan ukuran image sebelum upload.
- Simpan data minimum yang diperlukan.
- Hindari mencetak token atau secret ke log.

---

## 17. Performance

### Image
- Jangan menyimpan bitmap full resolution di state lebih lama dari yang diperlukan.
- Resize sebelum inference.
- Compress untuk upload history bila diperlukan.

### ML
- Load interpreter sekali dan reuse bila aman.
- Dispose interpreter saat aplikasi/service selesai.
- Ukur inference time pada real device.

### UI
- Jangan menjalankan pekerjaan berat sinkron di build method.
- Hindari rebuild besar yang tidak diperlukan.

---

## 18. Testing Strategy

### Unit Test
- label mapping,
- confidence formatting,
- disease info mapping,
- result serialization,
- repository behavior.

### Widget Test
- Home CTA.
- Scan state.
- Result rendering.
- Empty history.
- Error state.

### Integration Test
- pick image → analyze → result.
- save result → history → detail.

### ML Validation
Di luar Flutter:
- accuracy,
- precision,
- recall,
- F1-score,
- confusion matrix.

### Device Test
- camera permission,
- gallery permission,
- low light image,
- rotated image,
- high-resolution image,
- no network,
- slow network.

---

## 19. Build and Release Gate

Sebelum merge ke main:

```bash
dart format .
flutter analyze
flutter test
```

Jika project menggunakan generated code:
- jalankan generator yang sesuai,
- pastikan generated files konsisten.

Sebelum demo:
- model asset tersedia,
- label mapping tervalidasi,
- build release berhasil,
- kamera dan galeri diuji di real device,
- Firebase configuration valid,
- tidak ada secret di repository.

---

## 20. Architecture Decision Guardrails

Coding agent tidak boleh:
- mengganti Riverpod tanpa keputusan tim,
- mengganti Random Forest dengan server inference,
- mengganti Firebase tanpa keputusan tim,
- menambah backend baru,
- mengubah class label model,
- mengubah preprocessing tanpa bukti dari pipeline training,
- membuat arsitektur terlalu kompleks untuk kebutuhan MVP.

Jika ditemukan kebutuhan yang bertentangan dengan dokumen ini, buat catatan keputusan terlebih dahulu sebelum implementasi.


## Referensi integrasi Firebase

- [Konfigurasi Firebase untuk Flutter](https://firebase.google.com/docs/flutter/setup).
- [Cloud Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started).
