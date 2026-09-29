import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../history/history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onScan, required this.onHistory});
  final VoidCallback onScan;
  final VoidCallback onHistory;
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const Text('Selamat datang'),
      const SizedBox(height: 8),
      Text(
        'Kenali kondisi\ndaun pisang Anda.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cream100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Icon(Icons.eco_outlined, size: 48, color: AppColors.forest900),
            SizedBox(height: 12),
            Text(
              'Foto tanaman pisang belum tersedia.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Area foto referensi',
              style: TextStyle(fontSize: 12, color: AppColors.ink600),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Cek kondisi daun pisang',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Ambil satu foto daun atau pilih dari galeri untuk memulai identifikasi awal.',
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: onScan,
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Scan Daun'),
      ),
      const SizedBox(height: 16),
      const Notice(
        'Versi pengembangan: analisis dan penyimpanan riwayat belum tersedia.',
      ),
      const SizedBox(height: 32),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        children: [
          Text(
            'Deteksi terakhir',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextButton(onPressed: onHistory, child: const Text('Lihat semua')),
        ],
      ),
      const SizedBox(height: 12),
      HistoryContent(onScan: onScan, limit: 3),
    ],
  );
}
