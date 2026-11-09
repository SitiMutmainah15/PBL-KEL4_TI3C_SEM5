Jalankan `training/train_random_forest.py --copy-to ecoplant/assets/models` untuk menghasilkan:

- `forest.json`
- `labels.json`
- `model_metadata.json`

Model menerima 48 fitur: RGB 64×64 (interpolasi nearest), histogram 16 bin per kanal
dengan `density=True`. Ekstraksi ada di `lib/features/detection/leaf_features.dart`
dan harus tetap sama dengan `leaf_features()` di skrip training. Urutan output
mengikuti `labels.json`.
