import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luminaread_ai/models/translation_models.dart';
import 'package:luminaread_ai/screens/reader_screen.dart';
import 'package:luminaread_ai/theme/app_theme.dart';

TranslationResult _loadFixture() {
  final raw = File('test/fixtures/translate_response.json').readAsStringSync();
  return TranslationResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: child,
    );

void main() {
  testWidgets('ReaderScreen paints the page image and translated overlay text', (tester) async {
    final result = _loadFixture();

    await tester.pumpWidget(_wrap(ReaderScreen(result: result, sourceFileName: 'book.pdf')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull, reason: 'ReaderScreen threw during build/layout');
    expect(find.byType(Image), findsWidgets, reason: 'page background image should be built');
    expect(
      find.textContaining('TRANS Line 1'),
      findsWidgets,
      reason: 'translated span overlay text should be built',
    );
    expect(find.byType(PageView), findsOneWidget);

    // A widget can be present in the tree yet paint nothing (zero size) --
    // which is exactly what a black, empty page area would look like.
    final imageBox = tester.getSize(find.byType(Image).first);
    expect(imageBox.width, greaterThan(0), reason: 'page image must have width');
    expect(imageBox.height, greaterThan(0), reason: 'page image must have height');

    final columnBox = tester.getSize(find.byType(Column).first);
    expect(columnBox.height, greaterThan(0), reason: 'page column must have height');

    final textBox = tester.getSize(find.textContaining('TRANS Line 1').first);
    expect(textBox.width, greaterThan(0), reason: 'overlay text must paint with width');
    expect(textBox.height, greaterThan(0), reason: 'overlay text must paint with height');
  });

  testWidgets('ReaderScreen paints when the result carries two pages', (tester) async {
    final result = _loadFixture();
    final twoPages = TranslationResult(
      pages: [result.pages.first, result.pages.first],
      targetLang: result.targetLang,
      provider: result.provider,
    );

    await tester.pumpWidget(
      _wrap(ReaderScreen(result: twoPages, sourceFileName: 'book.pdf')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsWidgets);
    expect(find.byType(Slider), findsOneWidget);
  });
}
