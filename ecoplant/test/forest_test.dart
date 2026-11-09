import 'dart:convert';
import 'dart:io';

import 'package:ecoplant/features/detection/forest.dart';
import 'package:ecoplant/features/detection/leaf_features.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> oneTree() => {
  'features': 2,
  'labels': ['A', 'B'],
  'trees': [
    {
      'f': [0, -2, -2],
      't': [0.5, 0, 0],
      'l': [1, -1, -1],
      'r': [2, -1, -1],
      'p': [
        [0, 0],
        [1.0, 0.0],
        [0.0, 1.0],
      ],
    },
  ],
};

void main() {
  test('left branch wins when feature is at or below the threshold', () {
    expect(predictForest(oneTree(), [0.4, 0.9]), [1.0, 0.0]);
  });

  test('right branch wins above the threshold', () {
    expect(predictForest(oneTree(), [0.6, 0.9]), [0.0, 1.0]);
  });

  test('rejects a feature vector of the wrong size', () {
    expect(() => predictForest(oneTree(), [0.1]), throwsFormatException);
  });

  test('shipped forest scores sum to one', () {
    final forest =
        jsonDecode(File('assets/models/forest.json').readAsStringSync())
            as Map<String, dynamic>;
    final scores = predictForest(forest, List<double>.filled(48, 1.0));
    expect(scores.length, 4);
    expect(scores.every((v) => v >= 0 && v <= 1), isTrue);
    expect(scores.reduce((a, b) => a + b), closeTo(1, 1e-6));
  });

  test('dart histogram and traversal match the python reference', () {
    final parity =
        jsonDecode(
              File('../training/artifacts_rf/parity.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final expected = (parity['features'] as List).cast<num>();
    final features = extractHistogram(
      File('../${parity['image']}').readAsBytesSync(),
    );
    for (var i = 0; i < featureSize; i++) {
      expect(features[i], closeTo(expected[i], 1e-6), reason: 'fitur $i');
    }
    final forest =
        jsonDecode(File('assets/models/forest.json').readAsStringSync())
            as Map<String, dynamic>;
    final labels = (forest['labels'] as List).cast<String>();
    final scores = predictForest(forest, features);
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    expect(labels[best], parity['expected']);
  });
}
