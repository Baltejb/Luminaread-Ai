import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luminaread_ai/main.dart';

void main() {
  testWidgets('App starts on the home screen with its title', (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaReadApp());

    expect(find.text('LuminaRead AI'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });
}
