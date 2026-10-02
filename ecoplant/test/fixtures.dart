import 'dart:async';
import 'package:ecoplant/features/detection/detection.dart';
import 'package:ecoplant/features/history/history_repository.dart';
import 'package:ecoplant/features/scan/scan_controller.dart';

// Synthetic results are confined to tests and never installed in the app.
DetectionResult fixture({String id = 'test-only', DateTime? date}) =>
    DetectionResult(
      id: id,
      imagePath: 'missing-test-photo.png',
      predictedClass: LeafClass.sigatoka,
      confidence: .87,
      createdAt: date ?? DateTime(2026, 9, 24, 10, 30),
      modelVersion: 'test-only',
    );

class TestHistory implements HistoryRepository {
  TestHistory({
    this.items = const [],
    this.failLoad = false,
    this.failSave = false,
    this.pending,
  });
  List<DetectionResult> items;
  bool failLoad;
  bool failSave;
  Completer<List<DetectionResult>>? pending;
  int saves = 0;
  @override
  Future<List<DetectionResult>> load() async {
    if (failLoad) {
      throw const ServiceFailure('Riwayat gagal dimuat. Coba lagi.');
    }
    return pending != null ? pending!.future : items;
  }

  @override
  Future<void> save(DetectionResult result) async {
    saves++;
    if (failSave) {
      throw const ServiceFailure('Riwayat gagal disimpan. Coba lagi.');
    }
    items = [...items.where((item) => item.id != result.id), result];
  }
}

class TestGallery implements GalleryService {
  String? path;
  bool fail = false;
  @override
  Future<String?> pick() async {
    if (fail) throw StateError('test permission denied');
    return path;
  }

  @override
  Future<String?> recover() async => null;
}

class TestDetection implements DetectionService {
  TestDetection(this.completer);
  final Completer<DetectionResult> completer;
  int calls = 0;
  @override
  Future<DetectionResult> analyze(String imagePath) {
    calls++;
    return completer.future;
  }
}
