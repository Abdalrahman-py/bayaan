import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bayaan/core/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Supabase starts app_links, whose platform channels do not exist under
    // flutter_test; silence them so the boot sequence itself is what we test.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('com.llfbandit.app_links/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.app_links/messages'),
      (_) async => null,
    );
  });

  testWidgets('bootstrap holds booting for at least the splash window', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final quick = AppState();
      addTearDown(quick.dispose);
      final control = Stopwatch()..start();
      await quick.bootstrap(minSplash: Duration.zero);
      control.stop();

      final held = AppState();
      addTearDown(held.dispose);
      final gated = Stopwatch()..start();
      await held.bootstrap(minSplash: const Duration(milliseconds: 900));
      gated.stop();

      expect(quick.booting, isFalse);
      expect(held.booting, isFalse);
      expect(control.elapsedMilliseconds, lessThan(900));
      expect(gated.elapsedMilliseconds, greaterThanOrEqualTo(900));
    });
  });
}
