import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ecoplant/core/storage/photo_storage.dart';

void main() {
  test(
    'original photos are copied to app documents and temporary copies cleaned',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ecoplant_photos_',
      );
      final documents = Directory(p.join(directory.path, 'documents'));
      final temporary = Directory(p.join(directory.path, 'temporary'));
      await documents.create();
      await temporary.create();
      final storage = DevicePhotoStorage(
        documentsDirectory: () async => documents,
      );
      addTearDown(() => directory.delete(recursive: true));

      final retainedSource = File(p.join(temporary.path, 'retained.png'));
      await retainedSource.writeAsBytes([1, 2, 3]);
      final retainedPath = await storage.saveOriginal(retainedSource.path);
      expect(
        p.isWithin(p.join(documents.path, 'ecoplant', 'photos'), retainedPath),
        isTrue,
      );
      expect(await File(retainedPath).readAsBytes(), [1, 2, 3]);
      expect(await retainedSource.exists(), isTrue);

      final disposableSource = File(p.join(temporary.path, 'disposable.png'));
      await disposableSource.writeAsBytes([4, 5, 6]);
      final disposablePath = await storage.saveOriginal(
        disposableSource.path,
        deleteTemporarySource: true,
      );
      expect(await File(disposablePath).readAsBytes(), [4, 5, 6]);
      expect(await disposableSource.exists(), isFalse);
    },
  );
}
