import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../history/history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onScan,
    required this.onHistory,
  });

  final VoidCallback onScan;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) => PageBody(
        children: [
          // Greeting
          const Text(
            'Selamat datang di EcoPlant AI',
            style: TextStyle(
              color: AppColors.ink600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          // Hero title
          Text(
            'Kenali kondisi\ndaun pisang Anda.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),

          const Text(
            'Identifikasi kondisi daun pisang dengan bantuan teknologi AI secara cepat dan praktis.',
            style: TextStyle(
              color: AppColors.ink600,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // Hero card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cream100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco_outlined,
                    size: 40,
                    color: AppColors.forest900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cek kesehatan daun pisang',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ambil foto daun yang ingin diperiksa atau pilih foto yang sudah tersedia di galeri.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Scan CTA
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Mulai Scan Daun'),
            ),
          ),

          const SizedBox(height: 16),

          // Information
          const Notice(
            'Gunakan foto satu daun pisang yang terlihat jelas dan memiliki pencahayaan yang cukup untuk membantu proses identifikasi.',
          ),

          const SizedBox(height: 32),

          // History title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Deteksi terakhir',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: onHistory,
                child: const Text('Lihat semua'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Existing history component
          HistoryContent(
            onScan: onScan,
            limit: 3,
          ),
        ],
      );
}