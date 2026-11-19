import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class PhotoStorage {
  Future<String> saveOriginal(
    String sourcePath, {
    bool deleteTemporarySource = false,
  });
  Future<File> thumbnail(String imagePath);
  Future<void> delete(String imagePath);
}

final photoStorageProvider = Provider<PhotoStorage>(
  (ref) => DevicePhotoStorage(),
);

class DevicePhotoStorage implements PhotoStorage {
  DevicePhotoStorage({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  static final CacheManager _cache = CacheManager(
    Config(
      'ecoplantThumbnails',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 200,
    ),
  );

  @override
  Future<String> saveOriginal(
    String sourcePath, {
    bool deleteTemporarySource = false,
  }) async {
    final source = File(sourcePath);
    final documents = await _documentsDirectory();
    final photoDirectory = Directory(
      p.join(documents.path, 'ecoplant', 'photos'),
    );
    await photoDirectory.create(recursive: true);

    final extension = p.extension(sourcePath).toLowerCase();
    final safeExtension =
        const {'.jpg', '.jpeg', '.png', '.webp', '.heic'}.contains(extension)
        ? extension
        : '.jpg';
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    var targetPath = p.join(photoDirectory.path, '$timestamp$safeExtension');
    var suffix = 0;
    while (await File(targetPath).exists()) {
      suffix++;
      targetPath = p.join(
        photoDirectory.path,
        '${timestamp}_$suffix$safeExtension',
      );
    }

    final temporaryPath = '$targetPath.part';
    try {
      await source.copy(temporaryPath);
      final saved = await File(temporaryPath).rename(targetPath);
      if (deleteTemporarySource &&
          p.normalize(source.absolute.path) !=
              p.normalize(saved.absolute.path)) {
        await source.delete();
      }
    } catch (_) {
      final temporary = File(temporaryPath);
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }

    return targetPath;
  }

  @override
  Future<File> thumbnail(String imagePath) async {
    final cached = await _cache.getFileFromCache(imagePath);
    if (cached != null) return cached.file;

    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException(
        'Foto tidak dapat diproses menjadi thumbnail.',
      );
    }

    final resized = img.copyResize(
      decoded,
      width: 320,
      interpolation: img.Interpolation.average,
    );
    return _cache.putFile(
      imagePath,
      img.encodeJpg(resized, quality: 78),
      fileExtension: 'jpg',
    );
  }

  @override
  Future<void> delete(String imagePath) async {
    await _cache.removeFile(imagePath);
    final file = File(imagePath);
    if (await file.exists()) await file.delete();
  }
}
