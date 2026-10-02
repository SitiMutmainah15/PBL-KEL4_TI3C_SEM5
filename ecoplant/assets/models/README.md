Jalankan training/train_banana.ipynb sampai tahap penyalinan aset untuk menghasilkan:

- model.tflite
- labels.json
- model_metadata.json

Model harus menerima RGB float32 [1, 224, 224, 3] dalam rentang 0–255.
Normalisasi berada di dalam model. Urutan output mengikuti labels.json.
