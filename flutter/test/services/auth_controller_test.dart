import 'package:flutter_test/flutter_test.dart';
import 'package:bayaan/services/auth_controller.dart';

void main() {
  group('AuthController.friendly', () {
    final auth = AuthController();

    test('maps known Supabase error strings to friendly messages', () {
      expect(
        auth.friendly(StateError('Invalid login credentials'), 'fb'),
        'Incorrect email or password.',
      );
      expect(
        auth.friendly(StateError('Email not confirmed'), 'fb'),
        'Please confirm your email before logging in.',
      );
      expect(
        auth.friendly(StateError('User already registered'), 'fb'),
        'An account with this email already exists.',
      );
      expect(
        auth.friendly(StateError('Password should be at least 6 characters'), 'fb'),
        'Password is too weak (use at least 6 characters).',
      );
      expect(
        auth.friendly(StateError('Unable to validate email address'), 'fb'),
        'That email address looks invalid.',
      );
    });

    test('falls back for unknown errors', () {
      expect(auth.friendly(StateError('network down'), 'fb'), 'fb');
    });
  });
}
