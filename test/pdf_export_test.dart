import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luminaread_ai/models/translation_models.dart';
import 'package:luminaread_ai/screens/reader_screen.dart';
import 'package:luminaread_ai/services/pdf_export_service.dart';
import 'package:luminaread_ai/theme/app_theme.dart';

TranslationResult _loadFixture() {
  final raw = File('test/fixtures/translate_response.json').readAsStringSync();
  return TranslationResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

TranslationResult _withPages(int count) {
  final one = _loadFixture();
  return TranslationResult(
    pages: List.generate(count, (_) => one.pages.first),
    targetLang: one.targetLang,
    provider: one.provider,
  );
}

void main() {
  group('PdfExportService', () {
    test('exportFileName keeps the base name and appends the suffix', () {
      expect(PdfExportService.exportFileName('book.pdf'), 'book (translated).pdf');
      expect(PdfExportService.exportFileName('My Book.PDF'), 'My Book (translated).pdf');
      expect(PdfExportService.exportFileName('book'), 'book (translated).pdf');
    });

    test('buildPdf assembles every page from the in-memory images', () async {
      final onePage = await PdfExportService.buildPdf(_withPages(1));
      expect(onePage, isNotEmpty);
      expect(String.fromCharCodes(onePage.sublist(0, 5)), '%PDF-');

      final threePages = await PdfExportService.buildPdf(_withPages(3));
      expect(String.fromCharCodes(threePages.sublist(0, 5)), '%PDF-');
      expect(
        threePages.length,
        greaterThan(onePage.length),
        reason: 'more page images must produce a bigger PDF',
      );
    });

    test('buildPdf survives pages without a rendered image', () async {
      final result = _withPages(1);
      final noImages = TranslationResult(
        pages: [
          TranslatedPage(
            page: 1,
            width: result.pages.first.width,
            height: result.pages.first.height,
            spans: result.pages.first.spans,
          ),
        ],
        targetLang: result.targetLang,
        provider: result.provider,
      );
      final bytes = await PdfExportService.buildPdf(noImages);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });

    test('buildPdf falls back to a sane page size for degenerate dimensions', () async {
      final result = _withPages(1);
      final broken = TranslationResult(
        pages: [
          TranslatedPage(
            page: 1,
            width: 0,
            height: 0,
            spans: const [],
            imageBytes: result.pages.first.imageBytes,
          ),
        ],
        targetLang: result.targetLang,
        provider: result.provider,
      );
      final bytes = await PdfExportService.buildPdf(broken);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });
  });

  testWidgets('ReaderScreen exposes the Download as PDF action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: ReaderScreen(result: _withPages(1), sourceFileName: 'book.pdf'),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Download as PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
