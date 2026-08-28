import 'package:bayaan/services/password_strength.dart';
import 'package:flutter_test/flutter_test.dart';

PasswordStrength score(String p, {String? email, String? name}) =>
    PasswordStrength.of(p, email: email, name: name);

void main() {
  group('length policy (NIST SP 800-63B)', () {
    test('under 8 characters is never acceptable', () {
      for (final p in ['', 'a', 'Ab3!', 'Str0ng!']) {
        expect(score(p).acceptable, isFalse, reason: p);
      }
      expect(score('Str0ng!').advice, contains('1 more character'));
    });

    test('long passphrases are allowed, up to what bcrypt actually hashes', () {
      expect(score('correct horse battery staple').acceptable, isTrue);
      // 72 UTF-8 bytes is bcrypt's ceiling; beyond it Supabase silently drops
      // the tail, so a longer password must be refused rather than truncated.
      expect(score('lantern harbour cedar ' * 4).label, 'Too long');
      expect(score('a' * 72).label, isNot('Too long'));
      expect(score('a' * 73).label, 'Too long');
    });

    test('the limit counts bytes, so Arabic is measured honestly', () {
      // ~1.8 bytes a character: fine at 30, over the line well before 72.
      expect(score('لا إله إلا الله محمد رسول الله').label, isNot('Too long'));
      expect(score('لا إله إلا الله محمد رسول الله وصحبه أجمعين والحمد لله رب').label,
          'Too long');
    });
  });

  group('zxcvbn catches what a blocklist cannot', () {
    test('common passwords, however they are dressed up', () {
      for (final p in ['password', 'Password1!', 'p4ssw0rd', 'passwordpassword']) {
        expect(score(p).acceptable, isFalse, reason: p);
      }
    });

    test('keyboard walks, repeats and runs', () {
      for (final p in ['qwerty123', 'aaaaaaaa', 'abcdefgh', '87654321']) {
        expect(score(p).acceptable, isFalse, reason: p);
      }
    });

    test('name and email are not secrets', () {
      expect(score('jadeahmed2026', name: 'Jade Ahmed').acceptable, isFalse);
      expect(
        score('aalshaikh2026', email: 'aalshaikh@example.com').acceptable,
        isFalse,
      );
    });

    test('the app is not a secret either', () {
      // zxcvbn's dictionaries have never heard of this product, so these are
      // passed in as user inputs. bayaanapp123 scored 4 before that.
      for (final p in ['bayaanapp123', 'quran2026', 'tajweedpro']) {
        expect(score(p).acceptable, isFalse, reason: p);
      }
    });

    test('it explains the weakness rather than demanding symbols', () {
      final s = score('password');
      expect(s.advice, isNotNull);
      expect(s.advice!.toLowerCase(), contains('used password'));
    });
  });

  group('length beats composition', () {
    test('a lowercase passphrase outscores a short jumble', () {
      final phrase = score('lantern harbour cedar');
      final jumble = score('X7!q2a#z');
      expect(phrase.score, greaterThan(jumble.score));
      expect(phrase.score, 4);
      expect(phrase.acceptable, isTrue);
      // Composition is not what makes the jumble weak — length is.
      expect(jumble.acceptable, isFalse);
    });

    test('only a top score stops giving advice', () {
      expect(score('Bayaan2026!').advice, isNotNull);
      expect(score('lantern harbour cedar').advice, isNull);
    });

    test('an estimated crack time comes back for scored passwords', () {
      expect(score('lantern harbour cedar').crackTime, isNotNull);
      // Too short to be worth estimating.
      expect(score('abc').crackTime, isNull);
    });

    test('score stays inside the meter it drives', () {
      for (final p in ['', 'short', 'password', 'trellis9', 'a' * 40]) {
        expect(score(p).score, inInclusiveRange(0, 4));
      }
    });
  });
}
