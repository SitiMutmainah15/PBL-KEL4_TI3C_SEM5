import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'detection.dart';
import 'leaf_caption.dart';

/// Kunci Groq disuntikkan saat build lewat
/// `--dart-define=GROQ_API_KEY=gsk_...`, tidak ditulis di kode sumber.
const groqApiKey = String.fromEnvironment('GROQ_API_KEY');
const groqModel = String.fromEnvironment(
  'GROQ_MODEL',
  defaultValue: 'qwen/qwen3.8-27b',
);
const _groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';

const _leafClasses = ['healthy', 'sigatoka', 'cordana', 'pestalotiopsis'];

// Prompt dan skema disalin dari backend/app/groq_client.py supaya jawaban
// tetap sama dengan versi server.
const _systemPrompt =
    'Anda asisten penyuluh pertanian untuk aplikasi EcoPlant yang membantu pengguna '
    'memeriksa daun pisang. Model klasifikasi di perangkat sudah memberi satu label dan skor. Tugas Anda '
    'hanya menulis teks pendamping dalam Bahasa Indonesia yang tenang dan konkret.\n\n'
    'Aturan yang tidak boleh dilanggar:\n'
    '1. Jangan pernah menyebut diagnosis pasti, persentase keyakinan baru, nama bahan aktif, dosis, atau '
    'merek pestisida. Saran bersifat pengamatan dan tindakan awal yang aman.\n'
    '2. Jangan mengarang gejala yang tidak terlihat. Jika gambar tidak jelas atau bukan daun pisang, '
    'katakan apa adanya di field sesuai skema.\n'
    '3. Panjang tiap field: ringkasan 2 sampai 4 kalimat, penanganan 2 sampai 4 kalimat, '
    'saranFoto 1 sampai 3 kalimat.\n'
    '4. Jangan memakai tanda pisah panjang (em dash), tanda seru, atau huruf kapital berlebihan.\n'
    '5. Tulis dalam bentuk kalimat utuh, bukan daftar berbutir, dan tanpa judul atau markdown.\n'
    '6. Selalu jujur bahwa ini prediksi model, bukan diagnosis. Sampaikan pengingat itu tepat satu kali '
    'saja di seluruh jawaban, jangan diulang di field lain.';

const _responseSchema = {
  'type': 'object',
  'properties': {
    'labelTerdeteksi': {'type': 'string', 'enum': _leafClasses},
    'gambarSesuai': {'type': 'boolean'},
    'ringkasan': {'type': 'string'},
    'penanganan': {'type': 'string'},
    'saranFoto': {'type': 'string'},
  },
  'required': [
    'labelTerdeteksi',
    'gambarSesuai',
    'ringkasan',
    'penanganan',
    'saranFoto',
  ],
  'additionalProperties': false,
};

const _labelContext = {
  'healthy': (
    'Healthy',
    'Daun tidak menunjukkan pola bercak penyakit yang dikenali model.',
  ),
  'sigatoka': (
    'Sigatoka',
    'Bercak atau garis memanjang kekuningan hingga cokelat kehitaman, sering menyatu '
        'mengikuti arah tulang daun.',
  ),
  'cordana': (
    'Cordana',
    'Bercak cokelat keabu-abuan berbentuk lonjong dengan tepi lebih gelap, biasanya '
        'tidak mengikuti arah tulang daun.',
  ),
  'pestalotiopsis': (
    'Pestalotiopsis',
    'Bercak kecil kecokelatan yang melebar, sering dikelilingi halo kekuningan, dan '
        'dapat menyatu membentuk area kering.',
  ),
};

String _userPrompt(String label, double confidence, String locale) {
  final (display, traits) = _labelContext[label]!;
  return 'Label dari model di perangkat: $display ($label).\n'
      'Skor keluaran model: ${(confidence * 100).toStringAsFixed(1)} persen. '
      'Skor ini bukan tingkat kepastian diagnosis.\n'
      'Ciri umum kelas tersebut menurut dataset latih: $traits\n'
      'Bahasa keluaran: $locale.\n\n'
      'Amati foto yang dilampirkan, lalu isi skema JSON. Isi labelTerdeteksi dengan label model '
      'di perangkat, kecuali pengamatan Anda pada foto jelas menunjukkan kelas lain; dalam hal itu '
      'tulis kelas yang Anda amati. Setel gambarSesuai ke false bila foto bukan daun pisang, terlalu '
      'gelap, buram, atau daunnya tidak terlihat utuh, dan tetap tulis teks yang berguna untuk kondisi '
      'itu. Field saranFoto berisi petunjuk cara memotret ulang agar ciri daun lebih mudah dibaca, '
      'misalnya arah cahaya, jarak, sudut, atau bagian daun yang perlu masuk bingkai.';
}

/// Perkecil ke sisi terpanjang 1024 px dan simpan ulang sebagai JPEG,
/// sama seperti `prepare()` di backend. Dijalankan di isolate terpisah.
Uint8List? _shrinkToJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  const maxEdge = 1024;
  final resized =
      oriented.width >= oriented.height && oriented.width > maxEdge
      ? img.copyResize(oriented, width: maxEdge)
      : oriented.height > maxEdge
      ? img.copyResize(oriented, height: maxEdge)
      : oriented;
  return img.encodeJpg(resized, quality: 85);
}

/// Memanggil Groq langsung dari perangkat, tanpa backend perantara.
class GroqCaptionService implements CaptionService {
  GroqCaptionService({http.Client? client, String? apiKey, String? model})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? groqApiKey,
      _model = model ?? groqModel;

  final http.Client _client;
  final String _apiKey;
  final String _model;

  static const _timeout = Duration(seconds: 50);

  @override
  Future<LeafCaption> describe({
    required DetectionResult result,
    required String locale,
  }) async {
    if (_apiKey.isEmpty) {
      throw const ServiceFailure(
        'Kunci Groq belum dipasang di aplikasi. Build ulang dengan '
        '--dart-define=GROQ_API_KEY=...',
      );
    }

    final label = result.predictedClass.name;
    if (!_labelContext.containsKey(label)) {
      throw const ServiceFailure('Label hasil deteksi tidak dikenal.');
    }

    final file = File(result.imagePath);
    if (!await file.exists()) {
      throw const ServiceFailure(
        'Foto tidak ditemukan di perangkat, jadi keterangan tambahan tidak dapat dibuat.',
      );
    }

    final jpeg = await compute(_shrinkToJpeg, await file.readAsBytes());
    if (jpeg == null) {
      throw const ServiceFailure('Foto tidak dapat dibaca sebagai gambar.');
    }

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': _userPrompt(label, result.confidence, locale),
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,${base64Encode(jpeg)}',
              },
            },
          ],
        },
      ],
      'temperature': 0.7,
      'top_p': 0.8,
      'max_completion_tokens': 900,
      'reasoning_effort': 'none',
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'ecoplant_caption',
          'strict': true,
          'schema': _responseSchema,
        },
      },
    });

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_groqEndpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const ServiceFailure('Model terlalu lama menjawab. Coba lagi.');
    } catch (_) {
      throw const ServiceFailure(
        'Tidak dapat menghubungi Groq. Periksa koneksi internet HP.',
      );
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 401:
        throw const ServiceFailure('Kunci Groq ditolak. Periksa GROQ_API_KEY.');
      case 429:
        throw const ServiceFailure(
          'Batas permintaan Groq tercapai. Tunggu sebentar lalu coba lagi.',
        );
      default:
        debugPrint('Groq ${response.statusCode}: ${response.body}');
        throw const ServiceFailure('Model gagal membuat keterangan. Coba lagi.');
    }

    final caption = LeafCaption.fromJson(_extractJson(response.body, label));
    if (caption == null) {
      throw const ServiceFailure(
        'Keterangan tambahan tidak lengkap. Coba muat ulang.',
      );
    }
    return caption;
  }

  Map<String, dynamic> _extractJson(String raw, String expectedLabel) {
    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final choices = payload['choices'] as List;
      final message = (choices.first as Map)['message'] as Map;
      var text = (message['content'] as String).trim();
      if (text.startsWith('```')) {
        text = text.substring(text.indexOf('\n') + 1);
        text = text.substring(0, text.lastIndexOf('```'));
      }
      final parsed = Map<String, dynamic>.from(jsonDecode(text) as Map);
      if (!_leafClasses.contains(parsed['labelTerdeteksi'])) {
        parsed['labelTerdeteksi'] = expectedLabel;
      }
      return parsed;
    } catch (_) {
      throw const ServiceFailure('Jawaban model tidak dapat dibaca.');
    }
  }
}
