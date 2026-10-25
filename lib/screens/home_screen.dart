import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _apiKeyController = TextEditingController();

  PlatformFile? _pickedFile;
  String _targetLang = 'pa';
  TranslationProvider _provider = TranslationProvider.offline;
  bool _loading = false;
  String? _error;

  static const Map<String, String> _languages = {
    'pa': 'Punjabi (ਪੰਜਾਬੀ)',
    'en': 'English',
    'hi': 'Hindi (हिंदी)',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'ar': 'Arabic',
    'zh': 'Chinese',
  };

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _pickedFile = result.files.single;
      _error = null;
    });
  }

  Future<void> _translate() async {
    final file = _pickedFile;
    if (file == null || file.bytes == null) {
      setState(() => _error = 'Pick a PDF first.');
      return;
    }
    if (_provider != TranslationProvider.offline && _apiKeyController.text.trim().isEmpty) {
      setState(() => _error = '${_provider.label} needs an API key — paste one, or switch to Offline.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _api.translatePdf(
        pdfBytes: file.bytes!,
        fileName: file.name,
        targetLang: _targetLang,
        provider: _provider,
        apiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReaderScreen(result: result, sourceFileName: file.name)),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -0.8),
            radius: 1.4,
            colors: [Color(0xFF15131F), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: AppColors.neonCyan, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'LuminaRead AI',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Any book, any language — read it in yours, same layout.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            onTap: _pickFile,
                            borderRadius: BorderRadius.circular(14),
                            child: _PickerBox(fileName: _pickedFile?.name),
                          ),
                          const SizedBox(height: 18),
                          DropdownButtonFormField<String>(
                            value: _targetLang,
                            decoration: const InputDecoration(labelText: 'Translate to'),
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(color: AppColors.textPrimary),
                            items: _languages.entries
                                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                .toList(),
                            onChanged: (v) => setState(() => _targetLang = v ?? _targetLang),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<TranslationProvider>(
                            value: _provider,
                            decoration: const InputDecoration(labelText: 'Translation engine'),
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(color: AppColors.textPrimary),
                            items: TranslationProvider.values
                                .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                                .toList(),
                            onChanged: (v) => setState(() => _provider = v ?? _provider),
                          ),
                          if (_provider != TranslationProvider.offline) ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _apiKeyController,
                              obscureText: true,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: '${_provider.label} API key (BYOK — kept on this device only)',
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          if (_error != null) ...[
                            Text(_error!, style: const TextStyle(color: AppColors.danger)),
                            const SizedBox(height: 12),
                          ],
                          ElevatedButton(
                            onPressed: _loading ? null : _translate,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black),
                                  )
                                : const Text('Translate & Open'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerBox extends StatelessWidget {
  const _PickerBox({this.fileName});

  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final picked = fileName != null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: picked ? AppColors.neonCyan : AppColors.border,
          width: picked ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            picked ? Icons.picture_as_pdf : Icons.upload_file,
            color: picked ? AppColors.neonCyan : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              picked ? fileName! : 'Tap to pick a PDF book',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: picked ? AppColors.textPrimary : AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
