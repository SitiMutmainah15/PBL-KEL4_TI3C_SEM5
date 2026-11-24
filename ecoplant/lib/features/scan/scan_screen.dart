
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../detection/result_screen.dart';
import 'camera_capture.dart';
import 'scan_controller.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() =>
      _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  // Color palette EcoPlant
  static const Color _background = Color(0xFFF7F8F3);
  static const Color _primary = Color(0xFF164D2C);
  static const Color _secondary = Color(0xFF4C8826);
  static const Color _muted = Color(0xFF637367);
  static const Color _softGreen = Color(0xFFE7EDDF);
  static const Color _border = Color(0xFFB9CBB2);

  // =========================================
  // LOGIKA ASLI — TIDAK DIUBAH
  // =========================================

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (mounted) {
        ref.read(scanProvider.notifier).pick(
          recover: true,
        );
      }
    });
  }

  Future<void> _camera() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const CameraCapture(),
      ),
    );

    if (path != null && mounted) {
      await ref.read(scanProvider.notifier).select(path);
    }
  }

  Future<void> _analyze() async {
    final result =
        await ref.read(scanProvider.notifier).analyze();

    if (!mounted || result == null) return;

    final retake = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ResultScreen(result: result),
      ),
    );

    if (mounted && retake == true) {
      ref.read(scanProvider.notifier).clear();
    }
  }

  // =========================================
  // UI SCAN SCREEN
  // =========================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanProvider);
    final bool hasPhoto = state.imagePath != null;

    return ColoredBox(
      color: _background,
      child: PageBody(
        children: [
          const SizedBox(height: 24),

          // Judul dan deskripsi
          _buildHeading(hasPhoto),

          const SizedBox(height: 24),

          // Area preview foto
          if (hasPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: LeafPhoto(
                path: state.imagePath!,
                height: 270,
              ),
            )
          else
            _buildEmptyPreview(),

          const SizedBox(height: 18),

          // Informasi foto
          if (hasPhoto && !state.busy && state.error == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: _secondary,
                    size: 19,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Foto siap dianalisis',
                      style: TextStyle(
                        fontSize: 12,
                        color: _secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Loading asli
          if (state.busy) ...[
            LoadingMessage(
              state.analyzing
                  ? 'Menganalisis daun...'
                  : 'Menyiapkan foto...',
            ),
            const SizedBox(height: 16),
          ],

          // Error handling asli
          if (state.error != null) ...[
            Notice(
              state.error!,
              error: true,
            ),
            const SizedBox(height: 16),
          ],

          // Tombol utama
          if (!hasPhoto)
            _primaryButton(
              label: 'Buka kamera',
              icon: Icons.camera_alt_outlined,
              onPressed: state.busy ? null : _camera,
            )
          else
            _primaryButton(
              label: 'Analisis daun',
              icon: Icons.document_scanner_outlined,
              onPressed: state.busy ? null : _analyze,
            ),

          const SizedBox(height: 12),

          // Tombol galeri sebelum memilih foto
          if (!hasPhoto)
            _secondaryButton(
              label: 'Pilih dari galeri',
              icon: Icons.photo_library_outlined,
              onPressed: state.busy
                  ? null
                  : () {
                      ref.read(scanProvider.notifier).pick();
                    },
            ),

          // Tombol setelah memilih foto
          if (hasPhoto) ...[
            Row(
              children: [
                Expanded(
                  child: _secondaryButton(
                    label: 'Ganti foto',
                    icon: Icons.photo_library_outlined,
                    onPressed: state.busy
                        ? null
                        : () {
                            ref
                                .read(scanProvider.notifier)
                                .pick();
                          },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _secondaryButton(
                    label: 'Ambil ulang',
                    icon: Icons.camera_alt_outlined,
                    onPressed:
                        state.busy ? null : _camera,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Center(
              child: TextButton(
                onPressed: state.busy
                    ? null
                    : () {
                        ref.read(scanProvider.notifier).clear();
                      },
                style: TextButton.styleFrom(
                  foregroundColor: _muted,
                ),
                child: const Text(
                  'Batalkan foto',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],

          // Tips singkat sebelum memilih foto
          if (!hasPhoto) ...[
            const SizedBox(height: 26),
            _buildTips(),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // =========================================
  // HEADING
  // =========================================

  Widget _buildHeading(bool hasPhoto) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasPhoto
              ? 'Periksa foto Anda.'
              : 'Mulai dari satu daun.',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.7,
            height: 1.25,
            color: _primary,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          hasPhoto
              ? 'Pastikan daun terlihat jelas sebelum dianalisis.'
              : 'Ambil atau pilih foto daun pisang untuk '
                'mengetahui kondisi kesehatannya.',
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: _muted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // =========================================
  // EMPTY PREVIEW
  // =========================================

  Widget _buildEmptyPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: _softGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ScanFramePainter(),
                  ),
                ),

                const Icon(
                  Icons.eco_outlined,
                  color: _secondary,
                  size: 76,
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'Belum ada foto',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _primary,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Pilih foto daun untuk memulai.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================
  // PRIMARY BUTTON
  // =========================================

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 21),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _softGreen,
          disabledForegroundColor: _muted,
          minimumSize: const Size(0, 52),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // =========================================
  // SECONDARY BUTTON
  // =========================================

  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          textAlign: TextAlign.center,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          disabledForegroundColor: _muted,
          minimumSize: const Size(0, 50),
          side: const BorderSide(
            color: _border,
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // =========================================
  // TIPS FOTO
  // =========================================

  Widget _buildTips() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tips pengambilan foto',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _primary,
          ),
        ),

        SizedBox(height: 14),

        _PhotoTip(
          icon: Icons.light_mode_outlined,
          text: 'Gunakan pencahayaan yang cukup.',
        ),

        SizedBox(height: 12),

        _PhotoTip(
          icon: Icons.center_focus_strong_outlined,
          text: 'Pastikan foto jelas dan tidak buram.',
        ),

        SizedBox(height: 12),

        _PhotoTip(
          icon: Icons.eco_outlined,
          text: 'Fokus pada satu daun pisang.',
        ),
      ],
    );
  }
}

// =========================================
// KOMPONEN TIPS
// =========================================

class _PhotoTip extends StatelessWidget {
  const _PhotoTip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: const Color(0xFF4C8826),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF637367),
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================
// FRAME ILUSTRASI SCAN
// =========================================

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4C8826)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const double inset = 8;
    const double length = 25;

    final double left = inset;
    final double top = inset;
    final double right = size.width - inset;
    final double bottom = size.height - inset;

    final path = Path()
      // Sudut kiri atas
      ..moveTo(left, top + length)
      ..lineTo(left, top)
      ..lineTo(left + length, top)

      // Sudut kanan atas
      ..moveTo(right - length, top)
      ..lineTo(right, top)
      ..lineTo(right, top + length)

      // Sudut kanan bawah
      ..moveTo(right, bottom - length)
      ..lineTo(right, bottom)
      ..lineTo(right - length, bottom)

      // Sudut kiri bawah
      ..moveTo(left + length, bottom)
      ..lineTo(left, bottom)
      ..lineTo(left, bottom - length);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant _ScanFramePainter oldDelegate,
  ) {
    return false;
  }
}
