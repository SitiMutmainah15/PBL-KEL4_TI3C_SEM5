import 'package:cloud_firestore/cloud_firestore.dart';
import '../detection/detection.dart';
import 'history_repository.dart';

class FirebaseHistoryRepository implements HistoryRepository {
  FirebaseHistoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Nama koleksi (setara dengan nama tabel)
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('detections');

  @override
  Future<void> save(DetectionResult result) async {
    try {
      await _collection.doc(result.id).set({
        'id': result.id,
        'image_path': result.imagePath,
        'predicted_class': result.predictedClass.name,
        'confidence': result.confidence,
        'model_version': result.modelVersion,
        'created_at': Timestamp.fromDate(result.createdAt),
      });
    } catch (e) {
      throw ServiceFailure('Gagal menyimpan riwayat ke cloud: $e');
    }
  }

  @override
  Future<List<DetectionResult>> load() async {
    try {
      final snapshot = await _collection
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();

        // Parsing nama kelas kembali ke enum LeafClass
        final leafClass = LeafClass.values.firstWhere(
          (c) =>
              c.name.toLowerCase() ==
              (data['predicted_class'] as String? ?? '').toLowerCase(),
          orElse: () => LeafClass.healthy,
        );

        final timestamp = data['created_at'] as Timestamp?;
        final createdAt = timestamp != null
            ? timestamp.toDate()
            : DateTime.now();

        return DetectionResult(
          id: doc.id,
          imagePath: data['image_path'] as String? ?? '',
          predictedClass: leafClass,
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
          createdAt: createdAt,
          modelVersion: data['model_version'] as String? ?? '1.0.0',
        );
      }).toList();
    } catch (e) {
      throw ServiceFailure('Gagal memuat riwayat: $e');
    }
  }
}
