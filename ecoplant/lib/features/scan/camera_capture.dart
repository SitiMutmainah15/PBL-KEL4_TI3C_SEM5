
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraCapture extends StatefulWidget {
  const CameraCapture({super.key});

  @override
  State<CameraCapture> createState() => _CameraCaptureState();
}

class _CameraCaptureState extends State<CameraCapture>
    with WidgetsBindingObserver {
  // Color palette
  static const Color _background = Color(0xFF101A14);
  static const Color _surface = Color(0xFF1C2920);
  static const Color _light = Color(0xFFF7F8F3);
  static const Color _muted = Color(0xFFA5B6A8);
  static const Color _accent = Color(0xFFD0DDB4);

  CameraController? _camera;
  String? _error;
  bool _capturing = false;
  int _generation = 0;

  // =========================================
  // LOGIKA KAMERA ASLI
  // =========================================

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
        throw CameraException(
          'NoCamera',
          'Tidak ada kamera.',
        );
      }

      final selected = cameras
              .where(
                (camera) =>
                    camera.lensDirection ==
                    CameraLensDirection.back,
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
            error is CameraException &&
                    error.code.startsWith('CameraAccess')
                ? 'Izin kamera belum diberikan. '
                    'Izinkan kamera melalui pengaturan '
                    'aplikasi, lalu coba lagi atau '
                    'gunakan galeri.'
                : 'Kamera tidak dapat dibuka. '
                    'Coba lagi atau kembali untuk '
                    'memilih foto dari galeri.',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
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

    if (camera == null ||
        !camera.value.isInitialized ||
        _capturing) {
      return;
    }

    setState(() {
      _capturing = true;
      _error = null;
    });

    try {
      final picture = await camera.takePicture();

      if (mounted) {
        Navigator.of(context).pop(picture.path);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Foto gagal diambil. Coba ambil kembali.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  @override
  void dispose() {
    _generation++;

    WidgetsBinding.instance.removeObserver(this);

    unawaited(_camera?.dispose());

    super.dispose();
  }

  // =========================================
  // UI CAMERA SCREEN
  // =========================================

  @override
  Widget build(BuildContext context) {
    final bool isReady =
        _camera != null &&
        _camera!.value.isInitialized;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness:
            Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _background,

        // HEADER
        appBar: _buildAppBar(),

        // CAMERA CONTENT
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20, 12, 20, 16,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                // Instruksi pengambilan foto
                _buildInstruction(),

                const SizedBox(height: 20),

                // Preview kamera
                Expanded(
                  child: _buildCameraArea(isReady),
                ),

                // Pesan error saat capture
                if (_error != null && isReady) ...[
                  const SizedBox(height: 12),
                  _buildCaptureError(),
                ],

                const SizedBox(height: 18),

                // Tips pencahayaan
                _buildLightingTip(),

                const SizedBox(height: 20),

                // Tombol shutter
                _buildCaptureButton(isReady),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================
  // APP BAR
  // =========================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _background,
      foregroundColor: _light,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      centerTitle: true,
      automaticallyImplyLeading: false,
      toolbarHeight: 60,

      systemOverlayStyle:
          const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness:
            Brightness.light,
      ),

      leading: IconButton(
        tooltip: 'Kembali ke Scan',
        onPressed: _capturing
            ? null
            : () => Navigator.of(context).pop(),
        icon: const Icon(
          Icons.arrow_back_rounded,
          size: 23,
        ),
      ),

      title: const Text(
        'Ambil foto',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.4,
          color: _light,
        ),
      ),
    );
  }

  // =========================================
  // INSTRUCTION
  // =========================================

  Widget _buildInstruction() {
    return const Column(
      children: [
        Text(
          'Posisikan daun di dalam bingkai',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _light,
            height: 1.4,
          ),
        ),

        SizedBox(height: 6),

        Text(
          'Pastikan seluruh bagian daun terlihat jelas.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: _muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // =========================================
  // CAMERA PREVIEW
  // =========================================

  Widget _buildCameraArea(bool isReady) {
    if (isReady) {
      return Center(
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CameraPreview(_camera!),
                  ),
                ),

                // Bingkai pemindaian
                const IgnorePointer(
                  child: CustomPaint(
                    painter: _FramePainter(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _error != null
          ? _buildErrorState()
          : _buildLoadingState(),
    );
  }

  // =========================================
  // LOADING CAMERA
  // =========================================

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: _accent,
              strokeWidth: 2,
            ),
          ),

          SizedBox(height: 18),

          Text(
            'Membuka kamera...',
            style: TextStyle(
              fontSize: 13,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================
  // CAMERA ERROR
  // =========================================

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: _accent,
              size: 42,
            ),

            const SizedBox(height: 18),

            const Text(
              'Kamera tidak tersedia',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: _light,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: _muted,
              ),
            ),

            const SizedBox(height: 22),

            OutlinedButton(
              onPressed:
                  _capturing ? null : _initialize,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(
                  color: _accent,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================
  // CAPTURE ERROR
  // =========================================

  Widget _buildCaptureError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF382724),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 19,
                color: Color(0xFFFFB4AB),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _error ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFFFFB4AB),
                  ),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed:
                _capturing ? null : _initialize,
            style: TextButton.styleFrom(
              foregroundColor: _accent,
            ),
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  // =========================================
  // LIGHTING TIP
  // =========================================

  Widget _buildLightingTip() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.light_mode_outlined,
          size: 17,
          color: _accent,
        ),

        SizedBox(width: 8),

        Flexible(
          child: Text(
            'Gunakan pencahayaan yang cukup',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _muted,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================
  // SHUTTER BUTTON
  // =========================================

  Widget _buildCaptureButton(bool isReady) {
    final bool enabled = isReady && !_capturing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: 'Ambil foto daun',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? _capture : null,
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 180),
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: enabled ? _light : _muted,
                    width: 2,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled
                        ? _light
                        : const Color(0xFF435047),
                  ),
                  child: _capturing
                      ? const Center(
                          child: SizedBox(
                            width: 23,
                            height: 23,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _light,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          _capturing
              ? 'Mengambil foto...'
              : 'Ambil foto',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: _muted,
          ),
        ),
      ],
    );
  }
}

// =========================================
// CAMERA FRAME PAINTER
// =========================================

class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      size.width * 0.10,
      size.height * 0.12,
      size.width * 0.80,
      size.height * 0.76,
    );

    final path = Path();

    const length = 26.0;

    for (final corner in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ]) {
      path.moveTo(
        corner.$1.dx,
        corner.$1.dy + length * corner.$3,
      );

      path.lineTo(
        corner.$1.dx,
        corner.$1.dy,
      );

      path.lineTo(
        corner.$1.dx + length * corner.$2,
        corner.$1.dy,
      );
    }

    // Outline gelap agar frame terlihat
    // pada objek dengan pencahayaan terang.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Frame utama
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFF7F8F3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(
    covariant _FramePainter oldDelegate,
  ) {
    return false;
  }
}
