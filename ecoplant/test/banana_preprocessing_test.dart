import 'dart:typed_data';

import 'package:ecoplant/features/detection/detection.dart';
import 'package:ecoplant/features/detection/tflite_detection_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('RGB stays in 0-255 and resize uses floor source coordinates', () {
    final source = img.Image(width: 3, height: 1);
    source.setPixelRgb(0, 0, 255, 0, 0);
    source.setPixelRgb(1, 0, 0, 128, 0);
    source.setPixelRgb(2, 0, 0, 0, 64);
    final input = prepareBananaInput(Uint8List.fromList(img.encodePng(source)));
    expect(input.length, 224 * 224 * 3);
    expect(input.sublist(0, 3), [255.0, 0.0, 0.0]);
    expect(input.sublist(74 * 3, 75 * 3), [255.0, 0.0, 0.0]);
    expect(input.sublist(75 * 3, 76 * 3), [0.0, 128.0, 0.0]);
    expect(input.sublist(input.length - 3), [0.0, 0.0, 64.0]);
  });

  test('invalid image gives a readable failure', () {
    expect(
      () => prepareBananaInput(Uint8List(0)),
      throwsA(isA<ServiceFailure>()),
    );
  });
}
