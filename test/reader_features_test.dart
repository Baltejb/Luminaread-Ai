import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luminaread_ai/main.dart';
import 'package:luminaread_ai/models/translation_models.dart';
import 'package:luminaread_ai/screens/reader_screen.dart';
import 'package:luminaread_ai/screens/thumbnail_grid_screen.dart';
import 'package:luminaread_ai/services/library_service.dart';
import 'package:luminaread_ai/theme/app_theme.dart';

TranslationResult _loadFixture() {
  final raw = File('test/fixtures/translate_response.json').readAsStringSync();
  return TranslationResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

TranslationResult _twoPages() {
  final one = _loadFixture();
  return TranslationResult(
    pages: [one.pages.first, one.pages.first],
    targetLang: one.targetLang,
    provider: one.provider,
  );
}

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark(), home: child);

/// Fails if any part of the page area paints nothing (zero size), which is
/// what the reported "solid black body" bug looks like from the outside.
void _expectPagePaints(WidgetTester tester) {
  final imageBox = tester.getSize(find.byType(Image).first);
  expect(imageBox.width, greaterThan(0), reason: 'page image must have width');
  expect(imageBox.height, greaterThan(0), reason: 'page image must have height');
  final text = find.textContaining('TRANS Line 1');
  expect(text, findsWidgets, reason: 'translated overlay text must be built');
  final textBox = tester.getSize(text.first);
  expect(textBox.width, greaterThan(0), reason: 'overlay text must have width');
  expect(textBox.height, greaterThan(0), reason: 'overlay text must have height');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('page image + translated overlay paint at full size', (tester) async {
    await tester.pumpWidget(_wrap(ReaderScreen(result: _loadFixture(), sourceFileName: 'book.pdf')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull, reason: 'ReaderScreen must not throw');
    expect(find.byType(PageView), findsOneWidget);
    _expectPagePaints(tester);
  });

  testWidgets('full app: pushed ReaderScreen paints inside the real MaterialApp', (tester) async {
    await tester.pumpWidget(const LuminaReadApp());
    await tester.pump();

    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    final result = _loadFixture();
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(result: result, sourceFileName: 'book.pdf'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(ReaderScreen), findsOneWidget);
    _expectPagePaints(tester);
  });

  testWidgets('tapping a page opens the zoom screen', (tester) async {
    await tester.pumpWidget(_wrap(ReaderScreen(result: _loadFixture(), sourceFileName: 'book.pdf')));
    await tester.pump();

    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();

    expect(find.byType(ZoomPageScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The zoomed page must actually paint too.
    expect(find.byType(Image), findsWidgets);
    final box = tester.getSize(find.byType(Image).first);
    expect(box.width, greaterThan(0));
    expect(box.height, greaterThan(0));

    // Back returns to the reader.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ZoomPageScreen), findsNothing);
    expect(find.byType(ReaderScreen), findsOneWidget);
  });

  testWidgets('grid icon opens thumbnails and selecting one jumps to that page', (tester) async {
    await tester.pumpWidget(_wrap(ReaderScreen(result: _twoPages(), sourceFileName: 'book.pdf')));
    await tester.pump();

    await tester.tap(find.byTooltip('All pages'));
    await tester.pumpAndSettle();
    expect(find.byType(ThumbnailGridScreen), findsOneWidget);

    final thumbs = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(InkWell),
    );
    expect(thumbs, findsNWidgets(2), reason: 'one thumbnail per page');
    await tester.tap(thumbs.last); // second page
    await tester.pumpAndSettle();

    expect(find.byType(ThumbnailGridScreen), findsNothing);
    expect(find.text('2 / 2'), findsOneWidget, reason: 'reader should jump to page 2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('slider scrubbing changes the current page', (tester) async {
    await tester.pumpWidget(_wrap(ReaderScreen(result: _twoPages(), sourceFileName: 'book.pdf')));
    await tester.pump();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget, reason: 'slider should move to page 2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('library: save, resume at last page, delete', (tester) async {
    final result = _twoPages();
    final entry = LibraryEntry(
      id: 'test-book',
      title: 'book.pdf',
      targetLang: 'pa',
      provider: 'offline',
      accentColorValue: 0xFF00FFD1,
      pageCount: result.pages.length,
      lastPage: 0,
      savedAt: DateTime.now(),
      result: result,
    );

    await LibraryService.save(entry);
    var entries = await LibraryService.listEntries();
    expect(entries, hasLength(1));
    expect(entries.first.result.pages, hasLength(2));
    expect(entries.first.result.pages.first.imageBytes, isNotNull,
        reason: 'page images must round-trip through local storage');

    // Resume: open from the library at the stored page.
    await LibraryService.updateLastPage('test-book', 1);
    entries = await LibraryService.listEntries();
    expect(entries.first.lastPage, 1);

    await tester.pumpWidget(
      _wrap(
        ReaderScreen(
          result: entries.first.result,
          sourceFileName: entries.first.title,
          libraryId: entries.first.id,
          initialPage: entries.first.lastPage,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('2 / 2'), findsOneWidget, reason: 'must resume on the last page read');
    _expectPagePaints(tester);

    // Delete removes it from the library.
    await LibraryService.remove('test-book');
    expect(await LibraryService.listEntries(), isEmpty);
  });
}
