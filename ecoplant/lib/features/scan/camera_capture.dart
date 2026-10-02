import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class CameraCapture extends StatefulWidget {
  const CameraCapture({super.key});
  @override
  State<CameraCapture> createState() => _CameraCaptureState();
}

class _CameraCaptureState extends State<CameraCapture>
    with WidgetsBindingObserver {
  CameraController? _camera;
  String? _error;
  bool _capturing = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    final old = _camera;
    setState(() {
      _camera = null;
      _error = null;
    });
    await old?.dispose();
    CameraController? next;
    try {
      final cameras = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'Tidak ada kamera.');
      }
      final selected =
          cameras
              .where(
                (camera) => camera.lensDirection == CameraLensDirection.back,
              )
              .firstOrNull ??
          cameras.first;
      next = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted || generation != _generation) {
        await next.dispose();
        return;
      }
      setState(() => _camera = next);
    } catch (error) {
      await next?.dispose();
      if (!mounted || generation != _generation) return;
      setState(
        () => _error =
            error is CameraException && error.code.startsWith('CameraAccess')
            ? 'Izin kamera belum diberikan. Izinkan kamera melalui pengaturan aplikasi, lalu coba lagi atau gunakan galeri.'
            : 'Kamera tidak dapat dibuka. Coba lagi atau kembali untuk memilih foto dari galeri.',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _generation++;
      final camera = _camera;
      setState(() => _camera = null);
      unawaited(camera?.dispose());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initialize());
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _capturing) return;
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      final picture = await camera.takePicture();
      if (mounted) Navigator.of(context).pop(picture.path);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Foto gagal diambil. Coba ambil kembali.');
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ambil Foto')),
    body: PageBody(
      children: [
        const Text('Posisikan satu daun di dalam frame.'),
        const SizedBox(height: 16),
        if (_camera != null && _camera!.value.isInitialized)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppColors.ink900,
                    child: Center(child: CameraPreview(_camera!)),
                  ),
                  const IgnorePointer(
                    child: CustomPaint(painter: _FramePainter()),
                  ),
                ],
              ),
            ),
          )
        else if (_error == null)
          const LoadingMessage('Membuka kamera...'),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Notice(_error!, error: true),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _capturing ? null : _initialize,
            child: const Text('Coba Lagi'),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _camera == null || _capturing ? null : _capture,
          icon: const Icon(Icons.camera_alt),
          label: Text(_capturing ? 'Mengambil foto...' : 'Ambil Foto'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _capturing ? null : () => Navigator.of(context).pop(),
          child: const Text('Kembali ke Scan'),
        ),
      ],
    ),
  );
}

class _FramePainter extends CustomPainter {
  const _FramePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      size.width * .1,
      size.height * .12,
      size.width * .8,
      size.height * .76,
    );
    final path = Path();
    const length = 24.0;
    for (final corner in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ]) {
      path.moveTo(corner.$1.dx, corner.$1.dy + length * corner.$3);
      path.lineTo(corner.$1.dx, corner.$1.dy);
      path.lineTo(corner.$1.dx + length * corner.$2, corner.$1.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.forest900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => false;
}
