import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../history/history_repository.dart';
import 'detection.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({
    super.key,
    required this.result,
    this.fromHistory = false,
  });
  final DetectionResult result;
  final bool fromHistory;
  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _saving = false;
  bool _saved = false;
  String? _error;
  Future<void> _save() async {
    if (_saving || _saved) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(historyRepositoryProvider).save(widget.result);
      if (!mounted) return;
      ref.invalidate(historyProvider);
      setState(() => _saved = true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ServiceFailure
              ? error.message
              : 'Riwayat gagal disimpan. Hasil Anda tetap tersedia di layar ini. Coba simpan kembali.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fromHistory ? 'Detail Riwayat' : 'Hasil Deteksi'),
      ),
      body: PageBody(
        children: [
          LeafPhoto(path: result.imagePath),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.forest900,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hasil identifikasi awal',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  result.predictedClass.label,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayDate(result.createdAt),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            children: [
              Text(
                'Confidence',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                result.confidenceLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Confidence',
            value: result.confidenceLabel,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.forest700),
                borderRadius: BorderRadius.circular(8),
              ),
              child: LinearProgressIndicator(
                value: result.confidence,
                minHeight: 12,
                color: AppColors.leaf500,
                backgroundColor: AppColors.forest900,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Skor keluaran model, bukan tingkat kepastian diagnosis.'),
          const SizedBox(height: 24),
          Text(
            'Tentang kondisi ini',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Informasi terkurasi untuk ${result.predictedClass.label} belum tersedia pada versi ini.',
          ),
          const SizedBox(height: 24),
          Text(
            'Penanganan awal',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Panduan khusus kondisi ini belum tersedia. Konsultasikan kondisi tanaman dengan tenaga ahli pertanian.',
          ),
          const SizedBox(height: 24),
          const Notice(resultDisclaimer),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Notice(_error!, error: true),
          ],
          if (_saving) const LoadingMessage('Menyimpan riwayat...'),
          if (_saved) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Notice('Hasil berhasil disimpan ke riwayat.'),
            ),
          ],
          if (!widget.fromHistory) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || _saved ? null : _save,
              child: Text(_saved ? 'Tersimpan' : 'Simpan Riwayat'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(true),
              child: const Text('Scan Ulang'),
            ),
          ],
        ],
      ),
    );
  }
}
