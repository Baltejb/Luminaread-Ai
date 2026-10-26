import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luminaread_ai/main.dart';
import 'package:luminaread_ai/models/translation_models.dart';
import 'package:luminaread_ai/services/usage_service.dart';

TranslationResult _loadFixture() {
  final raw = File('test/fixtures/translate_response.json').readAsStringSync();
  return TranslationResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('UsageService', () {
    test('labelFor groups per key without ever storing the key itself', () {
      expect(UsageService.labelFor(provider: 'gemini'), 'gemini');
      expect(UsageService.labelFor(provider: 'gemini', apiKey: ''), 'gemini');
      expect(UsageService.labelFor(provider: 'gemini', apiKey: 'abcdef1234'), 'gemini (…1234)');
      expect(UsageService.labelFor(provider: 'gemini', apiKey: 'ab'), 'gemini (…ab)');
    });

    test('record accumulates calls and characters per provider + key', () async {
      await UsageService.record(provider: 'gemini', apiKey: 'xxxx1111', characters: 100);
      await UsageService.record(provider: 'gemini', apiKey: 'xxxx1111', characters: 50);
      await UsageService.record(provider: 'gemini', apiKey: 'yyyy2222', characters: 10);

      final all = await UsageService.load();
      expect(all.keys, hasLength(2));
      expect(all['gemini (…1111)']!.calls, 2);
      expect(all['gemini (…1111)']!.characters, 150);
      expect(all['gemini (…2222)']!.calls, 1);
      expect(all['gemini (…1111)']!.lastUsed, isNotNull);
    });

    test('reset clears a single row, then everything', () async {
      await UsageService.record(provider: 'deepl', apiKey: 'aaaa1111', characters: 10);
      await UsageService.record(provider: 'gemini', apiKey: 'bbbb2222', characters: 20);

      await UsageService.reset(label: 'deepl (…1111)');
      var all = await UsageService.load();
      expect(all.keys, ['gemini (…2222)']);

      await UsageService.reset();
      expect(await UsageService.load(), isEmpty);
    });

    test('load survives corrupt stored data', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lumina_usage', '{not json');
      expect(await UsageService.load(), isEmpty);
    });

    test('estimateCharacters counts the rendered text of every page', () {
      final result = _loadFixture();
      var expected = 0;
      for (final page in result.pages) {
        for (final span in page.spans) {
          expected += span.text.length;
        }
      }
      expect(UsageService.estimateCharacters(result), expected);
      expect(expected, greaterThan(0));
    });
  });

  testWidgets('home screen exposes the Usage view with its estimate disclaimer', (tester) async {
    await UsageService.record(provider: 'offline', characters: 4242);

    await tester.pumpWidget(const LuminaReadApp());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Usage'), findsOneWidget);
    expect(find.text('Usage is an estimate tracked by this app'), findsOneWidget);

    await tester.tap(find.text('Usage'));
    await tester.pumpAndSettle();

    expect(find.text('Translation usage'), findsOneWidget);
    expect(find.textContaining('App-tracked estimate'), findsOneWidget);
    expect(find.textContaining('4242 characters'), findsOneWidget);

    // Reset empties the counter and the view updates.
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('No translations yet.'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Translation usage'), findsNothing);
  });
}
