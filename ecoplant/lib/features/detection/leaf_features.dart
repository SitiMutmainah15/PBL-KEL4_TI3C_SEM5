import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'detection.dart';

const int featureBins = 16;
const int featureSize = featureBins * 4;
const int featureSide = 64;

// Harus sama dengan leaf_features() di training/train_random_forest.py: RGB 64x64 nearest,
// histogram 16 bin per kanal + hue, density=True.
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
  const hueOffset = featureBins * 3;
  for (final pixel in source) {
    bins[pixel.r ~/ 16] += 1;
    bins[featureBins + pixel.g ~/ 16] += 1;
    bins[featureBins * 2 + pixel.b ~/ 16] += 1;

    // Hue 0-1 dari RGB; piksel abu-abu (delta 0) masuk bin 0 seperti numpy.
    final maxC = math.max(pixel.r, math.max(pixel.g, pixel.b));
    final delta = maxC - math.min(pixel.r, math.min(pixel.g, pixel.b));
    var hue = 0.0;
    if (delta > 0) {
      // Urutan R, G, B harus sama dengan hue_histogram() di Python.
      hue = maxC == pixel.r
          ? (pixel.g - pixel.b) / delta
          : maxC == pixel.g
          ? (pixel.b - pixel.r) / delta + 2
          : (pixel.r - pixel.g) / delta + 4;
      hue = (hue % 6) / 6;
    }
    final hueBin = math.min((hue * featureBins).floor(), featureBins - 1);
    bins[hueOffset + hueBin] += 1;
  }
  // density=True pada np.histogram: count * jumlah_bin / jumlah_piksel.
  const scale = featureBins / (featureSide * featureSide);
  for (var i = 0; i < featureSize; i++) {
    bins[i] *= scale;
  }
  return bins;
}
