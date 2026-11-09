import 'dart:io';

import 'package:ecoplant/app.dart';
import 'package:ecoplant/features/detection/detection.dart';
import 'package:ecoplant/features/detection/leaf_caption.dart';
import 'package:ecoplant/features/history/history_repository.dart';
import 'package:ecoplant/features/scan/scan_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

/// Integration test on a real device: no camera, gallery, TFLite or Firebase.
/// Those edges are replaced by fakes so the screens run as they do on a phone.
class _MemoryHistory implements HistoryRepository {
  _MemoryHistory([List<DetectionResult>? seed]) : items = [...?seed];
  final List<DetectionResult> items;

  @override
  Future<List<DetectionResult>> load() async => [...items];

  @override
  Future<void> save(DetectionResult result) async => items.add(result);
}

class _FixedGallery implements GalleryService {
  _FixedGallery(this.path);
  final String path;

  @override
  Future<String?> pick() async => path;

  @override
  Future<String?> recover() async => null;
}

/// Galeri yang menolak dibuka, seperti saat izin foto belum diberikan.
class _BrokenGallery implements GalleryService {
  @override
  Future<String?> pick() async => throw Exception('gallery denied');

  @override
  Future<String?> recover() async => null;
}

class _FixedDetection implements DetectionService {
  _FixedDetection(this.result);
  final DetectionResult result;

  @override
  Future<DetectionResult> analyze(String imagePath) async => result;
}

class _FakeCaption implements CaptionService {
  _FakeCaption({
    this.failuresLeft = 0,
    this.detectedLabel = 'sigatoka',
    this.imageMatches = true,
  });

  int failuresLeft;
  final String detectedLabel;
  final bool imageMatches;
  int calls = 0;

  @override
  Future<LeafCaption> describe({
    required DetectionResult result,
    required String locale,
  }) async {
    calls++;
    if (failuresLeft > 0) {
      failuresLeft--;
      throw const ServiceFailure('Keterangan uji gagal dimuat.');
    }
    return LeafCaption(
      summary: 'Ringkasan uji untuk ${result.predictedClass.label}.',
      treatment: 'Penanganan uji untuk ${result.predictedClass.label}.',
      photoTip: 'Saran foto uji.',
      imageMatches: imageMatches,
      detectedLabel: detectedLabel,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String imagePath;
  late String textPath;
  late DetectionResult sample;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('ecoplant_it_');
    imagePath = '${tempDir.path}/leaf.png';
    await File(
      imagePath,
    ).writeAsBytes(img.encodePng(img.Image(width: 64, height: 64)));
    textPath = '${tempDir.path}/not-an-image.txt';
    await File(textPath).writeAsString('bukan gambar');
    sample = DetectionResult(
      id: 'it-1',
      imagePath: imagePath,
      predictedClass: LeafClass.sigatoka,
      confidence: 0.92,
      createdAt: DateTime(2026, 11, 6, 9, 30),
      modelVersion: 'integration-test',
    );
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  Future<void> pumpApp(
    WidgetTester tester, {
    HistoryRepository? history,
    GalleryService? gallery,
    CaptionService? caption,
    Duration splash = const Duration(seconds: 4),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWith(
            (ref) => history ?? _MemoryHistory(),
          ),
          galleryServiceProvider.overrideWith(
            (ref) => gallery ?? _FixedGallery(imagePath),
          ),
          detectionServiceProvider.overrideWith(
            (ref) => _FixedDetection(sample),
          ),
          captionServiceProvider.overrideWith(
            (ref) => caption ?? _FakeCaption(),
          ),
        ],
        child: const EcoPlantApp(),
      ),
    );
    await tester.pump(splash);
    await tester.pumpAndSettle();
  }

  /// Beranda -> tab Scan -> pilih foto dari galeri -> Analisis.
  Future<void> openResult(WidgetTester tester) async {
    await tester.tap(find.text('Scan Daun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih dari Galeri'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Analisis'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Analisis'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTop(WidgetTester tester) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
  }

  testWidgets('1. splash tampil lalu berpindah ke beranda', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWith((ref) => _MemoryHistory()),
        ],
        child: const EcoPlantApp(),
      ),
    );

    expect(find.text('EcoPlant'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cek kesehatan'), findsOneWidget);
    expect(find.text('Belum ada hasil deteksi.'), findsOneWidget);
  });

  testWidgets('2. pilih foto, analisis, lalu simpan ke riwayat', (
    tester,
  ) async {
    final history = _MemoryHistory();
    await pumpApp(tester, history: history);

    await tester.tap(find.text('Scan Daun'));
    await tester.pumpAndSettle();
    expect(find.text('Mulai dari satu daun.'), findsOneWidget);

    await tester.tap(find.text('Pilih dari Galeri'));
    await tester.pumpAndSettle();
    expect(find.text('Periksa foto Anda'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Analisis'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Analisis'));
    await tester.pumpAndSettle();

    expect(find.text('Hasil Deteksi'), findsOneWidget);
    expect(find.text('Sigatoka'), findsOneWidget);
    expect(find.text('92.0%'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Simpan Riwayat'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Simpan Riwayat'));
    await tester.pumpAndSettle();

    expect(find.text('Hasil berhasil disimpan ke riwayat.'), findsOneWidget);
    expect(history.items.single.predictedClass, LeafClass.sigatoka);
  });

  testWidgets('3. riwayat menampilkan hasil tersimpan dan detailnya', (
    tester,
  ) async {
    await pumpApp(tester, history: _MemoryHistory([sample]));

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Pemeriksaan daun Anda'), findsOneWidget);
    expect(find.text('Confidence 92.0%'), findsOneWidget);

    await tester.tap(find.text('Sigatoka'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Riwayat'), findsOneWidget);
    expect(find.text('Sigatoka'), findsOneWidget);
  });

  testWidgets('4. keterangan kondisi tampil di layar hasil', (tester) async {
    await pumpApp(tester);

    await openResult(tester);

    expect(find.text('Tentang kondisi ini'), findsOneWidget);
    expect(find.text('Ringkasan uji untuk Sigatoka.'), findsOneWidget);
    expect(find.text('Penanganan awal'), findsOneWidget);
    expect(find.text('Foto pembanding'), findsOneWidget);
    expect(find.text('Saran foto berikutnya'), findsOneWidget);
  });

  testWidgets('5. keterangan tidak diminta ulang untuk hasil yang sama', (
    tester,
  ) async {
    final caption = _FakeCaption();
    await pumpApp(tester, caption: caption);

    await openResult(tester);
    expect(caption.calls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Analisis'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Analisis'));
    await tester.pumpAndSettle();

    expect(find.text('Ringkasan uji untuk Sigatoka.'), findsOneWidget);
    expect(caption.calls, 1);
  });

  testWidgets('6. keterangan gagal menyediakan keterangan umum', (
    tester,
  ) async {
    await pumpApp(tester, caption: _FakeCaption(failuresLeft: 99));

    await openResult(tester);

    expect(find.text('Keterangan uji gagal dimuat.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tampilkan keterangan umum'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tampilkan keterangan umum'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Sigatoka merupakan penyakit bercak daun'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Pantau perkembangan bercak pada daun'),
      findsOneWidget,
    );
  });

  testWidgets('7. coba lagi memuat keterangan setelah gagal', (tester) async {
    final caption = _FakeCaption(failuresLeft: 1);
    await pumpApp(tester, caption: caption);

    await openResult(tester);
    expect(find.text('Keterangan uji gagal dimuat.'), findsOneWidget);

    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Ringkasan uji untuk Sigatoka.'), findsOneWidget);
    expect(caption.calls, 2);
  });

  testWidgets('8. label model bahasa yang berbeda diberi penjelasan', (
    tester,
  ) async {
    await pumpApp(tester, caption: _FakeCaption(detectedLabel: 'cordana'));

    await openResult(tester);

    expect(
      find.textContaining('Model bahasa menyebut Cordana'),
      findsOneWidget,
    );
    expect(
      find.textContaining('sedangkan model gambar menyebut Sigatoka'),
      findsOneWidget,
    );
  });

  testWidgets('9. foto yang dinilai sulit dibaca memakai judul khusus', (
    tester,
  ) async {
    await pumpApp(tester, caption: _FakeCaption(imageMatches: false));

    await openResult(tester);

    expect(find.text('Foto ini sulit dibaca'), findsOneWidget);
    expect(find.text('Saran foto berikutnya'), findsNothing);
    expect(find.text('Saran foto uji.'), findsOneWidget);
  });

  testWidgets('10. galeri gagal dibuka menampilkan pesan izin', (tester) async {
    await pumpApp(tester, gallery: _BrokenGallery());

    await tester.tap(find.text('Scan Daun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih dari Galeri'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Galeri tidak dapat dibuka.'), findsOneWidget);
    await scrollTop(tester);
    expect(find.text('Mulai dari satu daun.'), findsOneWidget);
    expect(find.text('Buka Kamera'), findsOneWidget);
  });

  testWidgets('11. berkas yang bukan gambar ditolak', (tester) async {
    await pumpApp(tester, gallery: _FixedGallery(textPath));

    await tester.tap(find.text('Scan Daun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih dari Galeri'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Foto gagal dibaca. Pilih foto lain'),
      findsOneWidget,
    );
    await scrollTop(tester);
    expect(find.text('Mulai dari satu daun.'), findsOneWidget);
  });

  testWidgets('12. batalkan foto mengosongkan pilihan', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Scan Daun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih dari Galeri'));
    await tester.pumpAndSettle();
    expect(find.text('Periksa foto Anda'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Batalkan Foto'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Batalkan Foto'));
    await tester.pumpAndSettle();
    await scrollTop(tester);

    expect(find.text('Mulai dari satu daun.'), findsOneWidget);
    expect(find.text('Belum ada foto dipilih.'), findsOneWidget);
  });

  testWidgets('13. scan ulang mengosongkan hasil sebelumnya', (tester) async {
    await pumpApp(tester);

    await openResult(tester);

    await tester.scrollUntilVisible(
      find.text('Scan Ulang'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Scan Ulang'));
    await tester.pumpAndSettle();
    await scrollTop(tester);

    expect(find.text('Mulai dari satu daun.'), findsOneWidget);
    expect(find.text('Belum ada foto dipilih.'), findsOneWidget);
  });
}
