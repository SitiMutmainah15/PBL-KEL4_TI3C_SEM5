import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'baseline_condition.dart';
import 'detection.dart';
import 'leaf_caption.dart';
import 'reference_photos.dart';

/// Blok "Tentang kondisi ini" dan "Penanganan awal" yang teksnya dibuat model
/// bahasa, lengkap dengan status muat, gagal, dan coba lagi.
class CaptionSection extends ConsumerStatefulWidget {
  const CaptionSection({super.key, required this.result});

  final DetectionResult result;

  @override
  ConsumerState<CaptionSection> createState() => _CaptionSectionState();
}

class _CaptionSectionState extends ConsumerState<CaptionSection> {
  Future<LeafCaption>? _request;
  bool _showBaseline = false;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<LeafCaption> _load() {
    final service = ref.read(captionServiceProvider);
    final cache = ref.read(captionCacheProvider);
    // Ditunda satu microtask supaya FutureBuilder sudah berlangganan sebelum
    // kegagalan pertama muncul, sehingga error tampil sebagai Notice.
    return Future<LeafCaption>(() => cache.load(widget.result, service));
  }

  void _retry() {
    ref.read(captionCacheProvider).invalidate(widget.result);
    setState(() {
      _showBaseline = false;
      _request = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<LeafCaption>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingMessage('Menyusun keterangan kondisi daun...');
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Notice(
                error is ServiceFailure
                    ? error.message
                    : 'Keterangan tambahan gagal dimuat. Coba lagi nanti.',
                error: true,
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _retry, child: const Text('Coba Lagi')),
              const SizedBox(height: 8),
              if (!_showBaseline)
                TextButton(
                  onPressed: () => setState(() => _showBaseline = true),
                  child: const Text('Tampilkan keterangan umum'),
                ),
              if (_showBaseline) ...[
                const SizedBox(height: 16),
                _BaselineText(result: widget.result),
              ],
            ],
          );
        }

        final caption = snapshot.data!;
        final predicted = widget.result.predictedClass;
        final namedByLanguageModel = LeafClass.values
            .where((value) => value.name == caption.detectedLabel)
            .firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tentang kondisi ini', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(caption.summary),
            if (namedByLanguageModel != null &&
                namedByLanguageModel != predicted) ...[
              const SizedBox(height: 8),
              Text(
                'Model bahasa menyebut ${namedByLanguageModel.label}, '
                'sedangkan model gambar menyebut ${predicted.label}. '
                'Label model gambar tetap dipakai sebagai hasil utama.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 24),
            Text('Penanganan awal', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(caption.treatment),
            const SizedBox(height: 24),
            Text('Foto pembanding', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Tiga contoh daun dari split uji dataset dengan kelas yang sama. '
              'Dipakai sebagai pembanding tampilan, bukan hasil analisis foto Anda.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ReferencePhotoStrip(leafClass: widget.result.predictedClass),
            const SizedBox(height: 24),
            PhotoTipCard(
              tip: caption.photoTip,
              imageMatches: caption.imageMatches,
            ),
          ],
        );
      },
    );
  }
}

/// Keterangan umum tanpa model bahasa, dipakai hanya bila pengguna memilihnya
/// setelah layanan caption gagal.
class _BaselineText extends StatelessWidget {
  const _BaselineText({required this.result});

  final DetectionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tentang kondisi ini', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(baselineConditionInfo(result.predictedClass)),
        const SizedBox(height: 24),
        Text('Penanganan awal', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(baselineTreatment(result.predictedClass)),
      ],
    );
  }
}

/// Kotak saran memotret ulang, diwarnai berbeda supaya terbaca sebagai
/// tindakan lanjutan, bukan peringatan medis.
class PhotoTipCard extends StatelessWidget {
  const PhotoTipCard({
    super.key,
    required this.tip,
    required this.imageMatches,
  });

  final String tip;
  final bool imageMatches;

  @override
  Widget build(BuildContext context) {
    final accent = imageMatches ? AppColors.forest700 : AppColors.error;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: AppColors.cream100,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        imageMatches
                            ? Icons.center_focus_strong_outlined
                            : Icons.image_not_supported_outlined,
                        color: accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              imageMatches
                                  ? 'Saran foto berikutnya'
                                  : 'Foto ini sulit dibaca',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(tip, style: const TextStyle(height: 1.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
