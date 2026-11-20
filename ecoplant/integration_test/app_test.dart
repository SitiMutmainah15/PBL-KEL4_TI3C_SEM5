import 'dart:io';

import 'package:ecoplant/app.dart';
import 'package:ecoplant/core/storage/photo_storage.dart';
import 'package:ecoplant/features/detection/detection.dart';
import 'package:ecoplant/features/detection/leaf_caption.dart';
import 'package:ecoplant/features/history/history_repository.dart';
import 'package:ecoplant/features/history/local_history_repository.dart';
import 'package:ecoplant/features/scan/scan_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

/// Exercises the Flutter screens on Android with controlled service responses.
class _MemoryHistory implements HistoryRepository {
  _MemoryHistory([List<DetectionResult>? seed]) : items = [...?seed];
  final List<DetectionResult> items;

  @override
  Future<List<DetectionResult>> load() async => [...items];

  @override
  Future<void> save(DetectionResult result) async => items.add(result);

  @override
  Future<void> update(DetectionResult result) async {
    final index = items.indexWhere((item) => item.id == result.id);
    if (index >= 0) items[index] = result;
  }

  @override
  Future<void> delete(String id) async =>
      items.removeWhere((item) => item.id == id);
}

class _MemoryPhotoStorage implements PhotoStorage {
  @override
  Future<String> saveOriginal(
    String sourcePath, {
    bool deleteTemporarySource = false,
  }) async => sourcePath;

  @override
  Future<File> thumbnail(String imagePath) async => File(imagePath);

  @override
  Future<void> delete(String imagePath) async {}
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
          photoStorageProvider.overrideWith((ref) => _MemoryPhotoStorage()),
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

  Future<void> showInViewport(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pumpAndSettle();
  }

  /// Beranda -> tab Scan -> pilih foto dari galeri -> Analisis.
  Future<void> openResult(WidgetTester tester) async {
    await tester.tap(find.text('Scan Daun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih dari Galeri'));
    await tester.pumpAndSettle();
    await showInViewport(tester, find.text('Analisis'));
    await tester.tap(find.text('Analisis'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTop(WidgetTester tester) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
  }

  Future<void> openHelpdesk(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Helpdesk'));
    await tester.pumpAndSettle();
    expect(find.text('Helpdesk'), findsOneWidget);
  }

  Future<void> tapSendEmail(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    for (
      var frame = 0;
      frame < 20 && tester.view.viewInsets.bottom > 0;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final button = find.widgetWithText(FilledButton, 'Kirim Email');
    await showInViewport(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('TS-015 TC-036: membuka dan menutup ketiga FAQ Helpdesk', (
    tester,
  ) async {
    await openHelpdesk(tester);
    for (final entry in {
      'Bagaimana cara memindai daun?': 'Buka tab Scan, lalu ambil foto',
      'Kenapa kamera atau galeri tidak terbuka?':
          'Periksa izin kamera dan foto',
      'Di mana hasil pemindaian sebelumnya?':
          'Buka tab Riwayat dan pilih hasil',
    }.entries) {
      final question = find.text(entry.key);
      final answer = find.textContaining(entry.value);
      await showInViewport(tester, question);
      await tester.tap(question);
      await tester.pumpAndSettle();
      expect(answer, findsOneWidget);
      await tester.tap(question);
      await tester.pumpAndSettle();
      expect(answer, findsNothing);
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Scan Daun'), findsOneWidget);
  });

  testWidgets('TS-016 TC-037: Helpdesk menolak deskripsi kosong dan spasi', (
    tester,
  ) async {
    await openHelpdesk(tester);
    await tapSendEmail(tester);
    expect(find.text('Isi deskripsi kendala.'), findsOneWidget);
    final description = find.byType(TextFormField);
    await showInViewport(tester, description);
    await tester.enterText(description, '   ');
    await tapSendEmail(tester);
    expect(find.text('Isi deskripsi kendala.'), findsOneWidget);
    expect(find.text('Helpdesk'), findsOneWidget);
  });

  testWidgets('TS-016 TC-038 / TC-039: URI draf dan kegagalan pembuka email', (
    tester,
  ) async {
    const launchChannel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.url_launcher_android.UrlLauncherApi.launchUrl',
      StandardMessageCodec(),
    );
    final messenger = tester.binding.defaultBinaryMessenger;
    Uri? openedEmail;
    messenger.setMockDecodedMessageHandler(launchChannel, (message) async {
      final arguments = message! as List<Object?>;
      openedEmail = Uri.parse(arguments.first! as String);
      return <Object?>[false];
    });
    addTearDown(
      () => messenger.setMockDecodedMessageHandler(launchChannel, null),
    );

    await openHelpdesk(tester);
    final category = find.byType(DropdownButtonFormField<String>);
    await showInViewport(tester, category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riwayat').last);
    await tester.pumpAndSettle();
    final description = find.byType(TextFormField);
    await showInViewport(tester, description);
    await tester.enterText(description, 'Riwayat tidak tampil & foto hilang?');
    await tapSendEmail(tester);
    expect(openedEmail?.scheme, 'mailto');
    expect(openedEmail?.path, 'fatahaidaraly@gmail.com');
    expect(openedEmail?.queryParameters, {
      'subject': 'Laporan kendala EcoPlant AI',
      'body': 'Kategori: Riwayat\n\nRiwayat tidak tampil & foto hilang?',
    });
    expect(
      find.textContaining('Aplikasi email tidak dapat dibuka.'),
      findsOneWidget,
    );
    expect(find.text('Helpdesk'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(description).controller?.text,
      'Riwayat tidak tampil & foto hilang?',
    );
  });

  testWidgets('TS-001 TC-001: splash tampil lalu berpindah ke Beranda', (
    tester,
  ) async {
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
    await showInViewport(tester, find.text('Belum ada hasil deteksi.'));
    expect(find.text('Belum ada hasil deteksi.'), findsOneWidget);
  });

  testWidgets(
    'TS-005 TC-010 / TS-010 TC-022: pilih foto dan simpan hasil dengan fixture',
    (tester) async {
      final history = _MemoryHistory();
      await pumpApp(tester, history: history);

      await tester.tap(find.text('Scan Daun'));
      await tester.pumpAndSettle();
      expect(find.text('Mulai dari satu daun.'), findsOneWidget);

      await tester.tap(find.text('Pilih dari Galeri'));
      await tester.pumpAndSettle();
      expect(find.text('Periksa foto Anda'), findsOneWidget);

      await showInViewport(tester, find.text('Analisis'));
      await tester.tap(find.text('Analisis'));
      await tester.pumpAndSettle();

      expect(find.text('Hasil Deteksi'), findsOneWidget);
      expect(find.text('Sigatoka'), findsOneWidget);
      expect(find.text('92.0%'), findsOneWidget);

      await showInViewport(tester, find.text('Simpan Riwayat'));
      await tester.tap(find.text('Simpan Riwayat'));
      await tester.pumpAndSettle();

      expect(find.text('Hasil berhasil disimpan ke riwayat.'), findsOneWidget);
      expect(history.items.single.predictedClass, LeafClass.sigatoka);
    },
  );

  testWidgets('TS-011 TC-027: buka detail hasil dari riwayat', (tester) async {
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

  testWidgets('TS-013 TC-031: keterangan dan foto pembanding dengan fixture', (
    tester,
  ) async {
    await pumpApp(tester);

    await openResult(tester);

    expect(find.text('Tentang kondisi ini'), findsOneWidget);
    expect(find.text('Ringkasan uji untuk Sigatoka.'), findsOneWidget);
    expect(find.text('Penanganan awal'), findsOneWidget);
    expect(find.text('Foto pembanding'), findsOneWidget);
    expect(find.text('Saran foto berikutnya'), findsOneWidget);
  });

  testWidgets(
    'Regresi TS-013: keterangan tidak diminta ulang untuk hasil yang sama',
    (tester) async {
      final caption = _FakeCaption();
      await pumpApp(tester, caption: caption);

      await openResult(tester);
      expect(caption.calls, 1);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await showInViewport(tester, find.text('Analisis'));
      await tester.tap(find.text('Analisis'));
      await tester.pumpAndSettle();

      expect(find.text('Ringkasan uji untuk Sigatoka.'), findsOneWidget);
      expect(caption.calls, 1);
    },
  );

  testWidgets(
    'TS-013 TC-032: keterangan umum saat layanan gagal dengan fixture',
    (tester) async {
      await pumpApp(tester, caption: _FakeCaption(failuresLeft: 99));

      await openResult(tester);

      expect(find.text('Keterangan uji gagal dimuat.'), findsOneWidget);
      await showInViewport(tester, find.text('Tampilkan keterangan umum'));
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
    },
  );

  testWidgets(
    'TS-013 TC-033: coba lagi memuat keterangan dan foto pembanding',
    (tester) async {
      final caption = _FakeCaption(failuresLeft: 1);
      await pumpApp(tester, caption: caption);

      await openResult(tester);
      expect(find.text('Keterangan uji gagal dimuat.'), findsOneWidget);

      await showInViewport(tester, find.text('Coba Lagi'));
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Ringkasan uji untuk Sigatoka.'), findsOneWidget);
      expect(find.text('Foto pembanding'), findsOneWidget);
      expect(caption.calls, 2);
    },
  );

  testWidgets(
    'Regresi TS-013: label model bahasa yang berbeda diberi penjelasan',
    (tester) async {
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
    },
  );

  testWidgets('Regresi TS-013: foto yang sulit dibaca memakai judul khusus', (
    tester,
  ) async {
    await pumpApp(tester, caption: _FakeCaption(imageMatches: false));

    await openResult(tester);

    expect(find.text('Foto ini sulit dibaca'), findsOneWidget);
    expect(find.text('Saran foto berikutnya'), findsNothing);
    expect(find.text('Saran foto uji.'), findsOneWidget);
  });

  testWidgets('Regresi TS-005: galeri gagal dibuka menampilkan pesan izin', (
    tester,
  ) async {
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

  testWidgets('TS-007 TC-012: berkas yang bukan gambar ditolak', (
    tester,
  ) async {
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

  testWidgets(
    'TS-011 TC-028 / TS-014 TC-035: persistensi SQLite dengan fixture',
    (tester) async {
      final sqlitePhoto = File('${tempDir.path}/sqlite-leaf.png');
      await sqlitePhoto.writeAsBytes(
        img.encodePng(img.Image(width: 32, height: 32)),
      );
      final repository = LocalHistoryRepository();
      final resultId = 'mobile-sqlite-${DateTime.now().microsecondsSinceEpoch}';
      final sqliteResult = DetectionResult(
        id: resultId,
        imagePath: sqlitePhoto.path,
        predictedClass: LeafClass.sigatoka,
        confidence: 0.9,
        createdAt: DateTime.now(),
        modelVersion: 'integration-test',
      );

      await repository.save(sqliteResult);
      expect(
        (await repository.load()).any((item) => item.id == resultId),
        isTrue,
      );

      await repository.close();
      final reopenedRepository = LocalHistoryRepository();
      expect(
        (await reopenedRepository.load()).any((item) => item.id == resultId),
        isTrue,
      );
      await reopenedRepository.delete(resultId);
      expect(
        (await reopenedRepository.load()).any((item) => item.id == resultId),
        isFalse,
      );
      expect(await sqlitePhoto.exists(), isFalse);
      await reopenedRepository.close();
    },
  );

  testWidgets('Regresi TS-007: batalkan foto mengosongkan pilihan', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Scan Daun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih dari Galeri'));
    await tester.pumpAndSettle();
    expect(find.text('Periksa foto Anda'), findsOneWidget);

    await showInViewport(tester, find.text('Batalkan Foto'));
    await tester.tap(find.text('Batalkan Foto'));
    await tester.pumpAndSettle();
    await scrollTop(tester);

    expect(find.text('Mulai dari satu daun.'), findsOneWidget);
    expect(find.text('Belum ada foto dipilih.'), findsOneWidget);
  });

  testWidgets('TS-009 TC-020: scan ulang mengosongkan pilihan foto', (
    tester,
  ) async {
    await pumpApp(tester);

    await openResult(tester);

    await showInViewport(tester, find.text('Scan Ulang'));
    await tester.tap(find.text('Scan Ulang'));
    await tester.pumpAndSettle();
    await scrollTop(tester);

    expect(find.text('Mulai dari satu daun.'), findsOneWidget);
    expect(find.text('Belum ada foto dipilih.'), findsOneWidget);
  });
}
