import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecoplant/app.dart';
import 'package:ecoplant/core/storage/photo_storage.dart';
import 'package:ecoplant/core/theme.dart';
import 'package:ecoplant/features/detection/detection.dart';
import 'package:ecoplant/features/detection/leaf_caption.dart';
import 'package:ecoplant/features/detection/result_screen.dart';
import 'package:ecoplant/features/history/history_repository.dart';
import 'package:ecoplant/features/home/home_screen.dart';
import 'package:ecoplant/features/scan/scan_controller.dart';
import 'package:ecoplant/features/scan/scan_screen.dart';
import 'fixtures.dart';

Future<void> tapTarget(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        finder, 240, scrollable: scrollable.first,
      );
    }
  }
  expect(finder, findsWidgets, reason: 'Widget tidak ditemukan: $finder');
  final target = finder.last;
  if (target.hitTestable().evaluate().isEmpty) {
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pumpAndSettle();
  }
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) =>
    tapTarget(tester, find.text(text));

Finder navigation(String label) => find.widgetWithText(
  NavigationDestination, label,
);

Finder scanLabel(String pattern) => find.descendant(
  of: find.byType(ScanScreen),
  matching: find.textContaining(RegExp(pattern, caseSensitive: false)),
);

Finder get galleryAction => scanLabel(r'^(pilih (foto )?dari )?galeri$');
Finder get analyzeAction => scanLabel(r'^analisis( daun| foto)?$');
Finder get cameraAction => scanLabel(r'^buka kamera$');
Finder get emptyPhoto => scanLabel(
  r'^(belum ada (foto|gambar)( yang)? dipilih|belum ada foto|belum memilih foto|belum ada gambar)\.?$',
);

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
          photoStorageProvider.overrideWithValue(const TestPhotoStorage()),
          galleryServiceProvider.overrideWithValue(TestGallery()),
          captionServiceProvider.overrideWithValue(const TestCaptionService()),
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
    expect(find.byType(HomeScreen), findsOneWidget);
    await tapTarget(tester, navigation('Scan'));
    expect(emptyPhoto, findsOneWidget);
    final enabledAnalysis = find.ancestor(
      of: analyzeAction,
      matching: find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton && widget.onPressed != null,
      ),
    );
    expect(enabledAnalysis, findsNothing);
    await tapTarget(tester, galleryAction);
    expect(emptyPhoto, findsOneWidget);
    await tapTarget(tester, navigation('Riwayat'));
    expect(find.text('Belum ada hasil deteksi'), findsOneWidget);
    await tapText(tester, 'Mulai scan');
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(cameraAction, findsOneWidget);
    await tapTarget(tester, navigation('Beranda'));
    await tapText(tester, 'Lihat semua');
    expect(find.text('Riwayat pemeriksaan.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('history loading, failure, retry then success and detail', (
    tester,
  ) async {
    final pending = Completer<List<DetectionResult>>();
    final repository = TestHistory(pending: pending);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(repository),
          photoStorageProvider.overrideWithValue(const TestPhotoStorage()),
          captionServiceProvider.overrideWithValue(const TestCaptionService()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(navigation('Riwayat'));
    await tester.pump();
    expect(find.text('Memuat riwayat...'), findsOneWidget);
    pending.completeError(
      const ServiceFailure('Riwayat gagal dimuat. Coba lagi.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Riwayat gagal dimuat. Coba lagi.'), findsOneWidget);
    repository.pending = null;
    repository.items = [fixture()];
    await tapText(tester, 'Coba lagi');
    await tapText(tester, 'Sigatoka');
    expect(find.text('Detail Riwayat'), findsOneWidget);
    expect(find.text('Simpan riwayat'), findsNothing);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Riwayat pemeriksaan.'), findsOneWidget);
  });
  testWidgets('history can delete a saved result after confirmation', (
    tester,
  ) async {
    final repository = TestHistory(items: [fixture()]);
    await start(tester, repository: repository);
    await tapTarget(tester, navigation('Riwayat'));
    await tester.tap(find.byTooltip('Hapus riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus riwayat?'), findsOneWidget);
    await tapText(tester, 'Hapus');
    expect(find.text('Belum ada hasil deteksi'), findsOneWidget);
    expect(repository.items, isEmpty);
  });
  testWidgets(
    'save failure preserves result, retry saves once, rescan returns',
    (tester) async {
      final repository = TestHistory(failSave: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historyRepositoryProvider.overrideWithValue(repository),
            photoStorageProvider.overrideWithValue(const TestPhotoStorage()),
            captionServiceProvider.overrideWithValue(
              const TestCaptionService(),
            ),
          ],
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
      await tapText(tester, 'Simpan riwayat');
      expect(repository.saves, 1);
expect(repository.items, isEmpty);

final errorMessage = find.text(
  'Riwayat gagal disimpan. Coba lagi.',
);

await tester.scrollUntilVisible(
  errorMessage,
  200,
  scrollable: find.byType(Scrollable).first,
);

await tester.pumpAndSettle();

expect(errorMessage, findsOneWidget);
expect(find.byType(ResultScreen), findsOneWidget);
expect(find.text('Simpan riwayat'), findsOneWidget);
expect(repository.saves, 1);
expect(find.byType(ResultScreen), findsOneWidget);
expect(find.text('Simpan riwayat'), findsOneWidget);
      repository.failSave = false;
      await tapText(tester, 'Simpan riwayat');
      expect(find.text('Tersimpan'), findsOneWidget);
      expect(repository.saves, 2);
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Tersimpan'),
                matching: find.byWidgetPredicate((widget) => widget is FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tapText(tester, 'Scan ulang');
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
          photoStorageProvider.overrideWithValue(const TestPhotoStorage()),
          galleryServiceProvider.overrideWithValue(gallery),
          imageValidatorProvider.overrideWithValue((_) async {}),
          detectionServiceProvider.overrideWithValue(TestDetection(pending)),
          captionServiceProvider.overrideWithValue(const TestCaptionService()),
        ],
        child: MaterialApp(
          theme: appTheme(),
          home: const AppShell(),
        ) 
      ),
    );
    await tester.pumpAndSettle();
    await tapTarget(tester, navigation('Scan'));
    await tapTarget(tester, galleryAction);
    expect(analyzeAction, findsOneWidget);
    await tester.ensureVisible(analyzeAction);
    await tester.tap(analyzeAction);
    await tester.pump();
    expect(find.text('Menganalisis daun...'), findsOneWidget);
    pending.complete(fixture());
    await tester.pumpAndSettle();
    expect(find.text('Hasil Deteksi'), findsOneWidget);
    await tapText(tester, 'Scan ulang');
    expect(emptyPhoto, findsOneWidget);
  });
  testWidgets('photo that is not a banana leaf shows zero percent', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(TestHistory()),
          photoStorageProvider.overrideWithValue(const TestPhotoStorage()),
          captionServiceProvider.overrideWithValue(
            const TestCaptionService(
              caption: LeafCaption(
                summary: 'Foto ini memperlihatkan meja dan tangan.',
                treatment: 'Tidak ada penanganan daun yang bisa disarankan.',
                photoTip:
                    'Arahkan kamera ke satu daun pisang yang memenuhi layar.',
                imageMatches: false,
                subject: CaptionSubject.notLeaf,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: appTheme(),
          home: ResultScreen(result: fixture()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bukan daun pisang'), findsOneWidget);
    expect(find.text('0.0%'), findsOneWidget);
    expect(find.text('Sigatoka'), findsNothing);
    expect(find.text('Tentang kondisi ini'), findsNothing);
    expect(find.text('Simpan riwayat'), findsNothing);
    expect(find.text('Scan ulang').hitTestable(), findsOneWidget);
  });
  for (final width in [320.0, 390.0, 480.0]) {
    testWidgets('layout at width $width and 200 percent text', (tester) async {
      await start(tester, width: width, scale: 2);
      await tapTarget(tester, navigation('Scan'));
      expect(tester.takeException(), isNull);
      await tapTarget(tester, navigation('Riwayat'));
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Mulai scan');
      expect(find.byType(ScanScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('keyboard can activate primary action', (tester) async {
    await start(tester);
    final destination = navigation('Scan');
    expect(destination, findsOneWidget);
    final destinationElement = tester.element(destination);
    bool scanFocused() {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return false;
      if (context == destinationElement) return true;
      var found = false;
      context.visitAncestorElements((element) {
        if (element == destinationElement) {
          found = true;
          return false;
        }
        return true;
      });
      return found;
    }

    for (var i = 0; i < 40 && !scanFocused(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(scanFocused(), isTrue, reason: 'Tab Scan harus bisa difokuskan.');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(cameraAction, findsOneWidget);
  });
  testWidgets('capture home for visual review', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(
            TestHistory(items: [fixture()]),
          ),
          photoStorageProvider.overrideWithValue(const TestPhotoStorage()),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(theme: appTheme(), home: const AppShell()),
        ),
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
