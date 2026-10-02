import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tflite_detection_service.dart';

enum LeafClass {
  healthy('Healthy'),
  sigatoka('Sigatoka'),
  cordana('Cordana'),
  pestalotiopsis('Pestalotiopsis');

  const LeafClass(this.label);
  final String label;
}

class DetectionResult {
  DetectionResult({
    required this.id,
    required this.imagePath,
    required this.predictedClass,
    required this.confidence,
    required this.createdAt,
    required this.modelVersion,
  }) {
    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'Must be between 0 and 1.',
      );
    }
  }
  final String id;
  final String imagePath;
  final LeafClass predictedClass;
  final double confidence;
  final DateTime createdAt;
  final String modelVersion;
  String get confidenceLabel => '${(confidence * 100).toStringAsFixed(1)}%';
}

class ServiceFailure implements Exception {
  const ServiceFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class DetectionService {
  Future<DetectionResult> analyze(String imagePath);
}

class UnavailableDetectionService implements DetectionService {
  const UnavailableDetectionService();
  @override
  Future<DetectionResult> analyze(String imagePath) async {
    // TODO: Connect TFLite after model, label order and training preprocessing are supplied.
    throw const ServiceFailure(
      'Analisis belum tersedia pada versi ini. Anda tetap dapat mengambil atau memilih foto.',
    );
  }
}

final detectionServiceProvider = Provider<DetectionService>((ref) {
  return TfliteDetectionService();
});
const resultDisclaimer =
    'Hasil ini merupakan prediksi model berdasarkan citra daun, bukan diagnosis pasti. Konsultasikan dengan tenaga ahli jika gejala berlanjut.';
