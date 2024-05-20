import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('Demeter App Integration Tests', () {
    late FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
      await driver.waitUntilFirstFrameRasterized();
    });

    tearDownAll(() async {
      driver.close();
        });

    test('Registration and Login Flow', () async {
      // --- Registration ---
      // Find register button
      final registerButtonFinder = find.byValueKey('registerButton');
      final emailFieldFinder = find.ancestor(
          of: find.text('Email'),
          matching: find.byType('TextFormField')
      );

      // Find the 'Password' TextFormField
      final passwordFieldFinder = find.ancestor(
          of: find.text('Password'),
          matching: find.byType('TextFormField')
      );
      // Tap register button
      await driver.runUnsynchronized(() async {
        await driver.waitFor(find.byValueKey('registerButton'));
        await Future.delayed(const Duration(milliseconds: 500));
        await driver.tap(registerButtonFinder);
        await Future.delayed(const Duration(milliseconds: 500));
        await driver.tap(emailFieldFinder);
        await Future.delayed(const Duration(milliseconds: 500));
        await driver.enterText('integrationtest@email.com');
        await Future.delayed(const Duration(milliseconds: 500));
        await driver.tap(passwordFieldFinder);
        await Future.delayed(const Duration(milliseconds: 500));
        await driver.enterText('testpassword');
        await Future.delayed(const Duration(milliseconds: 500));
        final submitButtonFinder = find.byValueKey('registerSubmit');
        await Future.delayed(const Duration(milliseconds: 500));
        await driver.tap(submitButtonFinder);
        await Future.delayed(const Duration(seconds: 3));
      });

      // --- Login (After automatic redirection) ---
      final loginButtonFinder = find.byValueKey('loginButton');
      final loginEmailFieldFinder = find.ancestor(
          of: find.text('Email'),
          matching: find.byType('TextFormField')
      );
      final loginPasswordFieldFinder = find.ancestor(
          of: find.text('Password'),
          matching: find.byType('TextFormField')
      );
      await driver.runUnsynchronized(() async {
        await driver.tap(loginEmailFieldFinder);
        await Future.delayed(const Duration(milliseconds: 500));
        await driver.enterText('integrationtest@email.com');
        await Future.delayed(const Duration(milliseconds: 500));
        await driver.tap(loginPasswordFieldFinder);
        await Future.delayed(const Duration(milliseconds: 500));
        await driver.enterText('testpassword');
        await Future.delayed(const Duration(milliseconds: 500));
        await driver.tap(loginButtonFinder);
        await Future.delayed(const Duration(seconds: 5));
      });

      // --- Profile Completion (After login to dashboard page) ---
      final alertDialogTitleFinder = find.text('Complete Your Profile');
      final nameFieldFinder = find.byValueKey('nameField');
      final ageFieldFinder = find.byValueKey('ageField');

      // Find checkboxes
      final chineseCheckboxFinder = find.text('Chinese');
      final italianCheckboxFinder = find.text('Italian');

      final nextButtonFinder = find.text('Next');

      await driver.runUnsynchronized(() async {
        await driver.waitFor(alertDialogTitleFinder); // Wait for dialog
        await Future.delayed(const Duration(milliseconds: 500));

        await driver.tap(nameFieldFinder);
        await driver.enterText('Integration');
        await Future.delayed(const Duration(milliseconds: 500));

        await driver.tap(ageFieldFinder);
        await driver.enterText('25');
        await Future.delayed(const Duration(milliseconds: 500));

        // Select checkboxes
        await driver.tap(chineseCheckboxFinder);
        await Future.delayed(const Duration(milliseconds: 500));
        await driver.tap(italianCheckboxFinder);

        await Future.delayed(const Duration(milliseconds: 500));
        await driver.tap(nextButtonFinder);
        await Future.delayed(const Duration(seconds: 5));
        // ...
      });

    });
  });
}
