import 'package:flutter/material.dart';

import 'settings_screen.dart';

void main() {
  runApp(const BayaanApp());
}

class BayaanApp extends StatelessWidget {
  const BayaanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bayaan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        scaffoldBackgroundColor: const Color(0xFFFAF8F2),
      ),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
      home: const SettingsScreen(),
    );
  }
}
