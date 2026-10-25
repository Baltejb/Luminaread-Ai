// Basic smoke test: the app boots and the Home screen's picker UI shows up.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luminaread_ai/main.dart';

void main() {
  testWidgets('App starts and shows the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaReadApp());
    await tester.pump();

    expect(find.text('LuminaRead AI'), findsOneWidget);
    expect(find.text('Tap to pick a PDF book'), findsOneWidget);
    expect(find.text('Translate & Open'), findsOneWidget);
  });
}
