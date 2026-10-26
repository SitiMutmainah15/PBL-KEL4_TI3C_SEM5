import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'detection.dart';

/// Tiga foto contoh per kelas dari split uji dataset latih.
const Map<LeafClass, List<String>> referencePhotos = {
  LeafClass.healthy: [
    'assets/references/healthy/01.jpg',
    'assets/references/healthy/02.jpg',
    'assets/references/healthy/03.jpg',
  ],
  LeafClass.sigatoka: [
    'assets/references/sigatoka/01.jpg',
    'assets/references/sigatoka/02.jpg',
    'assets/references/sigatoka/03.jpg',
  ],
  LeafClass.cordana: [
    'assets/references/cordana/01.jpg',
    'assets/references/cordana/02.jpg',
    'assets/references/cordana/03.jpg',
  ],
  LeafClass.pestalotiopsis: [
    'assets/references/pestalotiopsis/01.jpg',
    'assets/references/pestalotiopsis/02.jpg',
    'assets/references/pestalotiopsis/03.jpg',
  ],
};

class ReferencePhotoStrip extends StatelessWidget {
  const ReferencePhotoStrip({super.key, required this.leafClass});

  final LeafClass leafClass;

  @override
  Widget build(BuildContext context) {
    final paths = referencePhotos[leafClass] ?? const <String>[];
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => Semantics(
          label: 'Foto pembanding ${index + 1} untuk kelas ${leafClass.label}',
          image: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              paths[index],
              width: 108,
              height: 108,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 108,
                height: 108,
                color: AppColors.cream100,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8),
                child: const Text(
                  'Foto pembanding tidak tersedia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
