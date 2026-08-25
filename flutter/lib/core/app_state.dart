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

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await QuranText.ensureLoaded();
    } catch (_) {
      assetError = true;
    }
    onboarded = prefs.getBool('onboarded') ?? false;
    await Supabase.initialize(url: kSupabaseUrl, publishableKey: kAnonKey);
    await auth.init(Supabase.instance.client);
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
