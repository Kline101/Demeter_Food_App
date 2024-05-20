import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demeter/login_page.dart';
import 'package:mockito/mockito.dart';


class MockFirebaseAuth extends Mock implements FirebaseAuth {
  // Simulate throwing a FirebaseAuthException
  @override
  Future<UserCredential> signInWithEmailAndPassword(
      {String? email, String? password}) async {
    throw FirebaseAuthException(code: 'wrong-password');
  }
}

abstract class AuthInterface {
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
}

void main() {
  group('Login form validation', () {
    testWidgets('Empty email field should show error', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
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
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      // Find the email field
      final emailField = find.byType(TextFormField).first;
      // Enter invalid email format
      await tester.enterText(emailField, 'not-a-valid-email');
      // Tap the 'Submit' button
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(seconds: 2));
      // Expect the error message
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('Empty password field should show error', (tester) async {
      // Build the widget
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
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

    testWidgets('Incorrect credentials should trigger alert dialog', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginPage(),
      ));
      final emailField = find.byType(TextFormField).first;
      // Enter valid but non existent email format
      await tester.enterText(emailField, 'notavalidemail@gmail.com');
      final passwordField = find.byType(TextFormField).last;
      // Enter valid but wrong password input
      await tester.enterText(passwordField, 'abcdef');
      // Tap the 'Submit' button
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(seconds: 2));
      // Expect the dialog
      expect(find.byKey(const Key('loginFailedDialog')), findsOneWidget);
      expect(find.text('Login Failed'), findsOneWidget);
    });
  });
}
