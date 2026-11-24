import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../history/history_repository.dart';
import 'caption_section.dart';
import 'detection.dart';
import 'leaf_caption.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({
    super.key,
    required this.result,
    this.fromHistory = false,
  });

  final DetectionResult result;
  final bool fromHistory;

  @override
  ConsumerState<ResultScreen> createState() =>
      _ResultScreenState();
}

class _ResultScreenState
    extends ConsumerState<ResultScreen> {
  // =========================================
  // COLOR PALETTE ECOPLANT
  // =========================================

  static const Color _background = Color(0xFFF7F8F3);
  static const Color _primary = Color(0xFF164D2C);
  static const Color _secondary = Color(0xFF4C8826);
  static const Color _muted = Color(0xFF637367);
  static const Color _softGreen = Color(0xFFE7EDDF);
  static const Color _border = Color(0xFFDDE4D7);
  static const Color _warning = Color(0xFF95612F);

  bool _saving = false;
  bool _saved = false;
  String? _error;
  late Future<LeafCaption> _caption = _load();

  Future<LeafCaption> _load() {
    final service = ref.read(captionServiceProvider);
    final cache = ref.read(captionCacheProvider);
    return Future<LeafCaption>(() => cache.load(widget.result, service));
  }

  void _retryCaption() {
    ref.read(captionCacheProvider).invalidate(widget.result);
    setState(() => _caption = _load());
  }

  // =========================================
  // FUNGSI SIMPAN RIWAYAT ASLI
  // Tidak mengubah logika penyimpanan.
  // =========================================

  Future<void> _save() async {
    if (_saving || _saved) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(historyRepositoryProvider)
          .save(widget.result);

      if (!mounted) return;

      ref.invalidate(historyProvider);

      setState(() => _saved = true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ServiceFailure
              ? error.message
              : 'Riwayat gagal disimpan. '
                'Hasil Anda tetap tersedia di layar ini. '
                'Coba simpan kembali.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // =========================================
  // MAIN UI
  // =========================================

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return FutureBuilder<LeafCaption>(
      future: _caption,
      builder: (context, snapshot) {
        final caption = snapshot.data;
        final notLeaf = caption?.subject == CaptionSubject.notLeaf;
        final checking = snapshot.connectionState == ConnectionState.waiting;

        return Scaffold(
          backgroundColor: _background,

          appBar: _buildAppBar(),

          body: ColoredBox(
            color: _background,
            child: PageBody(
              children: [
                const SizedBox(height: 20),

                // Status khusus ketika membuka riwayat.
                if (widget.fromHistory) ...[
                  _buildHistoryStatus(),

                  const SizedBox(height: 16),
                ],

                // Foto asli hasil pemindaian.
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: LeafPhoto(
                    path: result.imagePath,
                    height: 240,
                  ),
                ),

                const SizedBox(height: 20),

                // Card hasil identifikasi dan confidence.
                _buildResultCard(result, notLeaf: notLeaf),

                const SizedBox(height: 30),

                // Penjelasan AI tetap menggunakan
                // komponen CaptionSection asli.
                if (notLeaf) ...[
                  const Notice(
                    'Arahkan kamera ke satu daun pisang yang memenuhi layar, '
                    'dengan cahaya cukup, lalu pindai ulang.',
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 12),
                    Text(caption.photoTip),
                  ],
                ] else
                  CaptionSection(
                    result: result,
                    request: _caption,
                    onRetry: _retryCaption,
                  ),

                const SizedBox(height: 24),

                // Disclaimer asli.
                _buildDisclaimer(),

                // Error penyimpanan.
                if (_error != null) ...[
                  const SizedBox(height: 16),

                  Notice(
                    _error!,
                    error: true,
                  ),
                ],

                // Loading penyimpanan.
                if (_saving) ...[
                  const SizedBox(height: 16),

                  const LoadingMessage(
                    'Menyimpan riwayat...',
                  ),
                ],

                // Notifikasi berhasil disimpan.
                if (_saved) ...[
                  const SizedBox(height: 16),

                  _buildSavedNotice(),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),

          // Tombol simpan dan scan ulang hanya
          // ditampilkan pada hasil pemindaian baru.
          bottomNavigationBar: widget.fromHistory
              ? null
              : _buildBottomActions(notLeaf: notLeaf, checking: checking),
        );
      },
    );
  }

  // =========================================
  // APP BAR
  // =========================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _background,
      foregroundColor: _primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      titleSpacing: 4,

      systemOverlayStyle:
          const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness:
            Brightness.dark,
      ),

      // Tombol kembali.
      leading: IconButton(
        tooltip: 'Kembali',
        icon: const Icon(
          Icons.arrow_back_rounded,
          size: 23,
        ),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),

      // Judul menyesuaikan asal halaman.
      title: Text(
        widget.fromHistory
            ? 'Detail Riwayat'
            : 'Hasil Deteksi',
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.5,
          color: _primary,
        ),
      ),

      // Logo EcoPlant.
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/icons/LOGO.png',
                width: 34,
                height: 34,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ],

      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(
            height: 1,
            thickness: 0.7,
            color: _border,
          ),
        ),
      ),
    );
  }

  // =========================================
  // STATUS TERSIMPAN
  // Khusus halaman Detail Riwayat.
  // =========================================

  Widget _buildHistoryStatus() {
    return const Row(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: _secondary,
          size: 19,
        ),

        SizedBox(width: 8),

        Expanded(
          child: Text(
            'Tersimpan di riwayat',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _secondary,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================
  // RESULT CARD
  // Identifikasi, status, tanggal, confidence.
  // =========================================

  Widget _buildResultCard(DetectionResult result, {required bool notLeaf}) {
    final bool isHealthy =
        !notLeaf && result.predictedClass == LeafClass.healthy;

    final Color statusColor =
        isHealthy ? _secondary : _warning;

    final Color statusBackground = isHealthy
        ? _softGreen
        : const Color(0xFFF5EADB);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),

        // Border konsisten dengan History Screen.
        border: Border.all(
          color: _border,
          width: 1,
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label hasil identifikasi.
          const Text(
            'HASIL IDENTIFIKASI AWAL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.4,
              color: _muted,
            ),
          ),

          const SizedBox(height: 12),

          // Nama penyakit dan status kondisi.
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment:
                WrapCrossAlignment.center,
            children: [
              Text(
                notLeaf ? 'Bukan daun pisang' : result.predictedClass.label,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.8,
                  height: 1.2,
                  color: _primary,
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius:
                      BorderRadius.circular(8),
                ),

                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 6),

                    Text(
                      notLeaf ? 'Foto tidak sesuai' : isHealthy
                          ? 'Sehat'
                          : 'Perlu perhatian',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Tanggal deteksi asli.
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: _muted,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  displayDate(result.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Divider(
            height: 1,
            thickness: 0.8,
            color: _border,
          ),

          const SizedBox(height: 18),

          // Confidence model.
          _buildConfidence(result, notLeaf: notLeaf),
        ],
      ),
    );
  }

  // =========================================
  // CONFIDENCE MODEL
  // Nilai tetap menggunakan data asli.
  // =========================================

  Widget _buildConfidence(DetectionResult result, {required bool notLeaf}) {
    final confidence = notLeaf ? 0.0 : result.confidence;
    final confidenceLabel = '${(confidence * 100).toStringAsFixed(1)}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Confidence model',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _primary,
                ),
              ),
            ),

            const SizedBox(width: 8),

            Text(
              confidenceLabel,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.6,
                color: _primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Semantics(
          label: 'Confidence',
          value: confidenceLabel,

          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),

            child: LinearProgressIndicator(
              value: confidence,
              minHeight: 7,
              color: _secondary,
              backgroundColor: _softGreen,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          notLeaf
              ? 'Foto tidak dikenali sebagai daun pisang, jadi skor dibuat 0%.'
              : 'Skor keluaran model, bukan tingkat kepastian diagnosis.',
          style: const TextStyle(
            fontSize: 11,
            height: 1.6,
            color: _muted,
          ),
        ),
      ],
    );
  }

  // =========================================
  // DISCLAIMER
  // =========================================

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: _softGreen,
        borderRadius: BorderRadius.circular(12),
      ),

      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: _secondary,
          ),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              resultDisclaimer,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: _primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================
  // NOTIFIKASI BERHASIL DISIMPAN
  // =========================================

  Widget _buildSavedNotice() {
    return Semantics(
      liveRegion: true,

      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: _softGreen,
          borderRadius: BorderRadius.circular(12),
        ),

        child: const Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: _secondary,
              size: 22,
            ),

            SizedBox(width: 10),

            Expanded(
              child: Text(
                'Hasil berhasil disimpan ke riwayat.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: _primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================
  // BOTTOM ACTIONS
  // Khusus hasil deteksi baru.
  // =========================================

  Widget _buildBottomActions({required bool notLeaf, required bool checking}) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,

        border: Border(
          top: BorderSide(
            color: _border,
            width: 0.7,
          ),
        ),
      ),

      child: SafeArea(
        top: false,

        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20, 14, 20, 16,
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch,

            children: [
              // SIMPAN RIWAYAT
              if (!notLeaf) ...[
                FilledButton.icon(
                  onPressed: _saving || _saved || checking
                      ? null
                      : _save,

                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _muted,
                          ),
                        )
                      : Icon(
                          _saved
                              ? Icons.check_rounded
                              : Icons.bookmark_border_rounded,
                          size: 21,
                        ),

                  label: Text(
                    _saving
                        ? 'Menyimpan...'
                        : _saved
                            ? 'Tersimpan'
                            : 'Simpan riwayat',
                  ),

                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _softGreen,
                    disabledForegroundColor: _muted,
                    elevation: 0,
                    minimumSize: const Size(0, 50),

                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),

                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 10),
              ],

              // SCAN ULANG
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () {
                        Navigator.of(context).pop(true);
                      },

                icon: const Icon(
                  Icons.camera_alt_outlined,
                  size: 20,
                ),

                label: const Text('Scan ulang'),

                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  minimumSize: const Size(0, 48),

                  side: const BorderSide(
                    color: Color(0xFFB9CBB2),
                  ),

                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),

                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
