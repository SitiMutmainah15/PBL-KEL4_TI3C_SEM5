import 'dart:async';
import 'dart:io';

import 'package:ecoplant/app.dart';
import 'package:ecoplant/core/storage/photo_storage.dart';
import 'package:ecoplant/core/theme.dart';
import 'package:ecoplant/core/widgets.dart';
import 'package:ecoplant/features/detection/detection.dart';
import 'package:ecoplant/features/detection/leaf_caption.dart';
import 'package:ecoplant/features/detection/result_screen.dart';
import 'package:ecoplant/features/history/history_repository.dart';
import 'package:ecoplant/features/scan/scan_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File photo;
  late TestGallery gallery;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ecoplant_tcts_ui_');
    final bytes = await rootBundle.load('assets/references/healthy/01.jpg');
    photo = await File('${directory.path}/leaf.jpg').writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    gallery = TestGallery()..path = photo.path;
  });
  tearDown(() => directory.delete(recursive: true));

  DetectionResult sample({String id = 'fixture', double confidence = .87}) =>
      DetectionResult(
        id: id,
        imagePath: photo.path,
        predictedClass: LeafClass.sigatoka,
        confidence: confidence,
        createdAt: DateTime.utc(2026, 11, 20),
        modelVersion: 'test-only',
      );

  Future<void> open(
    WidgetTester tester, {
    TestHistory? history,
    Widget home = const AppShell(),
    DetectionService? detection,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          historyRepositoryProvider.overrideWithValue(history ?? TestHistory()),
          photoStorageProvider.overrideWithValue(const TestPhotoStorage()),
          galleryServiceProvider.overrideWithValue(gallery),
          captionServiceProvider.overrideWithValue(const TestCaptionService()),
          if (detection != null)
            detectionServiceProvider.overrideWithValue(detection),
        ],
        child: MaterialApp(theme: appTheme(), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        160,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> selectPhoto(WidgetTester tester) async {
    await tap(tester, find.widgetWithText(FilledButton, 'Scan Daun'));
    await tap(tester, find.text('Pilih dari Galeri'));
    expect(find.text('Periksa foto Anda'), findsOneWidget);
  }

  Future<void> openHistory(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(NavigationDestination, 'Riwayat'));
    await tester.pumpAndSettle();
  }

  testWidgets('TS-007 TC-013: foto rusak tidak menggantikan foto valid', (
    tester,
  ) async {
    await open(tester);
    await selectPhoto(tester);
    gallery.path = (await File(
      '${directory.path}/corrupt.jpg',
    ).writeAsString('not an image')).path;
    await tap(tester, find.text('Ganti Foto'));
    expect(find.textContaining('Foto gagal dibaca.'), findsOneWidget);
    expect(tester.widget<LeafPhoto>(find.byType(LeafPhoto)).path, photo.path);
  });

  testWidgets('TS-008 TC-016: hanya satu analisis berjalan', (tester) async {
    final pending = Completer<DetectionResult>();
    final detection = TestDetection(pending);
    await open(tester, detection: detection);
    await selectPhoto(tester);
    final action = find.widgetWithText(FilledButton, 'Analisis');
    await reveal(tester, action);
    await tester.tap(action);
    await tester.pump();
    expect(find.text('Menganalisis daun...'), findsOneWidget);
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    await tester.tap(action);
    expect(detection.calls, 1);
    pending.complete(sample());
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
  });

  testWidgets('TS-009 TC-021: dua nilai batas confidence tampil', (
    tester,
  ) async {
    for (final confidence in [0.0, 1.0]) {
      await open(
        tester,
        home: ResultScreen(result: sample(confidence: confidence)),
      );
      final text = find.text('${(confidence * 100).toStringAsFixed(1)}%');
      await reveal(tester, text);
      expect(text, findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        confidence,
      );
    }
  });

  Future<void> checkFailedSave(WidgetTester tester, TestHistory history) async {
    await open(
      tester,
      history: history,
      home: ResultScreen(result: sample()),
    );
    final save = find.widgetWithText(FilledButton, 'Simpan Riwayat');
    await tap(tester, save);
    expect(find.text('Riwayat gagal disimpan. Coba lagi.'), findsOneWidget);
    expect(find.text('Hasil Deteksi'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(history.items, isEmpty);
  }

  testWidgets('TS-010 TC-023: kegagalan menyimpan mempertahankan hasil', (
    tester,
  ) async {
    await checkFailedSave(tester, TestHistory(failSave: true));
  });

  testWidgets('TS-010 TC-024: coba simpan kembali menghasilkan satu entri', (
    tester,
  ) async {
    final history = TestHistory(failSave: true);
    await checkFailedSave(tester, history);
    history.failSave = false;
    await tap(tester, find.widgetWithText(FilledButton, 'Simpan Riwayat'));
    expect(find.text('Riwayat gagal disimpan. Coba lagi.'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Tersimpan'))
          .onPressed,
      isNull,
    );
    expect(history.items, hasLength(1));
    expect(history.saves, 2);
  });

  Future<void> checkFailedLoad(WidgetTester tester, TestHistory history) async {
    await open(tester, history: history);
    await openHistory(tester);
    expect(find.text('Riwayat gagal dimuat. Coba lagi.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  }

  testWidgets('TS-012 TC-029: gagal baca riwayat menyediakan Coba Lagi', (
    tester,
  ) async {
    await checkFailedLoad(tester, TestHistory(failLoad: true));
  });

  testWidgets('TS-012 TC-030: Coba Lagi memulihkan dua hasil', (tester) async {
    final history = TestHistory(failLoad: true);
    await checkFailedLoad(tester, history);
    history
      ..failLoad = false
      ..items = [sample(id: 'first'), sample(id: 'second')];
    await tap(tester, find.text('Coba Lagi'));
    expect(find.text('Riwayat gagal dimuat. Coba lagi.'), findsNothing);
    expect(find.text('Sigatoka'), findsNWidgets(2));
  });

  testWidgets('TS-014 TC-034: Batal mempertahankan entri yang dapat dibuka', (
    tester,
  ) async {
    final history = TestHistory(items: [sample()]);
    await open(tester, history: history);
    await openHistory(tester);
    await tap(tester, find.byTooltip('Hapus riwayat'));
    expect(find.text('Hapus riwayat?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus riwayat?'), findsNothing);
    expect(history.items, hasLength(1));
    await tap(tester, find.text('Sigatoka'));
    expect(find.text('Detail Riwayat'), findsOneWidget);
  });
}
