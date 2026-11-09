import 'dart:typed_data';

import 'package:ecoplant/features/detection/detection.dart';
import 'package:ecoplant/features/detection/leaf_features.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('half red half green fills the expected bins', () {
    final source = img.Image(width: 64, height: 64);
    img.fillRect(
      source,
      x1: 0,
      y1: 0,
      x2: 63,
      y2: 63,
      color: img.ColorRgb8(255, 0, 0),
    );
    img.fillRect(
      source,
      x1: 32,
      y1: 0,
      x2: 63,
      y2: 63,
      color: img.ColorRgb8(0, 128, 0),
    );
    final features = extractHistogram(
      Uint8List.fromList(img.encodePng(source)),
    );
    expect(features.length, featureSize);
    expect(features[0], closeTo(8, 1e-9)); // R=0, separuh kanan
    expect(features[15], closeTo(8, 1e-9)); // R=255, separuh kiri
    expect(features[16], closeTo(8, 1e-9)); // G=0
    expect(features[24], closeTo(8, 1e-9)); // G=128 -> bin 8
    expect(features[32], closeTo(16, 1e-9)); // B=0 di semua piksel
  });

  test('single colour image peaks in the last bin', () {
    final source = img.Image(width: 64, height: 64);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));
    final features = extractHistogram(
      Uint8List.fromList(img.encodePng(source)),
    );
    expect(features[15], closeTo(16, 1e-9));
    expect(features[31], closeTo(16, 1e-9));
    expect(features[47], closeTo(16, 1e-9));
  });

  test('tiny image is upscaled to 64x64', () {
    final source = img.Image(width: 2, height: 2);
    img.fill(source, color: img.ColorRgb8(10, 20, 30));
    final features = extractHistogram(
      Uint8List.fromList(img.encodePng(source)),
    );
    expect(features.length, featureSize);
    for (var channel = 0; channel < 3; channel++) {
      final sum = features
          .sublist(channel * featureBins, (channel + 1) * featureBins)
          .reduce((a, b) => a + b);
      expect(sum, closeTo(16, 1e-9));
    }
  });

  test('invalid image gives a readable failure', () {
    expect(
      () => extractHistogram(Uint8List(0)),
      throwsA(isA<ServiceFailure>()),
    );
  });
}
