import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ecoplant/core/storage/photo_storage.dart';
import 'package:ecoplant/features/detection/detection.dart';
import 'package:ecoplant/features/history/local_history_repository.dart';

class RecordingPhotoStorage implements PhotoStorage {
  final deletedPaths = <String>[];

  @override
  Future<String> saveOriginal(
    String sourcePath, {
    bool deleteTemporarySource = false,
  }) async => sourcePath;

  @override
  Future<File> thumbnail(String imagePath) async => File(imagePath);

  @override
  Future<void> delete(String imagePath) async {
    deletedPaths.add(imagePath);
  }
}

DetectionResult result({
  String id = 'scan-1',
  String imagePath = 'C:/ecoplant/photos/leaf.jpg',
  LeafClass predictedClass = LeafClass.sigatoka,
  DateTime? createdAt,
}) => DetectionResult(
  id: id,
  imagePath: imagePath,
  predictedClass: predictedClass,
  confidence: .87,
  createdAt: createdAt ?? DateTime(2026, 9, 24, 10, 30),
  modelVersion: '1.0.0',
);

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'SQLite repository creates, reads, updates and deletes persisted rows',
    () async {
      final directory = await Directory.systemTemp.createTemp('ecoplant_test_');
      final databasePath = p.join(directory.path, 'history.db');
      final photos = RecordingPhotoStorage();
      LocalHistoryRepository createRepository() => LocalHistoryRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: databasePath,
        photoStorage: photos,
      );

      addTearDown(() async {
        await directory.delete(recursive: true);
      });

      final repository = createRepository();
      final original = result();
      await repository.save(original);
      final saved = await repository.load();
      expect(saved, hasLength(1));
      expect(saved.single.id, original.id);
      expect(saved.single.imagePath, original.imagePath);
      expect(saved.single.predictedClass, original.predictedClass);
      await repository.close();

      final reopenedRepository = createRepository();
      final updated = result(
        imagePath: 'C:/ecoplant/photos/updated.jpg',
        predictedClass: LeafClass.healthy,
        createdAt: DateTime(2026, 10, 1, 12),
      );
      await reopenedRepository.update(updated);
      final loaded = await reopenedRepository.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.imagePath, updated.imagePath);
      expect(loaded.single.predictedClass, updated.predictedClass);
      expect(loaded.single.createdAt, updated.createdAt.toUtc());

      await reopenedRepository.delete(updated.id);
      expect(await reopenedRepository.load(), isEmpty);
      expect(photos.deletedPaths, [updated.imagePath]);
      await reopenedRepository.close();
    },
  );

  test('update and delete report missing records', () async {
    final repository = LocalHistoryRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      photoStorage: RecordingPhotoStorage(),
    );
    addTearDown(repository.close);

    await expectLater(
      repository.update(result()),
      throwsA(isA<ServiceFailure>()),
    );
    await expectLater(
      repository.delete('missing'),
      throwsA(isA<ServiceFailure>()),
    );
  });
}
