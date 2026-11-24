import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/storage/photo_storage.dart';
import '../detection/detection.dart';
import 'history_contract.dart';

class LocalHistoryRepository implements HistoryRepository {
  LocalHistoryRepository({
    sqflite.DatabaseFactory? databaseFactory,
    String? databasePath,
    PhotoStorage? photoStorage,
  }) : _databaseFactory = databaseFactory,
       _databasePath = databasePath,
       _photoStorage = photoStorage ?? DevicePhotoStorage();

  final sqflite.DatabaseFactory? _databaseFactory;
  final String? _databasePath;
  final PhotoStorage _photoStorage;
  Future<sqflite.Database>? _database;

  static bool _ffiInitialized = false;

  Future<sqflite.Database> get _db => _database ??= _openDatabase();

  Future<sqflite.Database> _openDatabase() async {
    var factory = _databaseFactory;
    if (factory == null) {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
        if (!_ffiInitialized) {
          sqfliteFfiInit();
          sqflite.databaseFactory = databaseFactoryFfi;
          _ffiInitialized = true;
        }
      }
      factory = sqflite.databaseFactory;
    }

    final path = _databasePath ?? await _defaultDatabasePath();
    return factory.openDatabase(
      path,
      options: sqflite.OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE detections (
              id TEXT PRIMARY KEY,
              image_path TEXT NOT NULL,
              predicted_class TEXT NOT NULL,
              confidence REAL NOT NULL,
              model_version TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX detections_created_at ON detections(created_at DESC)',
          );
        },
      ),
    );
  }

  Future<String> _defaultDatabasePath() async {
    final directory = await getApplicationSupportDirectory();
    final appDirectory = Directory(p.join(directory.path, 'ecoplant'));
    await appDirectory.create(recursive: true);
    return p.join(appDirectory.path, 'history.db');
  }

  Map<String, Object?> _toRow(DetectionResult result) => {
    'id': result.id,
    'image_path': result.imagePath,
    'predicted_class': result.predictedClass.name,
    'confidence': result.confidence,
    'model_version': result.modelVersion,
    'created_at': result.createdAt.toUtc().toIso8601String(),
  };

  DetectionResult _fromRow(Map<String, Object?> row) {
    final className = row['predicted_class'] as String;
    final leafClass = LeafClass.values.where((value) {
      return value.name == className;
    }).firstOrNull;
    if (leafClass == null) {
      throw FormatException('Kelas daun tidak dikenal: $className');
    }

    return DetectionResult(
      id: row['id'] as String,
      imagePath: row['image_path'] as String,
      predictedClass: leafClass,
      confidence: (row['confidence'] as num).toDouble(),
      modelVersion: row['model_version'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  Future<void> save(DetectionResult result) async {
    try {
      await (await _db).insert(
        'detections',
        _toRow(result),
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    } catch (error) {
      throw ServiceFailure('Gagal menyimpan riwayat secara lokal: $error');
    }
  }

  @override
  Future<List<DetectionResult>> load() async {
    try {
      final rows = await (await _db).query(
        'detections',
        orderBy: 'created_at DESC',
      );
      return rows.map(_fromRow).toList(growable: false);
    } catch (error) {
      throw ServiceFailure('Gagal memuat riwayat lokal: $error');
    }
  }

  @override
  Future<void> update(DetectionResult result) async {
    try {
      final changed = await (await _db).update(
        'detections',
        _toRow(result),
        where: 'id = ?',
        whereArgs: [result.id],
      );
      if (changed == 0) {
        throw const ServiceFailure(
          'Riwayat yang akan diperbarui tidak ditemukan.',
        );
      }
    } on ServiceFailure {
      rethrow;
    } catch (error) {
      throw ServiceFailure('Gagal memperbarui riwayat lokal: $error');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final database = await _db;
      final rows = await database.query(
        'detections',
        columns: ['image_path'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const ServiceFailure(
          'Riwayat yang akan dihapus tidak ditemukan.',
        );
      }

      await database.delete('detections', where: 'id = ?', whereArgs: [id]);
      await _photoStorage.delete(rows.single['image_path'] as String);
    } on ServiceFailure {
      rethrow;
    } catch (error) {
      throw ServiceFailure('Gagal menghapus riwayat lokal: $error');
    }
  }

  Future<void> close() async {
    final database = await _database;
    if (database != null) await database.close();
    _database = null;
  }
}
