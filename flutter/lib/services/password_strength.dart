import 'dart:convert';

import 'package:zxcvbnm/languages/common.dart' as common;
import 'package:zxcvbnm/languages/en/common_words.dart';
import 'package:zxcvbnm/languages/en/first_names.dart';
import 'package:zxcvbnm/zxcvbnm.dart';

/// NIST SP 800-63B length policy (8-64, no composition rules) + zxcvbn for the
/// actual estimate. zxcvbn catches what a hand-written blocklist can't:
/// `p4ssw0rd` reads as `password`, `qwerty123` as a keyboard walk.
const int kMinPasswordLength = 8;

/// Supabase hashes with bcrypt, which ignores everything past 72 **bytes** —
/// silently, so a longer password would appear to work and then let a
/// truncated prefix unlock the account. Counted in UTF-8 bytes because Arabic
/// costs about 1.8 bytes a character: an Arabic passphrase reaches the limit
/// around 40 characters, where an English one reaches it at 72.
const int kMaxPasswordBytes = 72;

/// zxcvbn's own reading: 3 is "safely unguessable". Move this one constant to
/// make sign-up more forgiving.
const int kMinAcceptableScore = 3;

/// Built once — loading dictionaries is the expensive part, and this runs on
/// every keystroke.
///
/// Deliberately not the full `languages/en.dart` set: its surname list alone is
/// 1.3MB of source and cost 2.1MB of web bundle, to catch English surnames that
/// aren't this learner's (their own name is passed in as a user input anyway).
/// Kept: the common-password list, the keyboard-adjacency graph, the l33t
/// table, diceware, English words and first names — the matchers that actually
/// fire on the passwords people choose.
final Zxcvbnm _zxcvbnm = Zxcvbnm(
  dictionaries: {...common.dictionaries, commonWords, firstNames},
);

class PasswordStrength {
  final int score; // 0-4, drives the meter
  final String label;
  final bool acceptable;
  final String? advice;

  /// Offline attacker at 10k guesses/second.
  final String? crackTime;

  const PasswordStrength({
    required this.score,
    required this.label,
    required this.acceptable,
    this.advice,
    this.crackTime,
  });

  static const _labels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'];

  /// Words every user of this app might reach for. zxcvbn's dictionaries have
  /// no idea what this product is called, so `bayaanapp123` scored 4 until
  /// these were passed in as user inputs.
  static const _appTerms = [
    'bayaan', 'bayan', 'bayaanapp', 'quran', 'koran', 'tajweed', 'tajwid',
    'recite', 'recitation', 'qari', 'mushaf', 'surah', 'ayah',
  ];

  /// zxcvbn matches user inputs as whole strings, so "Jade Ahmed" alone never
  /// catches "jadeahmed2026". Feed it the parts and the run-together form too.
  static List<String> _userInputs(String? email, String? name) {
    final out = <String>{..._appTerms};
    for (final raw in [email, name]) {
      final value = raw?.trim() ?? '';
      if (value.isEmpty) continue;
      out.add(value);
      out.addAll(value.split(RegExp(r'[\s@._-]+')).where((p) => p.isNotEmpty));
      out.add(value.replaceAll(RegExp(r'\s+'), ''));
    }
    return out.toList();
  }

  /// [email] and [name] are handed to zxcvbn as user inputs, so a password
  /// built out of them scores as the guessable thing it is.
  factory PasswordStrength.of(String password, {String? email, String? name}) {
    if (password.isEmpty) {
      return const PasswordStrength(
        score: 0,
        label: 'Too weak',
        acceptable: false,
      );
    }
    // Length is policy, not estimation: no score makes a 5-character password
    // acceptable, so don't bother computing one.
    if (password.length < kMinPasswordLength) {
      final missing = kMinPasswordLength - password.length;
      return PasswordStrength(
        score: 0,
        label: 'Too short',
        acceptable: false,
        advice: '$missing more character${missing == 1 ? '' : 's'} to go.',
      );
    }
    final bytes = utf8.encode(password).length;
    if (bytes > kMaxPasswordBytes) {
      return const PasswordStrength(
        score: 0,
        label: 'Too long',
        acceptable: false,
        advice: 'Past this length the sign-in server stops reading. Shorten it.',
      );
    }

    final result = _zxcvbnm(password, _userInputs(email, name));
    final score = result.score.clamp(0, 4);

    return PasswordStrength(
      score: score,
      label: _labels[score],
      acceptable: score >= kMinAcceptableScore,
      // zxcvbn's warning names the weakness, its suggestion says what to do.
      advice: score >= 4
          ? null
          : (result.feedback.warning ??
                (result.feedback.suggestions.isNotEmpty
                    ? result.feedback.suggestions.first
                    : 'Longer is stronger — a few words beats a short jumble.')),
      crackTime: result.crackTimesDisplay.offlineSlowHashing1e4PerSecond
          .toString(),
    );
  }
}
