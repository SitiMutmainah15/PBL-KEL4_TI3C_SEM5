import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'detection.dart';
import 'groq_caption_service.dart';

/// Alamat backend caption. Ubah lewat
/// `--dart-define=ECOPLANT_API_BASE_URL=http://host:8080`.
String get captionApiBaseUrl {
  const configured = String.fromEnvironment('ECOPLANT_API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080';
  return 'http://127.0.0.1:8080';
}

/// Teks pendamping hasil satu permintaan ke backend.
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

  /// Nama kelas yang disebut model bahasa, bisa berbeda dari keluaran TFLite.
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

abstract interface class CaptionService {
  Future<LeafCaption> describe({
    required DetectionResult result,
    required String locale,
  });
}

/// Melempar [ServiceFailure] yang pesannya sudah layak ditampilkan.
class HttpCaptionService implements CaptionService {
  HttpCaptionService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? captionApiBaseUrl).replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  /// Batas menyambung sengaja pendek. Salah alamat adalah penyebab tersering,
  /// dan menunggu satu menit hanya membuat pengguna melihat status memuat.
  static const _connectTimeout = Duration(seconds: 8);
  static const _totalTimeout = Duration(seconds: 50);

  @override
  Future<LeafCaption> describe({
    required DetectionResult result,
    required String locale,
  }) async {
    final file = File(result.imagePath);
    if (!await file.exists()) {
      throw const ServiceFailure(
        'Foto tidak ditemukan di perangkat, jadi keterangan tambahan tidak dapat dibuat.',
      );
    }

    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/v1/caption'))
          ..fields['label'] = result.predictedClass.name
          ..fields['confidence'] = result.confidence.toStringAsFixed(4)
          ..fields['locale'] = locale
          ..files.add(await http.MultipartFile.fromPath('image', file.path));

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_connectTimeout);
      response = await http.Response.fromStream(
        streamed,
      ).timeout(_totalTimeout);
    } on TimeoutException {
      throw ServiceFailure(
        'Layanan keterangan di $_baseUrl tidak menjawab. '
        'Periksa apakah backend berjalan dan alamatnya benar.',
      );
    } catch (_) {
      throw ServiceFailure(
        'Tidak dapat menghubungi layanan keterangan di $_baseUrl. '
        'Periksa koneksi dan pastikan backend berjalan.',
      );
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200) {
      final message = body?['error'];
      throw ServiceFailure(
        message is String && message.trim().isNotEmpty
            ? message.trim()
            : 'Keterangan tambahan gagal dibuat. Coba lagi nanti.',
      );
    }

    final caption = LeafCaption.fromJson(body);
    if (caption == null) {
      throw const ServiceFailure(
        'Keterangan tambahan tidak lengkap. Coba muat ulang.',
      );
    }
    return caption;
  }
}

/// Bila build menyertakan GROQ_API_KEY, aplikasi memanggil Groq langsung.
/// Tanpa kunci itu, aplikasi kembali memakai backend di `backend/`.
final captionServiceProvider = Provider<CaptionService>(
  (ref) => groqApiKey.isNotEmpty ? GroqCaptionService() : HttpCaptionService(),
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
