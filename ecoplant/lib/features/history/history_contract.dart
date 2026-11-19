import '../detection/detection.dart';

abstract interface class HistoryRepository {
  Future<List<DetectionResult>> load();
  Future<void> save(DetectionResult result);
  Future<void> update(DetectionResult result);
  Future<void> delete(String id);
}

class UnavailableHistoryRepository implements HistoryRepository {
  const UnavailableHistoryRepository();
  static const message =
      'Penyimpanan riwayat belum tersedia pada versi ini. Silakan coba kembali setelah layanan tersedia.';
  @override
  Future<List<DetectionResult>> load() async =>
      throw const ServiceFailure(message);
  @override
  Future<void> save(DetectionResult result) async =>
      throw const ServiceFailure(message);
  @override
  Future<void> update(DetectionResult result) async =>
      throw const ServiceFailure(message);
  @override
  Future<void> delete(String id) async => throw const ServiceFailure(message);
}
