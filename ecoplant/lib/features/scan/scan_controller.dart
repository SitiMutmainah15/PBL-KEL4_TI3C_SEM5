import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../detection/detection.dart';

abstract interface class GalleryService {
  Future<String?> pick();
  Future<String?> recover();
}

class DeviceGalleryService implements GalleryService {
  final _picker = ImagePicker();
  @override
  Future<String?> pick() async =>
      (await _picker.pickImage(source: ImageSource.gallery))?.path;
  @override
  Future<String?> recover() async {
    if (!Platform.isAndroid) return null;
    final response = await _picker.retrieveLostData();
    if (response.exception != null) throw response.exception!;
    return response.files?.firstOrNull?.path;
  }
}

final galleryServiceProvider = Provider<GalleryService>(
  (ref) => DeviceGalleryService(),
);
final imageValidatorProvider = Provider<Future<void> Function(String)>(
  (ref) => (path) async {
    ui.Codec? codec;
    try {
      final bytes = await File(path).readAsBytes();
      codec = await ui.instantiateImageCodec(bytes, targetWidth: 512);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } catch (_) {
      throw const ServiceFailure(
        'Foto gagal dibaca. Pilih foto lain dalam format JPEG atau PNG.',
      );
    } finally {
      codec?.dispose();
    }
  },
);

class ScanState {
  const ScanState({
    this.imagePath,
    this.busy = false,
    this.analyzing = false,
    this.error,
  });
  final String? imagePath;
  final bool busy;
  final bool analyzing;
  final String? error;
}

final scanProvider = NotifierProvider<ScanController, ScanState>(
  ScanController.new,
);

class ScanController extends Notifier<ScanState> {
  @override
  ScanState build() => const ScanState();
  void clear() {
    if (!state.busy) state = const ScanState();
  }

  Future<void> select(String path) async {
    if (state.busy) return;
    final previous = state.imagePath;
    state = ScanState(imagePath: previous, busy: true);
    try {
      await ref.read(imageValidatorProvider)(path);
      if (ref.mounted) state = ScanState(imagePath: path);
    } catch (error) {
      if (ref.mounted) {
        state = ScanState(
          imagePath: previous,
          error: error is ServiceFailure
              ? error.message
              : 'Foto gagal dibaca. Pilih foto lain.',
        );
      }
    }
  }

  Future<void> pick({bool recover = false}) async {
    if (state.busy) return;
    final previous = state.imagePath;
    state = ScanState(imagePath: previous, busy: true);
    try {
      final gallery = ref.read(galleryServiceProvider);
      final path = await (recover ? gallery.recover() : gallery.pick());
      if (!ref.mounted) return;
      state = ScanState(imagePath: previous);
      if (path != null) await select(path);
    } catch (_) {
      if (ref.mounted) {
        state = ScanState(
          imagePath: previous,
          error:
              'Galeri tidak dapat dibuka. Periksa izin foto pada pengaturan aplikasi, lalu coba lagi.',
        );
      }
    }
  }

  Future<DetectionResult?> analyze() async {
    final path = state.imagePath;
    if (path == null || state.busy) return null;
    state = ScanState(imagePath: path, busy: true, analyzing: true);
    try {
      final result = await ref.read(detectionServiceProvider).analyze(path);
      if (ref.mounted) state = ScanState(imagePath: path);
      return result;
    } catch (error) {
      if (ref.mounted) {
        state = ScanState(
          imagePath: path,
          error: error is ServiceFailure
              ? error.message
              : 'Analisis gagal. Coba lagi atau pilih foto lain.',
        );
      }
      return null;
    }
  }
}
