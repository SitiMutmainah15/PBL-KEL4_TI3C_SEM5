import 'dart:io';
import 'package:flutter/material.dart';
import 'theme.dart';

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(padding: const EdgeInsets.all(20), children: children),
      ),
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: error,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.info_outline,
            color: error ? AppColors.error : AppColors.forest900,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.ink900, height: 1.5),
            ),
          ),
        ],
      ),
    ),
  );
}

class LoadingMessage extends StatelessWidget {
  const LoadingMessage(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    ),
  );
}

class LeafPhoto extends StatelessWidget {
  const LeafPhoto({super.key, required this.path, this.height = 240});
  final String path;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Image.file(
      File(path),
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      semanticLabel: 'Foto daun yang diperiksa',
      errorBuilder: (_, error, stack) => Container(
        height: height,
        color: AppColors.cream100,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: const Text('Foto tidak tersedia.', textAlign: TextAlign.center),
      ),
    ),
  );
}

String displayDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
}
