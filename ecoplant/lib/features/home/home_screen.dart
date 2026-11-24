
import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../history/history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onScan,
    required this.onHistory,
  });

  final VoidCallback onScan;
  final VoidCallback onHistory;

  // Color palette EcoPlant
  static const Color _background = Color(0xFFF7F8F3);
  static const Color _primary = Color(0xFF164D2C);
  static const Color _secondary = Color(0xFF4C8826);
  static const Color _muted = Color(0xFF637367);
  static const Color _softGreen = Color(0xFFE7EDDF);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _background,
      child: PageBody(
        children: [
          const SizedBox(height: 12),

          // Welcome section
          _buildWelcome(),

          const SizedBox(height: 24),

          // Tips pencahayaan
          _buildTip(),

          const SizedBox(height: 28),

          // Header deteksi terbaru
          _buildHistoryHeader(),

          const SizedBox(height: 12),

          // Riwayat deteksi asli
          HistoryContent(
            onScan: onScan,
            limit: 3,
            compact: true,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // =========================================
  // WELCOME SECTION
  // =========================================

  Widget _buildWelcome() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double imageWidth =
            (constraints.maxWidth * 0.32)
                .clamp(72.0, 125.0)
                .toDouble();

        const welcomeText = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selamat datang',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: _muted,
              ),
            ),

            SizedBox(height: 12),

            Text(
              'Daun sehat,\ntanaman kuat.',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.8,
                height: 1.25,
                color: _primary,
              ),
            ),

            SizedBox(height: 12),

            Text(
              'Kenali kondisi daun pisangmu sejak dini.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.6,
                color: _muted,
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 280) {
          return welcomeText;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: welcomeText,
            ),

            const SizedBox(width: 16),

            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/banana_leaf.jpg',
                width: imageWidth,
                height: imageWidth * 1.4,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                excludeFromSemantics: true,

                // Pengganti jika gambar gagal dimuat
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: imageWidth,
                    height: imageWidth * 1.4,
                    decoration: BoxDecoration(
                      color: _softGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.eco_outlined,
                      color: _secondary,
                      size: 48,
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
  // TIPS PENCAHAYAAN
  // =========================================

  Widget _buildTip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: _softGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.light_mode_outlined,
            size: 22,
            color: _secondary,
          ),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              'Pindai daun dengan pencahayaan yang cukup.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: _primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================
  // HEADER DETEKSI TERBARU
  // =========================================

  Widget _buildHistoryHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Deteksi terbaru',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.3,
              color: _primary,
            ),
          ),
        ),

        TextButton(
          onPressed: onHistory,
          style: TextButton.styleFrom(
            foregroundColor: _secondary,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lihat semua',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(width: 3),

              Icon(
                Icons.chevron_right_rounded,
                size: 17,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
