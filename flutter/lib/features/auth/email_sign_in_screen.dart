import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../services/auth_controller.dart';
import '../../services/password_strength.dart';
import '../../shared/widgets/ornamental_divider.dart';
import 'widgets/password_meter.dart';

/// Email/password form — the one auth path actually wired to Supabase.
/// Reached from SignInScreen's "Continue with Email" button.
class EmailSignInScreen extends StatefulWidget {
  final AuthController auth;
  const EmailSignInScreen({super.key, required this.auth});

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen>
    with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  late final AnimationController _entry;
  bool _signUp = false;
  bool _obscure = true;

  /// Set when submit is pressed, so validation errors appear on a considered
  /// action rather than scolding someone mid-typing.
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    // The meter and the button's enabled state both track what's typed.
    for (final c in [_name, _email, _password]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    _entry.dispose();
    super.dispose();
  }

  PasswordStrength get _strength => PasswordStrength.of(
    _password.text,
    email: _email.text,
    name: _name.text,
  );

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? get _nameError => (_signUp && _name.text.trim().isEmpty)
      ? 'Tell us what to call you.'
      : null;

  String? get _emailError => _emailRe.hasMatch(_email.text.trim())
      ? null
      : "That doesn't look like an email address.";

  /// Log-in only checks that something was typed: an existing password set
  /// under older rules must still work.
  String? get _passwordError => _signUp
      ? (_strength.acceptable ? null : _strength.label)
      : (_password.text.isEmpty ? 'Enter your password.' : null);

  bool get _canSubmit =>
      _nameError == null && _emailError == null && _passwordError == null;

  void _submit() {
    setState(() => _showErrors = true);
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    if (_signUp) {
      widget.auth.signup(
        _email.text.trim(),
        _password.text,
        name: _name.text.trim(),
      );
    } else {
      widget.auth.login(_email.text.trim(), _password.text);
    }
  }

  /// One short fade-and-rise for the whole form. Six staggered steps read as
  /// the screen assembling itself in pieces, which is the "clunky" part —
  /// a form is one object, so it arrives as one.
  Widget _entrance(Widget child) => FadeTransition(
    opacity: _entry,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut)),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.auth,
          builder: (context, _) {
            final s = widget.auth.state;
            final loggedOut = s is LoggedOut ? s : const LoggedOut();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: _entrance(
                Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBackButton(),
                  const SizedBox(height: 16),
                  _buildCrest(),
                  const SizedBox(height: 18),
                  _buildTitle(),
                  const SizedBox(height: 20),
                  _buildModeSwitch(),
                  const SizedBox(height: 20),
                  _buildForm(),
                  if (loggedOut.error != null) ...[
                    const SizedBox(height: 14),
                    _buildNotice(
                      loggedOut.error!,
                      AppColors.tajweedError,
                      Icons.error_outline_rounded,
                    ),
                  ],
                  if (loggedOut.pendingConfirmation) ...[
                    const SizedBox(height: 14),
                    _buildNotice(
                      'Check your email to confirm your account.',
                      AppColors.tealStart,
                      Icons.mark_email_read_outlined,
                    ),
                  ],
                  const SizedBox(height: 22),
                  _buildSubmit(loggedOut.submitting),
                  const SizedBox(height: 16),
                  _buildFooter(),
                ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackButton() => Align(
    alignment: Alignment.centerLeft,
    child: GestureDetector(
      onTap: () =>
          context.canPop() ? context.pop() : context.go(AppRoutes.signIn),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFF5F1E6)),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.chevron_left, size: 20, color: AppColors.textDark),
      ),
    ),
  );

  /// The rotated-diamond mark from the sign-in screen, so the two screens read
  /// as one flow rather than a form bolted onto a branded page.
  Widget _buildCrest() => Center(
    child: SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 45 * 3.14159 / 180,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.splashGradient,
                border: Border.all(color: AppColors.gold, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Text(
            'ب',
            textDirection: TextDirection.rtl,
            style: arabic(fontSize: 22, color: Colors.white),
          ),
        ],
      ),
    ),
  );

  Widget _buildTitle() => Column(
    children: [
      Text(
        _signUp ? 'Create your account' : 'Welcome back',
        textAlign: TextAlign.center,
        style: pjs(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _signUp
            ? 'A few details and your recitation practice is saved from here on.'
            : 'Your streak, your levels, and every ayah you have recited.',
        textAlign: TextAlign.center,
        style: pjs(fontSize: 13, height: 1.5, color: AppColors.textMuted),
      ),
      const SizedBox(height: 14),
      const OrnamentalDivider(width: 180, opacity: 0.35),
    ],
  );

  /// A sliding two-up switch instead of the old text link — the choice between
  /// signing in and signing up is the first thing to make obvious.
  Widget _buildModeSwitch() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFF1ECE0),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Row(
      children: [
        _modeTab('Log in', !_signUp),
        _modeTab('Sign up', _signUp),
      ],
    ),
  );

  Widget _modeTab(String label, bool selected) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() {
        _signUp = label == 'Sign up';
        _showErrors = false;
        // The email is worth keeping across the switch; the password is not —
        // a log-in password carried into sign-up gets scored and shown a
        // strength verdict it was never meant for.
        _password.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: pjs(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.tealStart : AppColors.textMuted,
          ),
        ),
      ),
    ),
  );

  Widget _buildForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // AnimatedSize keeps the name field from popping the layout when the
      // mode switches.
      AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: _signUp
            ? Column(
                children: [
                  _field(
                    controller: _name,
                    hint: 'Your name',
                    icon: Icons.person_outline_rounded,
                    error: _showErrors ? _nameError : null,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                ],
              )
            : const SizedBox(width: double.infinity),
      ),
      _field(
        controller: _email,
        hint: 'Email',
        icon: Icons.alternate_email_rounded,
        keyboardType: TextInputType.emailAddress,
        error: _showErrors ? _emailError : null,
      ),
      const SizedBox(height: 12),
      _field(
        controller: _password,
        hint: 'Password',
        icon: Icons.lock_outline_rounded,
        obscure: _obscure,
        focusNode: _passwordFocus,
        onSubmitted: (_) => _submit(),
        // A wrong password on log-in is the server's verdict, not ours, so the
        // inline error only fires for an empty field.
        error: _showErrors ? _passwordError : null,
        trailing: GestureDetector(
          onTap: () => setState(() => _obscure = !_obscure),
          child: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
            color: AppColors.textMuted,
          ),
        ),
      ),
      if (_signUp)
        PasswordMeter(
          strength: _strength,
          visible: _password.text.isNotEmpty,
        ),
    ],
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? error,
    bool obscure = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    FocusNode? focusNode,
    Widget? trailing,
    void Function(String)? onSubmitted,
  }) {
    final bad = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          onSubmitted: onSubmitted,
          style: pjs(fontSize: 15, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: pjs(fontSize: 15, color: AppColors.textMuted),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: bad ? AppColors.tajweedError : AppColors.textMuted,
            ),
            suffixIcon: trailing == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: trailing,
                  ),
            suffixIconConstraints: const BoxConstraints(minWidth: 0),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: _border(const Color(0xFFF5F1E6)),
            enabledBorder: _border(
              bad ? AppColors.tajweedError : const Color(0xFFF5F1E6),
            ),
            focusedBorder: _border(
              bad ? AppColors.tajweedError : AppColors.tealStart,
              width: 1.6,
            ),
          ),
        ),
        if (bad)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 6),
            child: Text(
              error,
              style: pjs(fontSize: 12, color: AppColors.tajweedError),
            ),
          ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  Widget _buildNotice(String message, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: pjs(fontSize: 13, height: 1.4, color: AppColors.textDark),
          ),
        ),
      ],
    ),
  );

  Widget _buildSubmit(bool submitting) => SizedBox(
    height: 52,
    child: ElevatedButton(
      onPressed: submitting ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.tealStart,
        disabledBackgroundColor: AppColors.tealStart.withValues(alpha: 0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      child: submitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              _signUp ? 'Create account' : 'Log in',
              style: pjs(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    ),
  );

  Widget _buildFooter() => Text(
    // Same wording as SignInScreen's footer, which carries this notice for the
    // social buttons. ponytail: plain text, because there is nothing to link
    // to yet — a privacy policy is still unwritten (GRADUATION_REPORT.md:490).
    // Make these real links before release; an agreement notice pointing at
    // nothing is worse than none.
    _signUp
        ? 'By creating an account, you agree to our Terms of Service and Privacy Policy.'
        : 'Signing in keeps your progress on every device you use.',
    textAlign: TextAlign.center,
    style: pjs(fontSize: 12, height: 1.5, color: AppColors.textMuted),
  );
}
