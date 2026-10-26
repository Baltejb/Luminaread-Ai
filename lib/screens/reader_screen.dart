import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/translation_models.dart';
import '../services/library_service.dart';
import '../services/pdf_export_service.dart';
import '../theme/app_theme.dart';
import 'thumbnail_grid_screen.dart';

/// Page aspect ratio (width / height) with guards against degenerate or
/// non-finite dimensions. A non-finite ratio makes [AspectRatio] lay out a
/// zero-size box, which paints nothing at all -- a silently blank page area
/// with no error and no broken-image icon. Any bad value falls back to a
/// readable 3:4 page.
double _pageAspectRatio(double width, double height) {
  if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) return 0.75;
  final ratio = width / height;
  if (!ratio.isFinite || ratio <= 0) return 0.75;
  return ratio;
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.result,
    required this.sourceFileName,
    this.libraryId,
    this.initialPage = 0,
  });

  final TranslationResult result;
  final String sourceFileName;
  final String? libraryId;
  final int initialPage;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final int _maxPageIndex = widget.result.pages.isEmpty ? 0 : widget.result.pages.length - 1;
  late final PageController _pageController =
      PageController(initialPage: widget.initialPage.clamp(0, _maxPageIndex).toInt());
  late int _currentPage = widget.initialPage.clamp(0, _maxPageIndex).toInt();
  bool _exporting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.jumpToPage(index);
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    final id = widget.libraryId;
    if (id != null) {
      LibraryService.updateLastPage(id, index);
    }
  }

  Future<void> _openThumbnails() async {
    final selected = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => ThumbnailGridScreen(pages: widget.result.pages, currentPage: _currentPage),
      ),
    );
    if (selected != null) _goToPage(selected);
  }

  void _openZoom(TranslatedPage page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ZoomPageScreen(page: page)),
    );
  }

  /// Assemble the already-rendered page images into a single PDF and hand it
  /// to the platform share/download flow.
  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final fileName = PdfExportService.exportFileName(widget.sourceFileName);
    try {
      final bytes = await PdfExportService.buildPdf(widget.result, title: widget.sourceFileName);
      final shared = await Printing.sharePdf(bytes: bytes, filename: fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(shared ? 'Saved $fileName' : 'PDF export was cancelled.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export the PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.result.pages;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.sourceFileName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (pages.isNotEmpty)
            IconButton(
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Download as PDF',
              onPressed: _exporting ? null : _exportPdf,
            ),
          if (pages.length > 1)
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: 'All pages',
              onPressed: _openThumbnails,
            ),
          if (pages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentPage + 1} / ${pages.length}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
      body: pages.isEmpty
          ? const Center(
              child: Text('No pages to show.', style: TextStyle(color: AppColors.textSecondary)),
            )
          : PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => _TranslatedPageView(
                page: pages[index],
                onTapZoom: () => _openZoom(pages[index]),
              ),
            ),
      bottomNavigationBar: pages.length > 1
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                // The Slider expands to whatever height it is given; inside
                // Scaffold.bottomNavigationBar that meant it consumed the
                // whole screen, starving the body of height and leaving the
                // page area completely blank. Pin it to its intended height.
                child: SizedBox(
                  height: 48,
                  child: Slider(
                    value: _currentPage.toDouble().clamp(0.0, _maxPageIndex.toDouble()).toDouble(),
                    min: 0,
                    max: _maxPageIndex.toDouble(),
                    divisions: _maxPageIndex > 0 ? _maxPageIndex : null,
                    label: '${_currentPage + 1}',
                    onChanged: (v) => _goToPage(v.round()),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _TranslatedPageView extends StatelessWidget {
  const _TranslatedPageView({required this.page, required this.onTapZoom});

  final TranslatedPage page;
  final VoidCallback onTapZoom;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = _pageAspectRatio(page.width, page.height);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: GestureDetector(
                onTap: onTapZoom,
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 2),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _PageStack(page: page),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ZoomPageScreen extends StatelessWidget {
  const ZoomPageScreen({super.key, required this.page});

  final TranslatedPage page;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = _pageAspectRatio(page.width, page.height);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: _PageStack(page: page),
          ),
        ),
      ),
    );
  }
}

class _PageStack extends StatelessWidget {
  const _PageStack({required this.page});

  final TranslatedPage page;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (page.imageBytes != null)
              Image.memory(
                page.imageBytes!,
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.black26, size: 40),
                  ),
                ),
              )
            else
              const ColoredBox(
                color: Colors.white,
                child: Center(
                  child: Icon(Icons.image_not_supported_outlined, color: Colors.black26, size: 40),
                ),
              ),
            for (final span in page.spans)
              Positioned(
                left: span.left * w,
                top: span.top * h,
                width: span.width * w,
                height: span.height * h,
                child: _OverlayText(text: span.text, boxHeight: span.height * h),
              ),
          ],
        );
      },
    );
  }
}

class _OverlayText extends StatelessWidget {
  const _OverlayText({required this.text, required this.boxHeight});

  final String text;
  final double boxHeight;

  @override
  Widget build(BuildContext context) {
    final double fontSize = (boxHeight * 0.78).clamp(8.0, 48.0).toDouble();
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(color: Colors.black, fontSize: fontSize, height: 1.0),
      ),
    );
  }
}
