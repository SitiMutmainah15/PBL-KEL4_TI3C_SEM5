import 'dart:convert';
import 'dart:io';

import 'package:ecoplant/app.dart';
import 'package:ecoplant/core/storage/photo_storage.dart';
import 'package:ecoplant/core/theme.dart';
import 'package:ecoplant/core/widgets.dart';
import 'package:ecoplant/features/detection/detection.dart';
import 'package:ecoplant/features/detection/groq_caption_service.dart';
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

import '../test/fixtures.dart';

class _HostPhotoStorage extends TestPhotoStorage {
  const _HostPhotoStorage();

  @override
  Future<void> delete(String imagePath) async {
    await File(imagePath).delete();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const offlineDevice = bool.fromEnvironment('TCTS_OFFLINE_DEVICE');
  const liveGroq = bool.fromEnvironment('TCTS_LIVE_GROQ');
  late Directory directory;
  late String photoA;
  late String photoB;
  late LocalHistoryRepository repository;
  late TestGallery gallery;

  LocalHistoryRepository createRepository() => LocalHistoryRepository(
    databasePath: '${directory.path}/tcts.db',
    photoStorage: Platform.isAndroid ? null : const _HostPhotoStorage(),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ecoplant_tcts_');
    repository = createRepository();
    gallery = TestGallery();
    Future<String> writePhoto(String name, int red, int green, int blue) async {
      final image = img.Image(width: 64, height: 64);
      img.fill(image, color: img.ColorRgb8(red, green, blue));
      return (await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(img.encodePng(image))).path;
    }

    photoA = await writePhoto('a', 80, 150, 40);
    photoB = await writePhoto('b', 200, 100, 60);
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  Future<void> openApp(WidgetTester tester, {CaptionService? caption}) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          galleryServiceProvider.overrideWithValue(gallery),
          historyRepositoryProvider.overrideWithValue(repository),
          photoStorageProvider.overrideWithValue(const TestPhotoStorage()),
          captionServiceProvider.overrideWithValue(
            caption ?? const TestCaptionService(),
          ),
        ],
        child: MaterialApp(theme: appTheme(), home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> selectPhoto(WidgetTester tester, String path) async {
    gallery.path = path;
    await tap(tester, find.text('Scan Daun').last);
    await tap(tester, find.text('Pilih dari Galeri'));
    expect(find.text('Periksa foto Anda'), findsOneWidget);
  }

  Future<void> analyze(WidgetTester tester) async {
    await tap(tester, find.widgetWithText(FilledButton, 'Analisis'));
  }

  Future<void> restart(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await repository.close();
    repository = createRepository();
    await openApp(tester);
  }

  Future<void> openHistory(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(NavigationDestination, 'Riwayat'));
    await tester.pumpAndSettle();
  }

  DetectionResult saved(String id, LeafClass label, String path, int day) =>
      DetectionResult(
        id: id,
        imagePath: path,
        predictedClass: label,
        confidence: .8,
        createdAt: DateTime.utc(2026, 11, day),
        modelVersion: 'fixture',
      );

  testWidgets('TS-006 TC-011: pembatalan galeri mempertahankan foto A', (
    tester,
  ) async {
    await openApp(tester);
    await selectPhoto(tester, photoA);
    gallery.path = null;
    await tap(tester, find.text('Ganti Foto'));
    expect(tester.widget<LeafPhoto>(find.byType(LeafPhoto)).path, photoA);
    expect(find.widgetWithText(FilledButton, 'Analisis'), findsOneWidget);
  });

  testWidgets('TS-007 TC-014: mengganti foto A dengan B sampai hasil', (
    tester,
  ) async {
    await openApp(tester);
    await selectPhoto(tester, photoA);
    gallery.path = photoB;
    await tap(tester, find.text('Ganti Foto'));
    expect(tester.widget<LeafPhoto>(find.byType(LeafPhoto)).path, photoB);
    await analyze(tester);
    expect(find.text('Hasil Deteksi'), findsOneWidget);
    expect(tester.widget<LeafPhoto>(find.byType(LeafPhoto)).path, photoB);
  });

  testWidgets('TS-008 TC-017: aset model rusak mempertahankan foto di Scan', (
    tester,
  ) async {
    const assetChannel = 'flutter/assets';
    const forestAsset = 'assets/models/forest.json';
    final messenger = tester.binding.defaultBinaryMessenger;
    final corruptForest = ByteData.sublistView(utf8.encode('{"features": -1}'));
    var forestRequested = false;
    rootBundle.evict(forestAsset);
    addTearDown(() {
      messenger.setMockMessageHandler(assetChannel, null);
      rootBundle.evict(forestAsset);
    });
    messenger.setMockMessageHandler(assetChannel, (message) async {
      if (message != null &&
          utf8.decode(Uint8List.sublistView(message)) == forestAsset) {
        forestRequested = true;
        return corruptForest;
      }
      return messenger.delegate.send(assetChannel, message);
    });

    await openApp(tester);
    await selectPhoto(tester, photoA);
    await analyze(tester);
    expect(forestRequested, isTrue);
    expect(
      find.textContaining('Model gagal dimuat atau dijalankan.'),
      findsOneWidget,
    );
    expect(find.text('Hasil Deteksi'), findsNothing);
    expect(tester.widget<LeafPhoto>(find.byType(LeafPhoto)).path, photoA);
  });

  testWidgets(
    'TS-009 TC-018: inferensi lokal pada HP yang disiapkan offline',
    (tester) async {
      await openApp(tester, caption: GroqCaptionService(apiKey: ''));
      await selectPhoto(tester, photoA);
      await analyze(tester);
      expect(find.text('Hasil Deteksi'), findsOneWidget);
      expect(find.text('Healthy'), findsOneWidget);
      expect(find.text('68.3%'), findsOneWidget);
      expect(tester.widget<LeafPhoto>(find.byType(LeafPhoto)).path, photoA);
    },
    skip: !offlineDevice,
  );

  testWidgets('TS-009 TC-019: hasil nyata sesuai acuan Random Forest', (
    tester,
  ) async {
    await openApp(tester, caption: GroqCaptionService(apiKey: ''));
    await selectPhoto(tester, photoA);
    await analyze(tester);
    // RGB (80, 150, 40), model banana-rf-81c683ad22b4: Python reference
    // yields Healthy with confidence 0.6828087167.
    expect(find.text('Healthy'), findsOneWidget);
    expect(find.text('68.3%'), findsOneWidget);
  });

  testWidgets('TS-010 TC-022: simpan sekali ke SQLite dan tampil di Riwayat', (
    tester,
  ) async {
    await openApp(tester);
    await selectPhoto(tester, photoA);
    await analyze(tester);
    await tap(tester, find.text('Simpan Riwayat'));
    final stored = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tersimpan'),
    );
    expect(stored.onPressed, isNull);
    expect(await repository.load(), hasLength(1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openHistory(tester);
    expect(find.text('Healthy'), findsOneWidget);
  });

  testWidgets('TS-011 TC-025: dua hasil SQLite tampil terbaru dahulu', (
    tester,
  ) async {
    await repository.save(saved('old', LeafClass.cordana, photoA, 1));
    await repository.save(saved('new', LeafClass.healthy, photoB, 2));
    await openApp(tester);
    await openHistory(tester);
    expect(
      tester.getTopLeft(find.text('Healthy')).dy,
      lessThan(tester.getTopLeft(find.text('Cordana')).dy),
    );
  });

  testWidgets('TS-011 TC-028: buka ulang shell dan SQLite, detail tetap ada', (
    tester,
  ) async {
    await repository.save(saved('persistent', LeafClass.cordana, photoA, 1));
    await openApp(tester);
    await openHistory(tester);
    expect(find.text('Cordana'), findsOneWidget);
    await restart(tester);
    await openHistory(tester);
    await tap(tester, find.text('Cordana'));
    expect(find.text('Detail Riwayat'), findsOneWidget);
    expect(tester.widget<LeafPhoto>(find.byType(LeafPhoto)).path, photoA);
    expect(await File(photoA).exists(), isTrue);
  });

  testWidgets(
    'TS-013 TC-031: Groq langsung menampilkan keterangan dan pembanding',
    (tester) async {
      expect(
        groqApiKey.isNotEmpty,
        isTrue,
        reason: 'Masukkan GROQ_API_KEY untuk skenario live.',
      );
      final reference = await rootBundle.load(
        'assets/references/healthy/01.jpg',
      );
      final photo = await File('${directory.path}/real-leaf.jpg').writeAsBytes(
        reference.buffer.asUint8List(
          reference.offsetInBytes,
          reference.lengthInBytes,
        ),
      );
      await openApp(tester, caption: GroqCaptionService());
      await selectPhoto(tester, photo.path);
      await analyze(tester);
      await tester.scrollUntilVisible(
        find.text('Foto pembanding'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tentang kondisi ini'), findsOneWidget);
      expect(find.text('Penanganan awal'), findsOneWidget);
      expect(find.text('Foto pembanding'), findsOneWidget);
    },
    skip: !liveGroq,
  );

  testWidgets(
    'TS-013 TC-032: layanan tanpa kunci memunculkan keterangan umum',
    (tester) async {
      await openApp(tester, caption: GroqCaptionService(apiKey: ''));
      await selectPhoto(tester, photoA);
      await analyze(tester);
      expect(find.text('Hasil Deteksi'), findsOneWidget);
      await tap(tester, find.text('Tampilkan keterangan umum'));
      await tester.scrollUntilVisible(
        find.text('Penanganan awal'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Penanganan awal'), findsOneWidget);
    },
  );

  testWidgets(
    'TS-014 TC-035: hapus dari UI dan SQLite tetap kosong saat dibuka ulang',
    (tester) async {
      await repository.save(saved('delete', LeafClass.cordana, photoA, 1));
      await openApp(tester);
      await openHistory(tester);
      await tap(tester, find.byTooltip('Hapus riwayat'));
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada hasil deteksi.'), findsOneWidget);
      await restart(tester);
      await openHistory(tester);
      expect(find.text('Belum ada hasil deteksi.'), findsOneWidget);
      expect(await repository.load(), isEmpty);
      expect(await File(photoA).exists(), isFalse);
    },
  );
}
