import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'baseline_condition.dart';
import 'detection.dart';
import 'leaf_caption.dart';
import 'reference_photos.dart';

// =========================================
// COLOR PALETTE
// =========================================

const Color _primary = Color(0xFF164D2C);
const Color _secondary = Color(0xFF4C8826);
const Color _muted = Color(0xFF637367);
const Color _softGreen = Color(0xFFE7EDDF);
const Color _border = Color(0xFFDDE4D7);

// =========================================
// CAPTION SECTION
// =========================================

class CaptionSection extends StatefulWidget {
  const CaptionSection({
    super.key,
    required this.result,
    required this.request,
    required this.onRetry,
  });

  final DetectionResult result;
  final Future<LeafCaption> request;
  final VoidCallback onRetry;

  @override
  State<CaptionSection> createState() => _CaptionSectionState();
}

class _CaptionSectionState extends State<CaptionSection> {
  bool _showBaseline = false;

  void _retry() {
    widget.onRetry();
    setState(() => _showBaseline = false);
  }

  // =========================================
  // UI CAPTION SECTION
  // =========================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LeafCaption>(
      future: widget.request,
      builder: (context, snapshot) {
        // Loading AI
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return _buildLoading();
        }

        // Error handling asli
        if (snapshot.hasError) {
          return _buildError(snapshot.error);
        }

        final caption = snapshot.data!;
        final predicted = widget.result.predictedClass;

        // Pemeriksaan perbedaan label model asli
        final namedByLanguageModel = LeafClass.values
            .where(
              (value) =>
                  value.name == caption.detectedLabel,
            )
            .firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header penjelasan AI
            const _CaptionHeader(),

            const SizedBox(height: 26),

            // Tentang kondisi daun
            _SectionText(
              title: 'Tentang kondisi ini',
              content: caption.summary,
            ),

            // Perbedaan model gambar dan model bahasa
            if (namedByLanguageModel != null &&
                namedByLanguageModel != predicted) ...[
              const SizedBox(height: 16),

              _buildModelNotice(
                namedByLanguageModel,
                predicted,
              ),
            ],

            const _SectionDivider(),

            // Penanganan awal dari AI
            _SectionText(
              title: 'Penanganan awal',
              content: caption.treatment,
            ),

            const _SectionDivider(),

            // Foto referensi asli dari dataset
            _buildReferencePhotos(),

            const SizedBox(height: 26),

            // Saran pengambilan foto asli
            PhotoTipCard(
              tip: caption.photoTip,
              imageMatches: caption.imageMatches,
            ),
          ],
        );
      },
    );
  }

  // =========================================
  // LOADING STATE
  // =========================================

  Widget _buildLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CaptionHeader(),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 28,
          ),
          decoration: BoxDecoration(
            color: _softGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: _secondary,
                  strokeWidth: 2,
                ),
              ),

              SizedBox(height: 18),

              Text(
                'Menyusun keterangan kondisi daun...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: _primary,
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(height: 8),

              Text(
                'AI sedang menyiapkan penjelasan '
                'berdasarkan hasil identifikasi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================
  // ERROR STATE
  // =========================================

  Widget _buildError(Object? error) {
    final message = error is ServiceFailure
        ? error.message
        : 'Keterangan tambahan gagal dimuat. '
          'Coba lagi nanti.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CaptionHeader(),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6EAE6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFA04B43),
                size: 22,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Penjelasan belum tersedia',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFA04B43),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: Color(0xFF805B55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Fungsi retry asli
        OutlinedButton.icon(
          onPressed: _retry,
          icon: const Icon(
            Icons.refresh_rounded,
            size: 19,
          ),
          label: const Text('Coba lagi'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            minimumSize: const Size(0, 48),
            side: const BorderSide(
              color: Color(0xFFB9CBB2),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Fallback asli
        if (!_showBaseline)
          TextButton(
            onPressed: () {
              setState(() => _showBaseline = true);
            },
            style: TextButton.styleFrom(
              foregroundColor: _secondary,
              minimumSize: const Size(0, 44),
            ),
            child: const Text(
              'Tampilkan keterangan umum',
              style: TextStyle(fontSize: 13),
            ),
          ),

        if (_showBaseline) ...[
          const SizedBox(height: 20),
          _BaselineText(result: widget.result),
        ],
      ],
    );
  }

  // =========================================
  // PERBEDAAN HASIL MODEL
  // =========================================

  Widget _buildModelNotice(
    LeafClass namedByLanguageModel,
    LeafClass predicted,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EADB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 21,
            color: Color(0xFF95612F),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perbedaan hasil identifikasi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF95612F),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Model bahasa menyebut '
                  '${namedByLanguageModel.label}, '
                  'sedangkan model gambar menyebut '
                  '${predicted.label}. '
                  'Label model gambar tetap dipakai '
                  'sebagai hasil utama.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Color(0xFF805E3B),
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
  // FOTO PEMBANDING
  // =========================================

  Widget _buildReferencePhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto pembanding',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
            color: _primary,
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'Tiga contoh daun dari split uji dataset '
          'dengan kelas yang sama. '
          'Dipakai sebagai pembanding tampilan, '
          'bukan hasil analisis foto Anda.',
          style: TextStyle(
            fontSize: 12,
            height: 1.6,
            color: _muted,
          ),
        ),

        const SizedBox(height: 16),

        // Widget foto pembanding asli.
        ReferencePhotoStrip(
          leafClass: widget.result.predictedClass,
        ),
      ],
    );
  }
}

// =========================================
// HEADER CAPTION
// =========================================

class _CaptionHeader extends StatelessWidget {
  const _CaptionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Penjelasan hasil',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                  color: _primary,
                ),
              ),

              SizedBox(height: 5),

              Text(
                'Analisis berbantuan AI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: _softGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome_outlined,
            color: _secondary,
            size: 21,
          ),
        ),
      ],
    );
  }
}

// =========================================
// SECTION TEXT
// =========================================

class _SectionText extends StatelessWidget {
  const _SectionText({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
            color: _primary,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.75,
            color: _muted,
          ),
        ),
      ],
    );
  }
}

// =========================================
// SECTION DIVIDER
// =========================================

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Divider(
        height: 1,
        thickness: 0.7,
        color: _border,
      ),
    );
  }
}

// =========================================
// BASELINE TEXT — FALLBACK ASLI
// =========================================

class _BaselineText extends StatelessWidget {
  const _BaselineText({
    required this.result,
  });

  final DetectionResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _softGreen,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 19,
                color: _secondary,
              ),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Keterangan umum tanpa analisis AI',
                  style: TextStyle(
                    fontSize: 12,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _SectionText(
          title: 'Tentang kondisi ini',
          content: baselineConditionInfo(
            result.predictedClass,
          ),
        ),

        const _SectionDivider(),

        _SectionText(
          title: 'Penanganan awal',
          content: baselineTreatment(
            result.predictedClass,
          ),
        ),
      ],
    );
  }
}

// =========================================
// PHOTO TIP CARD
// =========================================

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
    final accent = imageMatches
        ? _secondary
        : AppColors.error;

    final background = imageMatches
        ? _softGreen
        : const Color(0xFFF6EAE6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                imageMatches
                    ? Icons.center_focus_strong_outlined
                    : Icons.image_not_supported_outlined,
                color: accent,
                size: 23,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  imageMatches
                      ? 'Saran foto berikutnya'
                      : 'Foto ini sulit dibaca',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: imageMatches
                        ? _primary
                        : accent,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            tip,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.65,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }
}
