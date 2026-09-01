import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bayaan/features/settings/edit_profile_screen.dart';
import 'package:bayaan/features/settings/add_account_screen.dart';
import 'package:bayaan/features/settings/widgets/account_switcher_sheet.dart';
import 'package:bayaan/services/accounts_manager.dart';
import 'package:bayaan/services/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthController extends AuthController {
  @override
  String? get email => 'parent@example.com';

  @override
  String? get displayName => 'Abdalrahman';
}

void main() {
  group('Profile & Account Screens', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AccountsManager.instance.load();
    });

    testWidgets('EditProfileScreen pre-fills auth name and shows account email', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final auth = _MockAuthController();

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(auth: auth),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('parent@example.com'), findsOneWidget);
      expect(find.text('Account Email'), findsOneWidget);
      expect(find.text('Abdalrahman'), findsOneWidget);

      // Edit the name
      await tester.enterText(find.byType(TextFormField), 'Sara');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(AccountsManager.instance.activeAccount.name, 'Sara');
    });

    testWidgets('AddAccountScreen creates a new learner profile', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AddAccountScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Learner Profile'), findsWidgets);

      await tester.enterText(find.byType(TextFormField), 'Zayd');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Learner Profile'));
      await tester.pumpAndSettle();

      expect(AccountsManager.instance.activeAccount.name, 'Zayd');
      expect(AccountsManager.instance.accounts.length, 2);
    });

    testWidgets('showAccountSwitcherSheet switches active learner profile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      AccountsManager.instance.addAccount(name: 'Profile 1');
      AccountsManager.instance.addAccount(name: 'Profile 2');

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showAccountSwitcherSheet(context),
                child: const Text('Open Switcher'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Switcher'));
      await tester.pumpAndSettle();

      expect(find.text('Switch Learner Profile'), findsOneWidget);
      expect(find.text('Profile 1'), findsOneWidget);
      expect(find.text('Profile 2'), findsOneWidget);

      await tester.tap(find.text('Profile 1'));
      await tester.pumpAndSettle();

      expect(AccountsManager.instance.activeAccount.name, 'Profile 1');
    });
  });
}
