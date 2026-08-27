import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../shared/widgets/ornamental_divider.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';
import '../../services/auth_controller.dart';

class SignInScreen extends StatefulWidget {
  final AuthController auth;
  const SignInScreen({super.key, required this.auth});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _logoAnim;
  late final Animation<double> _headerAnim;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _googleAnim;
  late final Animation<Offset> _googleSlide;
  late final Animation<double> _appleAnim;
  late final Animation<Offset> _appleSlide;
  late final Animation<double> _emailAnim;
  late final Animation<Offset> _emailSlide;
  late final Animation<double> _footerAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOutBack),
    );

    _headerAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.20, 0.50, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(_headerAnim);

    _googleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.68, curve: Curves.easeOut),
    );
    _googleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_googleAnim);

    _appleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.78, curve: Curves.easeOut),
    );
    _appleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_appleAnim);

    _emailAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 0.88, curve: Curves.easeOut),
    );
    _emailSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_emailAnim);

    _footerAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.80, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is coming soon — use email for now.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildLogo(),
            const SizedBox(height: 16),
            _buildHeader(),
            const Spacer(),
            _buildAuthButtons(),
            _buildFooter(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return FadeTransition(
      opacity: _logoAnim,
      child: ScaleTransition(
        scale: _logoAnim,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: 45 * 3.14159 / 180,
                child: Container(
                  width: 51,
                  height: 51,
                  decoration: BoxDecoration(
                    color: AppColors.tealStart,
                    border: Border.all(color: AppColors.gold, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Container(
                width: 51,
                height: 51,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealStart,
                  border: Border.all(color: AppColors.gold, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'ب',
                  textDirection: TextDirection.rtl,
                  style: arabic(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _headerAnim,
      child: SlideTransition(
        position: _headerSlide,
        child: Column(
          children: [
            Text(
              'Welcome to Bayaan',
              textAlign: TextAlign.center,
              style: pjs(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your patient Quran teacher, anytime.',
              textAlign: TextAlign.center,
              style: pjs(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthButtons() {
    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        final s = widget.auth.state;
        final loggedOut = s is LoggedOut ? s : const LoggedOut();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              if (loggedOut.error != null) ...[
                Text(
                  loggedOut.error!,
                  textAlign: TextAlign.center,
                  style: pjs(fontSize: 13, color: AppColors.tajweedError),
                ),
                const SizedBox(height: 12),
              ],
              FadeTransition(
                opacity: _googleAnim,
                child: SlideTransition(
                  position: _googleSlide,
                  child: _AuthButton(
                    label: loggedOut.submitting
                        ? 'Connecting...'
                        : 'Continue with Google',
                    backgroundColor: Colors.white,
                    textColor: AppColors.textDark,
                    borderColor: const Color(0xFFF5F1E6),
                    icon: loggedOut.submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Image.asset(
                            'assets/icons/google_logo.png',
                            width: 20,
                            height: 20,
                          ),
                    onTap: loggedOut.submitting
                        ? () {}
                        : () => widget.auth.signInWithGoogle(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
          FadeTransition(
            opacity: _appleAnim,
            child: SlideTransition(
              position: _appleSlide,
              child: _AuthButton(
                label: 'Continue with Apple',
                backgroundColor: AppColors.textDark,
                textColor: Colors.white,
                icon: const Icon(Icons.apple, size: 22, color: Colors.white),
                onTap: () => _comingSoon(context, 'Apple sign-in'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FadeTransition(
            opacity: _emailAnim,
            child: SlideTransition(
              position: _emailSlide,
              child: _AuthButton(
                label: 'Continue with Email',
                backgroundColor: AppColors.tealStart,
                textColor: Colors.white,
                icon: const Icon(
                  Icons.mail_outline,
                  size: 20,
                  color: Colors.white,
                ),
                onTap: () => context.push(AppRoutes.emailSignIn),
              ),
            ),
          ),
        ],
      ),
    );
  },
);
}

  Widget _buildFooter() {
    return FadeTransition(
      opacity: _footerAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          children: [
            const OrnamentalDivider(width: double.infinity, opacity: 0.3),
            const SizedBox(height: 12),
            Text(
              'By signing in, you agree to our Terms of Service and Privacy Policy. Private recitation feedback requires audio access.',
              textAlign: TextAlign.center,
              style: pjs(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final Widget icon;
  final VoidCallback onTap;

  const _AuthButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
            side: borderColor != null
                ? BorderSide(color: borderColor!)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: pjs(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
