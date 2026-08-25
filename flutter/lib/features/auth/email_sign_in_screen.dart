import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../services/auth_controller.dart';

/// Email/password form — the one auth path actually wired to Supabase.
/// Reached from SignInScreen's "Continue with Email" button.
class EmailSignInScreen extends StatefulWidget {
  final AuthController auth;
  const EmailSignInScreen({super.key, required this.auth});

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go(AppRoutes.signIn),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFF5F1E6)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_left,
                            size: 20,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _signUp ? 'Create your account' : 'Welcome back',
                    style: pjs(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: pjs(fontSize: 15, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFF5F1E6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    style: pjs(fontSize: 15, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFF5F1E6)),
                      ),
                    ),
                  ),
                  if (loggedOut.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      loggedOut.error!,
                      style: pjs(fontSize: 13, color: AppColors.tajweedError),
                    ),
                  ],
                  if (loggedOut.pendingConfirmation) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Check your email to confirm your account.',
                      style: pjs(fontSize: 13, color: AppColors.tealStart),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: loggedOut.submitting
                          ? null
                          : () => _signUp
                                ? widget.auth.signup(
                                    _email.text.trim(),
                                    _password.text,
                                  )
                                : widget.auth.login(
                                    _email.text.trim(),
                                    _password.text,
                                  ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealStart,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: loggedOut.submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _signUp ? 'Sign Up' : 'Log In',
                              style: pjs(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _signUp = !_signUp),
                    child: Text(
                      _signUp
                          ? 'Already have an account? Log in'
                          : "Don't have an account? Sign up",
                      style: pjs(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
