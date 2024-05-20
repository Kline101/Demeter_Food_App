import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demeter/register_page.dart';

void main() {
  group('RegisterPage form validation', () {
    testWidgets('Empty email field should show error', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
      // Find the email field
      final emailField = find.byType(TextFormField).first;
      // Enter an empty string as email input
      await tester.enterText(emailField, '');
      // Find the 'Submit' button and scroll
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(seconds: 2));
      // Expect the error message
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('Invalid email format should show error', (tester) async {
      // Build the widget
      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
      // Find the email field
      final emailField = find.byType(TextFormField).first;
      // Enter invalid email format
      await tester.enterText(emailField, 'not-a-valid-email');
      // Tap the 'Submit' button
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byType(ElevatedButton));
      // Increased timeout if there might be animations
      await tester.pump(const Duration(seconds: 2));
      // Expect the error message
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('Empty password field should show error', (tester) async {
      // Build the widget
      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
      // Find the password field
      final passwordField = find.byType(TextFormField).last;
      // Enter an empty string as password input
      await tester.enterText(passwordField, '');
      // Tap the 'Submit' button
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byType(ElevatedButton));
      // Increased timeout if there might be animations
      await tester.pump(const Duration(seconds: 2));
      // Expect the error message
      expect(find.text('Please enter your password'), findsOneWidget);
    });
  });
}
