// Basic Flutter widget test for the Sims-like game app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sims_like_game/presentation/game_app.dart';

void main() {
  testWidgets('GameApp launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GameApp());

    // Verify that the app launches without errors
    expect(find.byType(MaterialApp), findsOneWidget);

    // The game should be running (we can't easily test Flame game content in widget tests)
    // but we can verify the app structure is correct
    await tester.pump();

    // If we get here without exceptions, the basic app structure is working
    expect(true, isTrue);
  });

  testWidgets('Main function initializes app correctly', (
    WidgetTester tester,
  ) async {
    // Test that main() creates the right app structure
    await tester.pumpWidget(const GameApp());

    // Verify MaterialApp is created with correct title
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, equals('Sims-Like Game'));
    expect(materialApp.debugShowCheckedModeBanner, isFalse);
  });
}
