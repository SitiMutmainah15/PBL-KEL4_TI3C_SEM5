import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../detection/detection.dart';
import 'firebaseHistoryRepository.dart';

abstract interface class HistoryRepository {
  Future<List<DetectionResult>> load();
  Future<void> save(DetectionResult result);
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
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => FirebaseHistoryRepository(),
);
final historyProvider = FutureProvider<List<DetectionResult>>((ref) async {
  final items = await ref.watch(historyRepositoryProvider).load();
  return [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}, retry: (count, error) => null);
