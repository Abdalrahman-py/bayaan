import 'package:flutter/material.dart';

import 'core/router/app_router.dart';

void main() {
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
