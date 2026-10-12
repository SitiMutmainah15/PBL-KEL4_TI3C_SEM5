import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../history/history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onScan, required this.onHistory});
  final VoidCallback onScan;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF5FAF0),
    child: PageBody(
      children: [
        const Text(
          'Selamat datang 👋',
          style: TextStyle(fontSize: 13, color: AppColors.ink600),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Expanded(
              child: Text(
                'Cek kesehatan\ndaun pisang\ndengan mudah.',
                style: TextStyle(
                  fontSize: 23,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest900,
                ),
              ),
            ),
            CircleAvatar(
              radius: 23,
              backgroundColor: Color(0xFFE5EDDF),
              child: Icon(
                Icons.agriculture_outlined,
                color: AppColors.forest700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/banana_leaf.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  excludeFromSemantics: true,
                ),
              ),
              Container(
                width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xDD192C16)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xDDE5EFDA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco_outlined,
                            size: 14,
                            color: AppColors.forest700,
                          ),
                          SizedBox(width: 5),
                          Text(
                            '4 Kondisi Terdeteksi',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.forest900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Kenali kondisi daun lebih awal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Gunakan foto daun pisang untuk mendapatkan identifikasi awal.',
                      style: TextStyle(
                        color: Color(0xFFE5EBDD),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cek kondisi daun pisang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Ambil foto atau pilih gambar daun untuk mulai melakukan identifikasi.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.ink600,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.camera_alt_outlined, size: 19),
                label: const Text('Scan Daun'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F3DA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.light_mode_outlined,
                size: 26,
                color: AppColors.forest700,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pencahayaan Lapangan Optimal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forest700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ambil foto daun pisang sebaiknya saat sinar matahari pagi.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: AppColors.ink600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Deteksi Terbaru',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest700,
                ),
              ),
            ),
            TextButton(
              onPressed: onHistory,
              child: const Text('Lihat semua', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        HistoryContent(onScan: onScan, limit: 3, compact: true),
      ],
    ),
  );
}
