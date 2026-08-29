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

  final AuthController auth;
  final RecitationController recitation = RecitationController();

  AppState({AuthController? auth}) : auth = auth ?? AuthController() {
    this.auth.addListener(notifyListeners);
  }

  bool _bootstrapped = false;

  /// No artificial floor: the native launch screen is the branding, and the
  /// splash route just holds its colour, so there is no animation left to wait
  /// for. Kept as a parameter because a test still needs to gate on it.
  Future<void> bootstrap({Duration minSplash = Duration.zero}) async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    final floor = Future<void>.delayed(minSplash);
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
    await floor;
    booting = false;
    notifyListeners();
  }

  /// Re-runs a boot that failed on assets. Clears the failure first so the
  /// splash drops back to its plain colour while the retry is in flight.
  Future<void> retryBootstrap() {
    _bootstrapped = false;
    assetError = false;
    booting = true;
    notifyListeners();
    return bootstrap();
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
