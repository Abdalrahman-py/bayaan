import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../services/password_strength.dart';

/// Four segments that fill as the password gets stronger, with the label and
/// the one piece of advice crossfading underneath.
///
/// The animation is the point: a bar that slides and warms from red through
/// gold to green gives immediate, legible feedback while typing, which is what
/// actually moves people toward longer passwords. Reaching "Strong" gives the
/// row a small settle so the finish line is felt, not just read.
class PasswordMeter extends StatelessWidget {
  final PasswordStrength strength;

  /// Hidden entirely until the field has something in it, so an untouched
  /// form isn't already shouting "Too weak".
  final bool visible;

  const PasswordMeter({
    super.key,
    required this.strength,
    this.visible = true,
  });

  static const _segments = 4;

  Color get _color => switch (strength.score) {
    0 => AppColors.tajweedError,
    1 => AppColors.tajweedError,
    2 => AppColors.gold,
    3 => AppColors.tealStart,
    _ => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: List.generate(_segments, (i) {
                      // Each segment fills only once the score reaches it, and
                      // they animate in sequence rather than all at once.
                      final bool lit = strength.score > i;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == _segments - 1 ? 0 : 6),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: lit ? 1 : 0),
                            duration: Duration(milliseconds: 260 + i * 70),
                            curve: Curves.easeOutCubic,
                            builder: (context, t, _) => Stack(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE7D9),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: t,
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _color,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedScale(
                        // The little settle on reaching Strong.
                        scale: strength.score >= 4 ? 1 : 0.6,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          strength.acceptable
                              ? Icons.shield_rounded
                              : Icons.shield_outlined,
                          size: 15,
                          color: _color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            strength.advice == null
                                ? '${strength.label} — ${strength.crackTime} to crack'
                                : '${strength.label} — ${strength.advice}',
                            key: ValueKey('${strength.label}${strength.advice}'),
                            style: pjs(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: strength.acceptable
                                  ? AppColors.textMuted
                                  : _color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
