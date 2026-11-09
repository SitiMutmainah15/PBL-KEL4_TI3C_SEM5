import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'detection.dart';

const int featureBins = 16;
const int featureSize = featureBins * 3;
const int featureSide = 64;

// Harus sama dengan leaf_features() di training/train_random_forest.py: RGB 64x64 nearest, 16 bin per kanal, density=True.
Float64List extractHistogram(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const ServiceFailure('Foto gagal dibaca. Gunakan JPEG atau PNG.');
  }
  if (decoded == null) {
    throw const ServiceFailure('Foto gagal dibaca. Gunakan JPEG atau PNG.');
  }
  final source = img.copyResize(
    img.bakeOrientation(decoded).convert(numChannels: 3),
    width: featureSide,
    height: featureSide,
    interpolation: img.Interpolation.nearest,
  );
  final bins = Float64List(featureSize);
  for (final pixel in source) {
    bins[pixel.r ~/ 16] += 1;
    bins[featureBins + pixel.g ~/ 16] += 1;
    bins[featureBins * 2 + pixel.b ~/ 16] += 1;
  }
  // density=True pada np.histogram: count * jumlah_bin / jumlah_piksel.
  const scale = featureBins / (featureSide * featureSide);
  for (var i = 0; i < featureSize; i++) {
    bins[i] *= scale;
  }
  return bins;
}
