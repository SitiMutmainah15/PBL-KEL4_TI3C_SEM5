import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../detection/detection.dart';
import '../detection/result_screen.dart';
import 'history_repository.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.onScan});
  final VoidCallback onScan;
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Text(
        'Pemeriksaan daun Anda',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Buka hasil yang telah disimpan untuk melihat detailnya kembali.',
      ),
      const SizedBox(height: 24),
      HistoryContent(onScan: onScan),
    ],
  );
}

class HistoryContent extends ConsumerWidget {
  const HistoryContent({super.key, required this.onScan, this.limit});
  final VoidCallback onScan;
  final int? limit;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(historyProvider)
      .when(
        loading: () => const LoadingMessage('Memuat riwayat...'),
        error: (error, stack) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Notice(
              error is ServiceFailure
                  ? error.message
                  : 'Riwayat gagal dimuat. Periksa koneksi Anda lalu coba lagi.',
              error: true,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(historyProvider),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.history,
                      size: 40,
                      color: AppColors.forest900,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada hasil deteksi.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hasil yang disimpan akan muncul di sini.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: onScan,
                      child: const Text('Scan daun pertama'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final item in items.take(limit ?? items.length))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ResultScreen(result: item, fromHistory: true),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 56,
                              child: LeafPhoto(
                                path: item.imagePath,
                                height: 56,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.predictedClass.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Confidence ${item.confidenceLabel}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayDate(item.createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.ink600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.forest900,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}
