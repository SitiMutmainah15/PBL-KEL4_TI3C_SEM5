import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecoplant/app.dart';
import 'package:ecoplant/core/theme.dart';
import 'package:ecoplant/features/detection/detection.dart';
import 'package:ecoplant/features/detection/result_screen.dart';
import 'package:ecoplant/features/history/history_repository.dart';
import 'package:ecoplant/features/scan/scan_controller.dart';
import 'package:ecoplant/features/scan/scan_screen.dart';
import 'fixtures.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      240,
      scrollable: find.byType(Scrollable).first,
    );
  }
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    final fonts =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    for (final font in [
      ('Roboto', 'roboto-regular.ttf'),
      ('MaterialIcons', 'materialicons-regular.otf'),
    ]) {
      final loader = FontLoader(font.$1)
        ..addFont(
          File(
            '$fonts/${font.$2}',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  Future<void> start(
    WidgetTester tester, {
    TestHistory? repository,
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(
            repository ?? TestHistory(),
          ),
          galleryServiceProvider.overrideWithValue(TestGallery()),
        ],
        child: MaterialApp(
          theme: appTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home, navigation, empty history and gallery cancellation', (
    tester,
  ) async {
    await start(tester);
    expect(find.text('Kenali kondisi\ndaun pisang Anda.'), findsOneWidget);
    await tapText(tester, 'Scan Daun');
    expect(find.text('Belum ada foto dipilih.'), findsOneWidget);
    expect(find.text('Analisis'), findsNothing);
    await tapText(tester, 'Pilih dari Galeri');
    expect(find.text('Belum ada foto dipilih.'), findsOneWidget);
    await tapText(tester, 'Riwayat');
    expect(find.text('Belum ada hasil deteksi.'), findsOneWidget);
    await tapText(tester, 'Scan daun pertama');
    expect(find.text('Buka Kamera'), findsOneWidget);
    await tapText(tester, 'Beranda');
    await tapText(tester, 'Lihat semua');
    expect(find.text('Pemeriksaan daun Anda'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('history loading, failure, retry then success and detail', (
    tester,
  ) async {
    final pending = Completer<List<DetectionResult>>();
    final repository = TestHistory(pending: pending);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [historyRepositoryProvider.overrideWithValue(repository)],
        child: const EcoPlantApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Riwayat').last);
    await tester.pump();
    expect(find.text('Memuat riwayat...'), findsOneWidget);
    pending.completeError(
      const ServiceFailure('Riwayat gagal dimuat. Coba lagi.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Riwayat gagal dimuat. Coba lagi.'), findsOneWidget);
    repository.pending = null;
    repository.items = [fixture()];
    await tapText(tester, 'Coba Lagi');
    await tapText(tester, 'Sigatoka');
    expect(find.text('Detail Riwayat'), findsOneWidget);
    expect(find.text('Simpan Riwayat'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Pemeriksaan daun Anda'), findsOneWidget);
  });
  testWidgets(
    'save failure preserves result, retry saves once, rescan returns',
    (tester) async {
      final repository = TestHistory(failSave: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [historyRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: appTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ResultScreen(result: fixture()),
                    ),
                  ),
                  child: const Text('Open test result'),
                ),
              ),
            ),
          ),
        ),
      );
      await tapText(tester, 'Open test result');
      await tapText(tester, 'Simpan Riwayat');
      expect(find.text('Riwayat gagal disimpan. Coba lagi.'), findsOneWidget);
      repository.failSave = false;
      await tapText(tester, 'Simpan Riwayat');
      expect(find.text('Tersimpan'), findsOneWidget);
      expect(repository.saves, 2);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Tersimpan'),
            )
            .onPressed,
        isNull,
      );
      await tapText(tester, 'Scan Ulang');
      expect(find.text('Open test result'), findsOneWidget);
    },
  );
  testWidgets('scan loading, test result, and rescan clears photo', (
    tester,
  ) async {
    final pending = Completer<DetectionResult>();
    final gallery = TestGallery()..path = 'test-photo.png';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(TestHistory()),
          galleryServiceProvider.overrideWithValue(gallery),
          imageValidatorProvider.overrideWithValue((_) async {}),
          detectionServiceProvider.overrideWithValue(TestDetection(pending)),
        ],
        child: const EcoPlantApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'Scan Daun');
    await tapText(tester, 'Pilih dari Galeri');
    await tester.ensureVisible(find.text('Analisis'));
    await tester.tap(find.text('Analisis'));
    await tester.pump();
    expect(find.text('Menganalisis daun...'), findsOneWidget);
    pending.complete(fixture());
    await tester.pumpAndSettle();
    expect(find.text('Hasil Deteksi'), findsOneWidget);
    await tapText(tester, 'Scan Ulang');
    expect(find.text('Belum ada foto dipilih.'), findsOneWidget);
  });
  for (final width in [320.0, 390.0, 480.0]) {
    testWidgets('layout at width $width and 200 percent text', (tester) async {
      await start(tester, width: width, scale: 2);
      await tapText(tester, 'Scan Daun');
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Riwayat');
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Scan daun pertama');
      expect(find.byType(ScanScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('keyboard can activate primary action', (tester) async {
    await start(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Buka Kamera'), findsOneWidget);
  });
  testWidgets('capture home for visual review', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(key: key, child: const EcoPlantApp()),
      ),
    );
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/review').create(recursive: true);
      await File(
        'build/review/home.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}
