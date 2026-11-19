import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../detection/detection.dart';
import 'local_history_repository.dart';
import 'history_contract.dart';

export 'history_contract.dart';

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => LocalHistoryRepository(),
);
final historyProvider = FutureProvider<List<DetectionResult>>((ref) async {
  final items = await ref.watch(historyRepositoryProvider).load();
  return [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}, retry: (count, error) => null);
