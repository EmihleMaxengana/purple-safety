import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purple_safety/main.dart';

void main() {
  testWidgets('Purple Safety app starts without crashing', (WidgetTester tester) async {
    //(build the app and trigger a frame)
    await tester.pumpWidget(const PurpleSafetyApp());
    
    //(verify the app starts and shows something)
    expect(find.byType(MaterialApp), findsOneWidget);
    
    //(wait for any async operations)
    await tester.pumpAndSettle();
    
    //(verify the login screen appears)
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}