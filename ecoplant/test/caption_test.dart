import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecoplant/core/theme.dart';
import 'package:ecoplant/features/detection/caption_section.dart';
import 'package:ecoplant/features/detection/detection.dart';
import 'package:ecoplant/features/detection/leaf_caption.dart';
import 'package:ecoplant/features/detection/reference_photos.dart';
import 'fixtures.dart';

class TestCaption implements CaptionService {
  TestCaption({this.caption, this.error, this.pending});

  LeafCaption? caption;
  ServiceFailure? error;
  Completer<LeafCaption>? pending;
  int calls = 0;
  String? lastLocale;

  @override
  Future<LeafCaption> describe({
    required DetectionResult result,
    required String locale,
  }) {
    calls++;
    lastLocale = locale;
    if (pending != null) return pending!.future;
    if (error != null) return Future.error(error!);
    return Future.value(caption);
  }
}

const sampleCaption = LeafCaption(
  summary: 'Daun tampak sehat tanpa bercak yang dikenali model.',
  treatment: 'Lanjutkan pemantauan rutin dan jaga kebersihan area tanam.',
  photoTip: 'Foto ulang dengan cahaya dari samping agar tulang daun terlihat.',
  imageMatches: true,
);

Widget host(TestCaption service, {DetectionResult? result}) => ProviderScope(
  overrides: [captionServiceProvider.overrideWithValue(service)],
  child: MaterialApp(
    theme: appTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: CaptionSection(result: result ?? fixture()),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('caption loading then shows text, photos and tip', (
    tester,
  ) async {
    final pending = Completer<LeafCaption>();
    final service = TestCaption(pending: pending);
    await tester.pumpWidget(host(service));
    expect(find.text('Menyusun keterangan kondisi daun...'), findsOneWidget);

    pending.complete(sampleCaption);
    await tester.pumpAndSettle();

    expect(find.text('Tentang kondisi ini'), findsOneWidget);
    expect(find.text(sampleCaption.summary), findsOneWidget);
    expect(find.text('Penanganan awal'), findsOneWidget);
    expect(find.text(sampleCaption.treatment), findsOneWidget);
    expect(find.text('Foto pembanding'), findsOneWidget);
    expect(find.byType(ReferencePhotoStrip), findsOneWidget);
    expect(find.text('Saran foto berikutnya'), findsOneWidget);
    expect(find.text(sampleCaption.photoTip), findsOneWidget);
    expect(service.lastLocale, 'id');
  });

  testWidgets('failure shows message, retry refetches', (tester) async {
    final service = TestCaption(
      error: const ServiceFailure('Layanan caption tidak dapat dihubungi.'),
    );
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();

    expect(find.text('Layanan caption tidak dapat dihubungi.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(find.text('Tentang kondisi ini'), findsNothing);

    service
      ..error = null
      ..caption = sampleCaption;
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text(sampleCaption.summary), findsOneWidget);
    expect(service.calls, 2);
  });

  testWidgets('baseline text only appears when requested', (tester) async {
    final service = TestCaption(error: const ServiceFailure('Gagal.'));
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();

    expect(find.text('Tampilkan keterangan umum'), findsOneWidget);
    expect(find.text('Penanganan awal'), findsNothing);

    await tester.tap(find.text('Tampilkan keterangan umum'));
    await tester.pumpAndSettle();

    expect(find.text('Tentang kondisi ini'), findsOneWidget);
    expect(find.text('Penanganan awal'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });

  testWidgets('unreadable photo changes the tip heading', (tester) async {
    final service = TestCaption(
      caption: const LeafCaption(
        summary: 'A.',
        treatment: 'B.',
        photoTip: 'C.',
        imageMatches: false,
      ),
    );
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();

    expect(find.text('Foto ini sulit dibaca'), findsOneWidget);
    expect(find.text('Saran foto berikutnya'), findsNothing);
  });

  testWidgets('same result reuses one request', (tester) async {
    final service = TestCaption(caption: sampleCaption);
    final result = fixture();
    final container = ProviderContainer(
      overrides: [captionServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final cache = container.read(captionCacheProvider);

    await cache.load(result, service);
    await cache.load(result, service);
    expect(service.calls, 1);

    cache.invalidate(result);
    await cache.load(result, service);
    expect(service.calls, 2);
  });

  test('every class has three reference photos', () {
    for (final leafClass in LeafClass.values) {
      expect(referencePhotos[leafClass], hasLength(3));
    }
  });

  test('reference photos are bundled and decodable', () async {
    for (final paths in referencePhotos.values) {
      for (final path in paths) {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(1000), reason: path);
        expect(await decodeImageFromList(data.buffer.asUint8List()), isNotNull);
      }
    }
  });

  test('caption json requires all three texts', () {
    expect(
      LeafCaption.fromJson({
        'ringkasan': 'A',
        'penanganan': 'B',
        'saranFoto': 'C',
        'gambarSesuai': true,
      })?.photoTip,
      'C',
    );
    expect(LeafCaption.fromJson({'ringkasan': 'A'}), isNull);
    expect(
      LeafCaption.fromJson({
        'ringkasan': '  ',
        'penanganan': 'B',
        'saranFoto': 'C',
      }),
      isNull,
    );
    expect(LeafCaption.fromJson('not a map'), isNull);
  });

  testWidgets('label disagreement is disclosed, image label wins', (
    tester,
  ) async {
    final service = TestCaption(
      caption: const LeafCaption(
        summary: 'A.',
        treatment: 'B.',
        photoTip: 'C.',
        imageMatches: true,
        detectedLabel: 'cordana',
      ),
    );
    await tester.pumpWidget(host(service, result: fixture()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Model bahasa menyebut Cordana'),
      findsOneWidget,
    );
    expect(
      find.textContaining('model gambar menyebut Sigatoka'),
      findsOneWidget,
    );
    expect(find.byType(ReferencePhotoStrip), findsOneWidget);
  });
}
