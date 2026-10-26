import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../models/translation_models.dart';
import '../services/api_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
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

  Future<List<LibraryEntry>> _libraryFuture = LibraryService.listEntries();

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

  void _reloadLibrary() {
    setState(() {
      _libraryFuture = LibraryService.listEntries();
    });
  }

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
    _extractCoverTheme();
  }

  Future<void> _extractCoverTheme() async {
    final file = _pickedFile;
    if (file == null || file.bytes == null) return;
    try {
      final coverBytes = await _api.fetchCover(pdfBytes: file.bytes!, fileName: file.name);
      final palette = await PaletteGenerator.fromImageProvider(
        MemoryImage(coverBytes),
        maximumColorCount: 24,
      );
      final accent =
          palette.vibrantColor?.color ?? palette.dominantColor?.color ?? palette.mutedColor?.color;
      if (accent != null) {
        ThemeController.instance.setSeed(accent);
      }
    } catch (_) {}
  }

  Future<void> _translate() async {
    final file = _pickedFile;
    if (file == null || file.bytes == null) {
      setState(() => _error = 'Pick a PDF first.');
      return;
    }
    if (_provider != TranslationProvider.offline && _apiKeyController.text.trim().isEmpty) {
      setState(() => _error = '${_provider.label} needs an API key -- paste one, or switch to Offline.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    TranslationResult? result;
    try {
      result = await _api.translatePdf(
        pdfBytes: file.bytes!,
        fileName: file.name,
        targetLang: _targetLang,
        provider: _provider,
        apiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    final translated = result;
    if (translated == null || !mounted) return;

    final entry = LibraryEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_${file.name}',
      title: file.name,
      targetLang: _targetLang,
      provider: _provider.apiValue,
      accentColorValue: Theme.of(context).colorScheme.primary.toARGB32(),
      pageCount: translated.pages.length,
      lastPage: 0,
      savedAt: DateTime.now(),
      result: translated,
    );

    String? libraryId = entry.id;
    try {
      await LibraryService.save(entry);
    } on LibraryException catch (e) {
      libraryId = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(result: translated, sourceFileName: file.name, libraryId: libraryId),
      ),
    );
    if (mounted) _reloadLibrary();
  }

  Future<void> _openFromLibrary(LibraryEntry entry) async {
    ThemeController.instance.setSeed(Color(entry.accentColorValue));
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          result: entry.result,
          sourceFileName: entry.title,
          libraryId: entry.id,
          initialPage: entry.lastPage,
        ),
      ),
    );
    if (mounted) _reloadLibrary();
  }

  Future<void> _deleteFromLibrary(LibraryEntry entry) async {
    await LibraryService.remove(entry.id);
    _reloadLibrary();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
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
                      children: [
                        Icon(Icons.auto_awesome, color: accent, size: 28),
                        const SizedBox(width: 10),
                        const Text(
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
                      'Any book, any language -- read it in yours, same layout.',
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
                            child: _PickerBox(fileName: _pickedFile?.name, accentColor: accent),
                          ),
                          const SizedBox(height: 18),
                          DropdownButtonFormField<String>(
                            initialValue: _targetLang,
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
                            initialValue: _provider,
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
                                labelText: '${_provider.label} API key (BYOK -- kept on this device only)',
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
                    _LibrarySection(
                      future: _libraryFuture,
                      onOpen: _openFromLibrary,
                      onDelete: _deleteFromLibrary,
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

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({required this.future, required this.onOpen, required this.onDelete});

  final Future<List<LibraryEntry>> future;
  final ValueChanged<LibraryEntry> onOpen;
  final ValueChanged<LibraryEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LibraryEntry>>(
      future: future,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <LibraryEntry>[];
        if (entries.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Row(
              children: const [
                Icon(Icons.auto_stories, color: AppColors.textSecondary, size: 20),
                SizedBox(width: 8),
                Text(
                  'My Library',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final entry in entries)
              _LibraryTile(entry: entry, onOpen: () => onOpen(entry), onDelete: () => onDelete(entry)),
          ],
        );
      },
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({required this.entry, required this.onOpen, required this.onDelete});

  final LibraryEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = Color(entry.accentColorValue);
    final progress = entry.pageCount > 0 ? (entry.lastPage + 1) / entry.pageCount : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Page ${entry.lastPage + 1} / ${entry.pageCount} -- ${(progress * 100).round()}%',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                tooltip: 'Remove from library',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerBox extends StatelessWidget {
  const _PickerBox({this.fileName, required this.accentColor});

  final String? fileName;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final picked = fileName != null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: picked ? accentColor : AppColors.border,
          width: picked ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            picked ? Icons.picture_as_pdf : Icons.upload_file,
            color: picked ? accentColor : AppColors.textSecondary,
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
