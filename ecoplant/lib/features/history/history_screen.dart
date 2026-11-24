
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../detection/detection.dart';
import '../detection/result_screen.dart';
import 'history_repository.dart';

// =========================================
// COLOR PALETTE
// =========================================

const Color _background = Color(0xFFF7F8F3);
const Color _primary = Color(0xFF164D2C);
const Color _secondary = Color(0xFF4C8826);
const Color _muted = Color(0xFF637367);
const Color _softGreen = Color(0xFFE7EDDF);
const Color _border = Color(0xFFDDE4D7);
const Color _warning = Color(0xFF95612F);

// =========================================
// HISTORY SCREEN
// =========================================

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.onScan,
  });

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _background,
      child: PageBody(
        children: [
          const SizedBox(height: 24),

          const Text(
            'Riwayat pemeriksaan.',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.8,
              height: 1.25,
              color: _primary,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Lihat kembali hasil identifikasi daun pisang '
            'yang telah kamu simpan.',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: _muted,
            ),
          ),

          const SizedBox(height: 26),

          HistoryContent(onScan: onScan),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// =========================================
// HISTORY CONTENT
// Digunakan oleh Home dan History Screen
// =========================================

class HistoryContent extends ConsumerWidget {
  const HistoryContent({
    super.key,
    required this.onScan,
    this.limit,
    this.compact = false,
  });

  final VoidCallback onScan;
  final int? limit;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(historyProvider).when(
      loading: () => const LoadingMessage(
        'Memuat riwayat...',
      ),

      error: (error, stack) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Notice(
            error is ServiceFailure
                ? error.message
                : 'Riwayat gagal dimuat. '
                  'Periksa koneksi Anda lalu coba lagi.',
            error: true,
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () {
              ref.invalidate(historyProvider);
            },
            icon: const Icon(
              Icons.refresh_rounded,
              size: 19,
            ),
            label: const Text('Coba lagi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              minimumSize: const Size(0, 48),
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),

      data: (items) {
        if (items.isEmpty) {
          return _buildEmptyState();
        }

        final displayedItems = items
            .take(limit ?? items.length)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ringkasan hanya tampil di halaman Riwayat.
            if (!compact) ...[
              _buildSummary(items.length),

              const SizedBox(height: 26),

              const Text(
                'Semua riwayat',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                  color: _primary,
                ),
              ),

              const SizedBox(height: 14),
            ],

            // Data riwayat asli.
            for (final item in displayedItems)
              Padding(
                padding: EdgeInsets.only(
                  bottom: compact ? 10 : 14,
                ),
                child: _HistoryCard(
                  item: item,
                  compact: compact,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ResultScreen(
                          result: item,
                          fromHistory: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // =========================================
  // RINGKASAN TOTAL PEMERIKSAAN
  // =========================================

  Widget _buildSummary(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 27,
              color: _primary,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total pemeriksaan tersimpan',
                  style: TextStyle(
                    fontSize: 12,
                    color: _muted,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '$total Deteksi',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.5,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================
  // EMPTY STATE
  // =========================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: compact ? 24 : 38,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _border,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: compact ? 54 : 76,
            height: compact ? 54 : 76,
            decoration: const BoxDecoration(
              color: _softGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: compact ? 28 : 36,
              color: _secondary,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Belum ada hasil deteksi',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 15 : 18,
              fontWeight: FontWeight.w500,
              color: _primary,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Hasil deteksi daun yang kamu simpan '
            'nantinya akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: _muted,
            ),
          ),

          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(
              Icons.camera_alt_outlined,
              size: 19,
            ),
            label: const Text('Mulai scan'),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================
// HISTORY CARD
// =========================================

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.compact,
    required this.onTap,
  });

  final DetectionResult item;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isHealthy =
        item.predictedClass == LeafClass.healthy;

    final Color statusColor =
        isHealthy ? _secondary : _warning;

    final Color statusBackground = isHealthy
        ? const Color(0xFFE7EDDF)
        : const Color(0xFFF5EADB);

    final double photoSize = compact ? 46 : 66;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),

        // Border tipis seperti Deteksi Terbaru.
        side: const BorderSide(
          color: _border,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: onTap,

        child: Padding(
          padding: EdgeInsets.all(
            compact ? 12 : 16,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center,
                children: [
                  // Foto asli hasil pemindaian.
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(10),
                    child: SizedBox(
                      width: photoSize,
                      height: photoSize,
                      child: LeafPhoto(
                        path: item.imagePath,
                        height: photoSize,
                      ),
                    ),
                  ),

                  SizedBox(
                    width: compact ? 12 : 14,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Nama hasil deteksi.
                        Text(
                          item.predictedClass.label,
                          style: TextStyle(
                            fontSize: compact ? 14 : 17,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.3,
                            color: _primary,
                          ),
                        ),

                        const SizedBox(height: 5),

                        // Confidence asli.
                        Text(
                          'Confidence ${item.confidenceLabel}',
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            color: _muted,
                          ),
                        ),

                        const SizedBox(height: 5),

                        // Tanggal asli.
                        Text(
                          displayDate(item.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: _muted,
                          ),
                        ),

                        // Status compact untuk Beranda.
                        if (compact) ...[
                          const SizedBox(height: 8),

                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusBackground,
                              borderRadius:
                                  BorderRadius.circular(6),
                            ),
                            child: Text(
                              isHealthy
                                  ? 'Sehat'
                                  : 'Perlu perhatian',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: _muted,
                  ),
                ],
              ),

              // Bagian tambahan hanya pada History.
              if (!compact) ...[
                const SizedBox(height: 14),

                const Divider(
                  height: 1,
                  thickness: 0.8,
                  color: _border,
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius:
                            BorderRadius.circular(8),
                      ),

                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),

                          const SizedBox(width: 6),

                          Text(
                            isHealthy
                                ? 'Sehat'
                                : 'Perlu perhatian',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    const Expanded(
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              'Lihat detail',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _primary,
                              ),
                            ),
                          ),

                          SizedBox(width: 5),

                          Icon(
                            Icons.arrow_outward_rounded,
                            size: 15,
                            color: _primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
