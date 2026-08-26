import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_controller.dart';
import '../services/quran_text.dart';
import '../services/recitation_controller.dart';

/// App-wide boot/auth/onboarding state, driving GoRouter's redirect logic.
/// One instance for the app's lifetime — same role the old imperative
/// _RootState used to play, just declarative now.
class AppState extends ChangeNotifier {
  bool booting = true;
  bool assetError = false;
  bool onboarded = false;

  final AuthController auth = AuthController();
  final RecitationController recitation = RecitationController();

  AppState() {
    auth.addListener(notifyListeners);
  }

  bool _bootstrapped = false;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    final prefs = await SharedPreferences.getInstance();
    try {
      await QuranText.ensureLoaded();
    } catch (_) {
      assetError = true;
    }
    onboarded = prefs.getBool('onboarded') ?? false;
    try {
      await Supabase.initialize(url: kSupabaseUrl, publishableKey: kAnonKey);
    } catch (_) {
      // Supabase already initialized or test environment
    }
    try {
      await auth.init(Supabase.instance.client);
    } catch (_) {}
    booting = false;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    onboarded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    auth.dispose();
    recitation.dispose();
    super.dispose();
  }
}

final appState = AppState();
