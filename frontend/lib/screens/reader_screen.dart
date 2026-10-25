import 'package:flutter/material.dart';

import '../models/translation_models.dart';
import '../theme/app_theme.dart';

/// Shows one translated book: a swipeable page view where every page is
/// the backend's redacted (original text painted over) background image
/// with the translated spans positioned exactly where the original text
/// used to be — the "Visual-Sync" overlay from the project spec.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.result, required this.sourceFileName});

  final TranslationResult result;
  final String sourceFileName;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) => _TranslatedPageView(page: pages[index]),
            ),
    );
  }
}

class _TranslatedPageView extends StatelessWidget {
  const _TranslatedPageView({required this.page});

  final TranslatedPage page;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = page.width > 0 && page.height > 0 ? page.width / page.height : 0.75;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 2)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (page.imageBytes != null)
                        Image.memory(page.imageBytes!, fit: BoxFit.fill)
                      else
                        const ColoredBox(color: Colors.white),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single translated line, sized to fit the box the original text used
/// to occupy. [FittedBox] shrinks long translations rather than clipping
/// them — translations are rarely the exact same length as the source.
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
