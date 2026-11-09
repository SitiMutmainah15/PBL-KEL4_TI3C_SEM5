import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'detection.dart';
import 'groq_caption_service.dart';

/// Teks pendamping hasil satu permintaan ke Groq.
class LeafCaption {
  const LeafCaption({
    required this.summary,
    required this.treatment,
    required this.photoTip,
    required this.imageMatches,
    this.detectedLabel = '',
  });

  final String summary;
  final String treatment;
  final String photoTip;

  /// `false` bila model bahasa menilai foto tidak layak dibaca.
  final bool imageMatches;

  /// Nama kelas yang disebut model bahasa, bisa berbeda dari keluaran model.
  final String detectedLabel;

  static LeafCaption? fromJson(Object? raw) {
    if (raw is! Map) return null;

    String? text(String key, int limit) {
      final value = raw[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return trimmed.length > limit ? trimmed.substring(0, limit) : trimmed;
    }

    final summary = text('ringkasan', 1200);
    final treatment = text('penanganan', 1200);
    final photoTip = text('saranFoto', 800);
    if (summary == null || treatment == null || photoTip == null) return null;

    final matches = raw['gambarSesuai'];
    final label = raw['labelTerdeteksi'];
    return LeafCaption(
      summary: summary,
      treatment: treatment,
      photoTip: photoTip,
      imageMatches: matches is bool ? matches : true,
      detectedLabel: label is String ? label.trim() : '',
    );
  }
}

/// Melempar [ServiceFailure] yang pesannya sudah layak ditampilkan.
abstract interface class CaptionService {
  Future<LeafCaption> describe({
    required DetectionResult result,
    required String locale,
  });
}

/// Aplikasi selalu memanggil Groq langsung. Bila APK dibangun tanpa
/// GROQ_API_KEY, layar hasil menampilkan pesan dan keterangan umum.
final captionServiceProvider = Provider<CaptionService>(
  (ref) => GroqCaptionService(),
);

/// Menyimpan permintaan caption per hasil supaya membuka layar yang sama
/// tidak memakai kuota layanan dua kali.
class CaptionCache {
  final Map<String, Future<LeafCaption>> _pending = {};

  String _key(DetectionResult result) =>
      '${result.id}|${result.predictedClass.name}|'
      '${result.confidence.toStringAsFixed(4)}|${result.imagePath}';

  Future<LeafCaption> load(DetectionResult result, CaptionService service) {
    final key = _key(result);
    final existing = _pending[key];
    if (existing != null) return existing;
    final future = service.describe(result: result, locale: 'id');
    _pending[key] = future;
    // Kegagalan tidak disimpan, supaya tombol coba lagi benar-benar memanggil ulang.
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          _pending.remove(key);
        },
      ),
    );
    return future;
  }

  void invalidate(DetectionResult result) {
    _pending.remove(_key(result));
  }
}

final captionCacheProvider = Provider<CaptionCache>((ref) => CaptionCache());
