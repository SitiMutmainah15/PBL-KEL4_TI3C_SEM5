# Backend EcoPlant

Layanan kecil yang menyembunyikan kunci Groq dari aplikasi Flutter. Aplikasi mengirim foto,
label hasil model TFLite, dan skor. Backend meminta satu jawaban JSON ke Groq lalu
mengembalikan teks siap tampil.

## Menjalankan

```powershell
cd backend
..\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
# isi GROQ_API_KEY di .env
..\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8080
```

Cek kesiapan:

```powershell
curl http://127.0.0.1:8080/health
```

`captionReady: false` berarti `GROQ_API_KEY` belum terbaca. Endpoint caption akan menjawab
503, bukan menjawab dengan teks karangan.

## Kontrak

`POST /v1/caption`, `multipart/form-data`

| Field | Tipe | Keterangan |
| --- | --- | --- |
| `image` | berkas | JPEG, PNG, atau WEBP, maksimal 8 MB |
| `label` | teks | `healthy`, `sigatoka`, `cordana`, atau `pestalotiopsis` |
| `confidence` | angka | 0 sampai 1, skor keluaran TFLite |
| `locale` | teks | `id` atau `en` |

Jawaban 200:

```json
{
  "labelTerdeteksi": "sigatoka",
  "gambarSesuai": true,
  "ringkasan": "...",
  "penanganan": "...",
  "saranFoto": "...",
  "cached": false
}
```

Kode galat: 415 foto tidak valid, 422 label atau confidence salah, 429 batas Groq,
502 Groq gagal, 503 kunci belum diisi, 504 Groq terlalu lama.

## Catatan

- Satu permintaan Groq menghasilkan ketiga field sekaligus. Model tidak diminta menilai
  ulang confidence dan tidak diberi izin menyebut dosis atau merek pestisida.
- Hasil disimpan di cache memori berdasarkan hash foto dan label, jadi memeriksa foto yang
  sama tidak memakai kuota Groq lagi.
- Jangan pakai `--reload` di produksi. Kunci hanya ada di `.env` yang tidak di-commit.
- Pengujian: `..\.venv\Scripts\python.exe -m pytest` dari folder `backend`.
