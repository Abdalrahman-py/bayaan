import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Settings are read synchronously all over the app, so load them before the
  // first frame rather than making every screen handle a null preference.
  await AppSettings.instance.load();
  runApp(const BayaanApp());
}

class BayaanApp extends StatelessWidget {
  const BayaanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Bayaan',
          debugShowCheckedModeBanner: false,
          themeMode: AppSettings.instance.themeMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: appRouter,
        );
      },
    );
  }
}

