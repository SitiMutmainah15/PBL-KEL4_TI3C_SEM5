import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecoplant/features/detection/detection.dart';
import 'package:ecoplant/features/history/history_repository.dart';
import 'package:ecoplant/features/scan/scan_controller.dart';
import 'fixtures.dart';

void main() {
  test(
    'production stubs never fabricate results or successful persistence',
    () async {
      await expectLater(
        const UnavailableDetectionService().analyze('leaf.png'),
        throwsA(isA<ServiceFailure>()),
      );
      await expectLater(
        const UnavailableHistoryRepository().load(),
        throwsA(isA<ServiceFailure>()),
      );
      await expectLater(
        const UnavailableHistoryRepository().save(fixture()),
        throwsA(isA<ServiceFailure>()),
      );
    },
  );
  test('confidence rejects invalid scores', () {
    for (final score in [-.1, 1.1, double.nan, double.infinity]) {
      expect(
        () => DetectionResult(
          id: 'test',
          imagePath: 'test',
          predictedClass: LeafClass.healthy,
          confidence: score,
          createdAt: DateTime(2026),
          modelVersion: 'test',
        ),
        throwsArgumentError,
      );
    }
  });
  test(
    'cancel gallery preserves preview; failures keep previous photo',
    () async {
      final gallery = TestGallery();
      final container = ProviderContainer(
        overrides: [
          galleryServiceProvider.overrideWithValue(gallery),
          imageValidatorProvider.overrideWithValue((_) async {}),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(scanProvider.notifier);
      await controller.select('original.png');
      await controller.pick();
      expect(container.read(scanProvider).imagePath, 'original.png');
      gallery.fail = true;
      await controller.pick();
      expect(container.read(scanProvider).imagePath, 'original.png');
      expect(container.read(scanProvider).error, contains('Galeri'));
    },
  );
  test('corrupt image rejected before replacing valid preview', () async {
    final container = ProviderContainer(
      overrides: [
        imageValidatorProvider.overrideWithValue((path) async {
          if (path == 'bad') throw const ServiceFailure('Foto gagal dibaca.');
        }),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(scanProvider.notifier);
    await controller.select('good');
    await controller.select('bad');
    expect(container.read(scanProvider).imagePath, 'good');
    expect(container.read(scanProvider).error, 'Foto gagal dibaca.');
  });
  test(
    'analysis requires photo, blocks duplicates, and keeps photo after failure',
    () async {
      final pending = Completer<DetectionResult>();
      final service = TestDetection(pending);
      final container = ProviderContainer(
        overrides: [
          detectionServiceProvider.overrideWithValue(service),
          imageValidatorProvider.overrideWithValue((_) async {}),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(scanProvider.notifier);
      expect(await controller.analyze(), isNull);
      await controller.select('leaf');
      final analysis = controller.analyze();
      expect(container.read(scanProvider).analyzing, isTrue);
      expect(await controller.analyze(), isNull);
      controller.clear();
      expect(container.read(scanProvider).imagePath, 'leaf');
      expect(service.calls, 1);
      pending.completeError(const ServiceFailure('Analisis gagal.'));
      expect(await analysis, isNull);
      expect(container.read(scanProvider).busy, isFalse);
      expect(container.read(scanProvider).imagePath, 'leaf');
      expect(container.read(scanProvider).error, 'Analisis gagal.');
    },
  );
  test('history sorts newest first without mutating repository data', () async {
    final old = fixture(id: 'old', date: DateTime(2026, 1));
    final recent = fixture(id: 'new', date: DateTime(2026, 9));
    final repository = TestHistory(items: [old, recent]);
    final container = ProviderContainer(
      overrides: [historyRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    expect((await container.read(historyProvider.future)).first.id, 'new');
    expect(repository.items.first.id, 'old');
  });
}
