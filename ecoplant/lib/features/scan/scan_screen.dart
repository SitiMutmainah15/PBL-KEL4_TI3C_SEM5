import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../detection/result_screen.dart';
import 'camera_capture.dart';
import 'scan_controller.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});
  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(scanProvider.notifier).pick(recover: true);
    });
  }

  Future<void> _camera() async {
    final path = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const CameraCapture()));
    if (path != null && mounted) {
      await ref.read(scanProvider.notifier).select(path);
    }
  }

  Future<void> _analyze() async {
    final result = await ref.read(scanProvider.notifier).analyze();
    if (!mounted || result == null) return;
    final retake = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
    );
    if (mounted && retake == true) ref.read(scanProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanProvider);
    return PageBody(
      children: [
        Text(
          state.imagePath == null
              ? 'Mulai dari satu daun.'
              : 'Periksa foto Anda',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Pastikan daun terlihat jelas, cukup terang, dan tidak tertutup objek lain.',
        ),
        const SizedBox(height: 24),
        if (state.imagePath != null)
          LeafPhoto(path: state.imagePath!, height: 300)
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            decoration: BoxDecoration(
              color: AppColors.cream100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 48,
                  color: AppColors.forest900,
                ),
                SizedBox(height: 16),
                Text(
                  'Belum ada foto dipilih.',
                  style: TextStyle(color: AppColors.ink900),
                ),
                SizedBox(height: 8),
                Text(
                  'Ambil foto daun pisang atau buka galeri.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        if (state.busy)
          LoadingMessage(
            state.analyzing ? 'Menganalisis daun...' : 'Menyiapkan foto...',
          ),
        if (state.error != null) ...[
          Notice(state.error!, error: true),
          const SizedBox(height: 16),
        ],
        if (state.imagePath == null)
          FilledButton.icon(
            onPressed: state.busy ? null : _camera,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Buka Kamera'),
          )
        else
          FilledButton(
            onPressed: state.busy ? null : _analyze,
            child: const Text('Analisis'),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: state.busy
              ? null
              : () => ref.read(scanProvider.notifier).pick(),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            state.imagePath == null ? 'Pilih dari Galeri' : 'Ganti Foto',
          ),
        ),
        if (state.imagePath != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: state.busy ? null : _camera,
            child: const Text('Ambil Ulang'),
          ),
          TextButton(
            onPressed: state.busy
                ? null
                : () => ref.read(scanProvider.notifier).clear(),
            child: const Text('Batalkan Foto'),
          ),
        ],
        const SizedBox(height: 20),
        const Notice(
          'Analisis belum tersedia pada versi pengembangan ini. Foto Anda tidak dikirim untuk analisis.',
        ),
      ],
    );
  }
}
