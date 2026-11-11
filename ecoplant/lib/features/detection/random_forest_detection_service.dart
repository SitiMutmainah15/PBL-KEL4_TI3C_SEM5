import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'detection.dart';
import 'forest.dart';
import 'leaf_features.dart';

class RandomForestDetectionService implements DetectionService {
  @override
  Future<DetectionResult> analyze(String imagePath) async {
    try {
      final labels =
          (jsonDecode(
                    await rootBundle.loadString('assets/models/labels.json'),
                  )
                  as List)
              .cast<String>();
      final forest =
          jsonDecode(await rootBundle.loadString('assets/models/forest.json'))
              as Map<String, dynamic>;
      final classes = labels
          .map(
            (label) =>
                LeafClass.values.firstWhere((value) => value.label == label),
          )
          .toList();
      if (classes.length != 4 ||
          classes.toSet().length != 4 ||
          forest['features'] != featureSize ||
          !listEquals((forest['labels'] as List).cast<String>(), labels)) {
        throw const FormatException('Model labels do not match the app.');
      }
      final features = await compute(
        extractHistogram,
        await File(imagePath).readAsBytes(),
      );
      final scores = predictForest(forest, features);
      if (scores.any((v) => !v.isFinite || v < 0 || v > 1)) {
        throw const FormatException('Invalid model probabilities.');
      }
      var best = 0;
      for (var i = 1; i < scores.length; i++) {
        if (scores[i] > scores[best]) best = i;
      }
      final now = DateTime.now();
      return DetectionResult(
        id: now.microsecondsSinceEpoch.toString(),
        imagePath: imagePath,
        predictedClass: classes[best],
        confidence: scores[best],
        createdAt: now,
        modelVersion: forest['version'] as String,
      );
    } on ServiceFailure {
      rethrow;
    } catch (error, stack) {
      debugPrint('Random forest analysis failed: $error\n$stack');
      throw const ServiceFailure(
        'Model gagal dimuat atau dijalankan. Jalankan '
        'training/train_random_forest.py, salin hasilnya ke assets/models, '
        'lalu jalankan ulang aplikasi.',
      );
    }
  }
}
