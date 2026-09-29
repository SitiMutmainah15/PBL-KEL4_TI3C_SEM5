import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'detection.dart';

// Same floor-coordinate RGB resize as load_rgb in the training notebook.
Float32List prepareBananaInput(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const ServiceFailure('Foto gagal dibaca. Gunakan JPEG atau PNG.');
  }
  if (decoded == null) {
    throw const ServiceFailure('Foto gagal dibaca. Gunakan JPEG atau PNG.');
  }
  final source = img.bakeOrientation(decoded).convert(numChannels: 3);
  final input = Float32List(224 * 224 * 3);
  var offset = 0;
  for (var y = 0; y < 224; y++) {
    for (var x = 0; x < 224; x++) {
      final pixel = source.getPixel(
        x * source.width ~/ 224,
        y * source.height ~/ 224,
      );
      input[offset++] = pixel.r.toDouble();
      input[offset++] = pixel.g.toDouble();
      input[offset++] = pixel.b.toDouble();
    }
  }
  return input;
}

class TfliteDetectionService implements DetectionService {
  @override
  Future<DetectionResult> analyze(String imagePath) async {
    Interpreter? interpreter;
    IsolateInterpreter? worker;
    try {
      final labels =
          (jsonDecode(await rootBundle.loadString('assets/models/labels.json'))
                  as List)
              .cast<String>();
      final classes = labels
          .map(
            (label) =>
                LeafClass.values.firstWhere((value) => value.label == label),
          )
          .toList();
      final metadata =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/models/model_metadata.json',
                ),
              )
              as Map<String, dynamic>;
      if (classes.length != 4 ||
          classes.toSet().length != 4 ||
          metadata['normalization'] != 'inside_model' ||
          metadata['resize'] != 'nearest_floor' ||
          !listEquals((metadata['labels'] as List).cast<String>(), labels)) {
        throw const FormatException('Model metadata does not match the app.');
      }
      interpreter = await Interpreter.fromAsset('assets/models/model.tflite');
      final inputTensor = interpreter.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);
      if (!listEquals(inputTensor.shape, [1, 224, 224, 3]) ||
          !listEquals(outputTensor.shape, [1, classes.length]) ||
          inputTensor.type != TensorType.float32 ||
          outputTensor.type != TensorType.float32) {
        throw const FormatException('Unexpected TFLite tensor format.');
      }
      final input = await compute(
        prepareBananaInput,
        await File(imagePath).readAsBytes(),
      );
      final output = [List<double>.filled(classes.length, 0)];
      worker = await IsolateInterpreter.create(address: interpreter.address);
      await worker.run(input.buffer, output);
      final scores = output.single;
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
        modelVersion: metadata['version'] as String,
      );
    } on ServiceFailure {
      rethrow;
    } catch (error, stack) {
      debugPrint('TFLite analysis failed: $error\n$stack');
      throw const ServiceFailure(
        'Model gagal dimuat atau dijalankan. Pastikan hasil ekspor notebook '
        'sudah disalin ke aset, lalu jalankan ulang aplikasi.',
      );
    } finally {
      await worker?.close();
      interpreter?.close();
    }
  }
}
