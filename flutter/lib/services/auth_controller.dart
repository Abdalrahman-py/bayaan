import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ported from android AuthViewModel: same state shape and the same
/// friendly-error mapping. Session persistence/refresh is handled by
/// supabase_flutter's Auth (equivalent of jan-transport on Android).
sealed class AuthUiState {
  const AuthUiState();
}

class Checking extends AuthUiState {
  const Checking();
}

class LoggedOut extends AuthUiState {
  final String? error;
  final bool pendingConfirmation;
  final bool submitting;
  const LoggedOut({
    this.error,
    this.pendingConfirmation = false,
    this.submitting = false,
  });
}

class LoggedIn extends AuthUiState {
  const LoggedIn();
}

class AuthController extends ChangeNotifier {
  AuthUiState _state = const Checking();
  AuthUiState get state => _state;

  late final SupabaseClient _client;
  StreamSubscription<AuthState>? _sub;

  Future<void> init(SupabaseClient client) async {
    _client = client;
    // Await the SDK's restored-session read ONCE before subscribing. This is
    // the anti-flash guarantee: the first state we publish is already final —
    // a logged-in user never sees the login screen, even for a frame.
    try {
      client.auth.currentSession; // warm the SDK (may be null)
    } catch (_) {}
    if (_disposed) return;
    final session = client.auth.currentSession;
    _state = session != null ? const LoggedIn() : const LoggedOut();

    _sub = client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.initialSession:
          if (data.session != null) _set(const LoggedIn());
        case AuthChangeEvent.signedOut:
          _set(const LoggedOut());
        default:
          break;
      }
    });
    notifyListeners();
  }

  String? get accessToken => _client.auth.currentSession?.accessToken;
  String? get email => _client.auth.currentUser?.email;

  Future<void> login(String email, String password) async {
    _set(const LoggedOut(submitting: true));
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      // listener flips to LoggedIn
    } catch (e) {
      _set(LoggedOut(error: friendly(e, "Couldn't log in. Please try again.")));
    }
  }

  /// Where Google sends the user back to. The `bayaan://` scheme only works
  /// where the OS can route it to the app; a browser cannot follow it, so on
  /// web we let supabase_flutter fall back to the page's own origin.
  static String? get oauthRedirect =>
      kIsWeb ? null : 'bayaan://login-callback';

  Future<void> signInWithGoogle() async {
    _set(const LoggedOut(submitting: true));
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: oauthRedirect,
      );
      // listener flips to LoggedIn upon deep link callback
    } catch (e) {
      _set(
        LoggedOut(
          error: friendly(e, "Couldn't sign in with Google. Please try again."),
        ),
      );
    }
  }

  Future<void> signup(String email, String password) async {
    _set(const LoggedOut(submitting: true));
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      if (res.session == null) {
        _set(const LoggedOut(pendingConfirmation: true));
      }
      // else listener flips to LoggedIn
    } catch (e) {
      _set(
        LoggedOut(error: friendly(e, "Couldn't sign up. Please try again.")),
      );
    }
  }

  Future<void> signOut() async {
    _state = const LoggedOut(); // flip first — same anti-bounce as Android
    notifyListeners();
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }

  void _set(AuthUiState s) {
    if (_disposed) return;
    _state = s;
    notifyListeners();
  }

  bool _disposed = false;

  String friendly(Object e, String fallback) {
    final raw = e.toString();
    if (raw.contains('Invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('Email not confirmed')) {
      return 'Please confirm your email before logging in.';
    }
    if (raw.contains('User already registered')) {
      return 'An account with this email already exists.';
    }
    if (raw.contains('Password should be')) {
      return 'Password is too weak (use at least 6 characters).';
    }
    if (raw.contains('Unable to validate email')) {
      return 'That email address looks invalid.';
    }
    return fallback;
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
