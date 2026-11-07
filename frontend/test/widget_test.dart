import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('ProGold app renders authentication screen with glassmorphic tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ProGoldApp());
    await tester.pump(const Duration(milliseconds: 500));

    // Verify presence of tabs and brand title
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Register Tenant'), findsWidgets);
    expect(find.text('ProGold'), findsOneWidget);
  });
}
