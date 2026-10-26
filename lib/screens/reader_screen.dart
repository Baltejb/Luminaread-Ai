import 'package:flutter/material.dart';

import '../models/translation_models.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import 'thumbnail_grid_screen.dart';

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
                child: Slider(
                  value: _currentPage.toDouble().clamp(0.0, _maxPageIndex.toDouble()).toDouble(),
                  min: 0,
                  max: _maxPageIndex.toDouble(),
                  divisions: _maxPageIndex > 0 ? _maxPageIndex : null,
                  label: '${_currentPage + 1}',
                  onChanged: (v) => _goToPage(v.round()),
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
    final aspectRatio = page.width > 0 && page.height > 0 ? page.width / page.height : 0.75;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'DEBUG w=${page.width} h=${page.height} ratio=${aspectRatio.toStringAsFixed(3)} '
            'bytes=${page.imageBytes?.length} spans=${page.spans.length}',
            style: const TextStyle(color: Colors.yellow, fontSize: 11),
          ),
        ),
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
    final aspectRatio = page.width > 0 && page.height > 0 ? page.width / page.height : 0.75;
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
