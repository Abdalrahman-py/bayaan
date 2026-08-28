import 'package:bayaan/features/auth/email_sign_in_screen.dart';
import 'package:bayaan/services/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth extends AuthController {
  String? signedUpEmail;
  String? signedUpName;
  int loginCalls = 0;

  @override
  AuthUiState get state => const LoggedOut();

  @override
  Future<void> signup(String email, String password, {String? name}) async {
    signedUpEmail = email;
    signedUpName = name;
  }

  @override
  Future<void> login(String email, String password) async {
    loginCalls++;
  }
}

Future<void> pump(WidgetTester tester, AuthController auth) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(home: EmailSignInScreen(auth: auth)));
  await tester.pumpAndSettle();
}

Future<void> switchToSignUp(WidgetTester tester) async {
  await tester.tap(find.text('Sign up'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('log in asks for email and password only', (tester) async {
    await pump(tester, _FakeAuth());
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Your name'), findsNothing);
  });

  testWidgets('sign up adds the name field', (tester) async {
    await pump(tester, _FakeAuth());
    await switchToSignUp(tester);
    expect(find.widgetWithText(TextField, 'Your name'), findsOneWidget);
  });

  testWidgets('a weak password never reaches the network', (tester) async {
    final auth = _FakeAuth();
    await pump(tester, auth);
    await switchToSignUp(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Jade');
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'jade@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(auth.signedUpEmail, isNull, reason: 'blocklisted password');
    expect(find.text('Too weak'), findsWidgets);
  });

  testWidgets('a missing name blocks sign up', (tester) async {
    final auth = _FakeAuth();
    await pump(tester, auth);
    await switchToSignUp(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'jade@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'lantern harbour cedar',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(auth.signedUpEmail, isNull);
    expect(find.text('Tell us what to call you.'), findsOneWidget);
  });

  testWidgets('a good sign up passes the name through', (tester) async {
    final auth = _FakeAuth();
    await pump(tester, auth);
    await switchToSignUp(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Your name'),
      '  Jade Ahmed  ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      ' jade@example.com ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'lantern harbour cedar',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(auth.signedUpEmail, 'jade@example.com');
    expect(auth.signedUpName, 'Jade Ahmed');
  });

  testWidgets('log in is not held to the sign-up password rules',
      (tester) async {
    final auth = _FakeAuth();
    await pump(tester, auth);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'jade@example.com',
    );
    // An old account whose password predates the current rules must still
    // be able to sign in.
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'abc123');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(auth.loginCalls, 1);
  });

  testWidgets('sign up carries the terms notice, log in does not',
      (tester) async {
    await pump(tester, _FakeAuth());
    expect(find.textContaining('Terms of Service'), findsNothing);
    await switchToSignUp(tester);
    expect(
      find.textContaining('you agree to our Terms of Service and Privacy Policy'),
      findsOneWidget,
    );
  });

  testWidgets('switching tabs keeps the email but drops the password',
      (tester) async {
    await pump(tester, _FakeAuth());
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'jade@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'lantern harbour cedar',
    );
    await tester.pumpAndSettle();

    await switchToSignUp(tester);

    expect(find.text('jade@example.com'), findsOneWidget);
    expect(find.text('lantern harbour cedar'), findsNothing);
  });

  testWidgets('a malformed email is caught before submitting', (tester) async {
    final auth = _FakeAuth();
    await pump(tester, auth);
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'not-an-email',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'abc123');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(auth.loginCalls, 0);
    expect(find.text("That doesn't look like an email address."), findsOneWidget);
  });
}
