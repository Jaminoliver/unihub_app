import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unihub/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UniHubApp());

    // Verify that the app launches without errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}