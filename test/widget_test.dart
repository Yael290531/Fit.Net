// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_net/main.dart';

void main() {
  testWidgets('Fit.Net app loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FitNetApp());

    // Wait for animations to finish
    await tester.pumpAndSettle();

    // Verify that the login screen is rendered (has the 'Iniciar Sesión' text)
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    
    // Verify the username and password fields exist
    expect(find.byType(TextField), findsWidgets);
  });
}
