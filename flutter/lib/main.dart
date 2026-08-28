import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
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
    return MaterialApp.router(
      title: 'Bayaan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'PlusJakartaSans'),
      routerConfig: appRouter,
    );
  }
}
