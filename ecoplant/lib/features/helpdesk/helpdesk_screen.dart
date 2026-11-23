import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpdeskScreen extends StatefulWidget {
  const HelpdeskScreen({super.key});

  @override
  State<HelpdeskScreen> createState() => _HelpdeskScreenState();
}

class _HelpdeskScreenState extends State<HelpdeskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  String _category = 'Scan daun';

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final subject = Uri.encodeComponent('Laporan kendala EcoPlant AI');
    final body = Uri.encodeComponent(
      'Kategori: $_category\n\n${_description.text.trim()}',
    );
    final email = Uri(
      scheme: 'mailto',
      path: 'fatahaidaraly@gmail.com',
      query: 'subject=$subject&body=$body',
    );

    try {
      if (await launchUrl(email, mode: LaunchMode.externalApplication)) return;
    } on PlatformException {
      // Show the same feedback if the platform could not open the draft.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Aplikasi email tidak dapat dibuka. '
          'Periksa pengaturan email di perangkat Anda.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Helpdesk')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Pertanyaan umum',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const ExpansionTile(
            title: Text('Bagaimana cara memindai daun?'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedAlignment: Alignment.centerLeft,
            children: [
              Text(
                'Buka tab Scan, lalu ambil foto atau pilih gambar daun '
                'pisang dari galeri. Gunakan foto yang terang dan tajam.',
              ),
            ],
          ),
          const ExpansionTile(
            title: Text('Kenapa kamera atau galeri tidak terbuka?'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedAlignment: Alignment.centerLeft,
            children: [
              Text(
                'Periksa izin kamera dan foto untuk EcoPlant AI di '
                'pengaturan perangkat, lalu coba lagi.',
              ),
            ],
          ),
          const ExpansionTile(
            title: Text('Di mana hasil pemindaian sebelumnya?'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedAlignment: Alignment.centerLeft,
            children: [
              Text('Buka tab Riwayat dan pilih hasil yang ingin dilihat.'),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Laporkan kendala',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Buka draf laporan ke email. '
            'Periksa isinya sebelum mengirim.',
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Scan daun',
                      child: Text('Scan daun'),
                    ),
                    DropdownMenuItem(value: 'Riwayat', child: Text('Riwayat')),
                    DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
                  ],
                  onChanged: (value) => _category = value!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi kendala',
                    hintText: 'Ceritakan apa yang terjadi',
                  ),
                  minLines: 3,
                  maxLines: 6,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Isi deskripsi kendala.'
                      : null,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _sendEmail,
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Kirim Email'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
