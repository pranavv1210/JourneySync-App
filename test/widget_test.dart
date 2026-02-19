// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:journeysync/main.dart';

void main() {
  testWidgets('app boots with splash screen shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      JourneySyncApp(initializationFuture: Future<void>.value()),
    );
    await tester.pump(const Duration(seconds: 4));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
