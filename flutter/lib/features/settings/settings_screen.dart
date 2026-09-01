import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_palette.dart';
import '../../services/accounts_manager.dart';
import '../../services/app_settings.dart';
import '../../services/auth_controller.dart';
import '../../services/reciter_audio.dart';
import 'widgets/account_avatar.dart';
import 'widgets/account_switcher_sheet.dart';

/// Modern, comprehensive settings and profile management screen.
class SettingsScreen extends StatefulWidget {
  final AuthController auth;
  const SettingsScreen({super.key, required this.auth});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettings _settings = AppSettings.instance;
  final AccountsManager _accountsManager = AccountsManager.instance;

  @override
  void initState() {
    super.initState();
    _accountsManager.load().then((_) {
      if (mounted) {
        _accountsManager.syncWithAuth(
          displayName: widget.auth.displayName,
          email: widget.auth.email,
        );
      }
    });
  }

  String get _identity {
    final active = _accountsManager.activeAccount;
    if (active.name.isNotEmpty && active.name != 'Learner') return active.name;
    return widget.auth.displayName ?? widget.auth.email?.split('@').first ?? 'Learner';
  }

  String get _email {
    final active = _accountsManager.activeAccount;
    if (active.email.isNotEmpty) return active.email;
    return widget.auth.email ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([_settings, _accountsManager, widget.auth]),
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _buildHeader(palette),
                const SizedBox(height: 20),
                _buildProfileCard(palette),
                const SizedBox(height: 24),
                _buildSectionHeader('RECITATION & COACHING', palette),
                const SizedBox(height: 10),
                _buildCard(palette, [
                  _buildSelectorRow(
                    'Reference Reciter',
                    _settings.reciter.name,
                    palette,
                    onTap: () => _showReciterPicker(context, palette),
                  ),
                  _divider(palette),
                  _buildSelectorRow(
                    'Tajweed Sensitivity',
                    _settings.tajweedSensitivity,
                    palette,
                    onTap: () => _showSensitivityPicker(context, palette),
                  ),
                  _divider(palette),
                  _buildSelectorRow(
                    'Madd Length',
                    _settings.maddStyle.name,
                    palette,
                    subtitle: _settings.maddStyle.summary,
                    onTap: () => _showMaddPicker(context, palette),
                  ),
                  _divider(palette),
                  _buildSwitchRow(
                    'Auto-play Reference Audio',
                    'Play teacher audio on compare screen',
                    _settings.autoPlayReference,
                    _settings.setAutoPlayReference,
                    palette,
                  ),
                  _divider(palette),
                  _buildSwitchRow(
                    'Show Transliteration',
                    'Display phonetic spelling and meaning',
                    _settings.showTranslation,
                    _settings.setShowTranslation,
                    palette,
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionHeader('PRACTICE & REMINDERS', palette),
                const SizedBox(height: 10),
                _buildCard(palette, [
                  _buildSelectorRow(
                    'Daily Practice Goal',
                    '${_settings.dailyGoalMinutes} min/day',
                    palette,
                    onTap: () => _showGoalPicker(context, palette),
                  ),
                  _divider(palette),
                  _buildSwitchRow(
                    'Daily Practice Reminder',
                    'Receive a gentle daily notification',
                    _settings.dailyReminder,
                    _settings.setDailyReminder,
                    palette,
                  ),
                  if (_settings.dailyReminder) ...[
                    _divider(palette),
                    _buildSelectorRow(
                      'Reminder Time',
                      _settings.reminderTime,
                      palette,
                      onTap: () => _pickReminderTime(context, palette),
                    ),
                  ],
                  _divider(palette),
                  _buildSwitchRow(
                    'Streak Protection Alerts',
                    'Protect your recitation consistency',
                    _settings.streakAlerts,
                    _settings.setStreakAlerts,
                    palette,
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionHeader('PREFERENCES', palette),
                const SizedBox(height: 10),
                _buildCard(palette, [
                  _buildSelectorRow(
                    'App Language',
                    _settings.appLanguage == 'ar' ? 'العربية' : 'English',
                    palette,
                    onTap: () => _showLanguagePicker(context, palette),
                  ),
                  _divider(palette),
                  _buildSelectorRow(
                    'Appearance',
                    _themeModeLabel(_settings.themeMode),
                    palette,
                    onTap: () => _showAppearancePicker(context, palette),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionHeader('ABOUT & LEGAL', palette),
                const SizedBox(height: 10),
                _buildCard(palette, [
                  _buildLinkRow(
                    'About Bayaan',
                    palette,
                    onTap: () => _showAboutBayaanSheet(context, palette),
                  ),
                  _divider(palette),
                  _buildLinkRow(
                    'Privacy Policy',
                    palette,
                    onTap: () => _showPrivacyPolicySheet(context, palette),
                  ),
                  _divider(palette),
                  _buildLinkRow(
                    'Terms of Service',
                    palette,
                    onTap: () => _showTermsSheet(context, palette),
                  ),
                  _divider(palette),
                  _buildStaticRow('App Version', '1.1.0 (Build 2026.08)', palette),
                ]),
                const SizedBox(height: 32),
                _buildSignOutButton(palette),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: pjs(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Preferences and recitation customization',
                style: pjs(fontSize: 13, color: palette.textMuted),
              ),
            ],
          ),
        ),
        ExcludeSemantics(
          child: Text(
            'الإعدادات',
            textDirection: TextDirection.rtl,
            style: arabic(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(AppPalette palette) {
    final account = _accountsManager.activeAccount;
    final displayAccount = account.copyWith(name: _identity, email: _email);
    final accountsCount = _accountsManager.accounts.length;

    return Container(
      decoration: BoxDecoration(
        color: palette.cardBg,
        border: Border.all(color: palette.borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: 'Learner profile: $_identity, tap to edit profile',
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              onTap: () => context.push(AppRoutes.editProfile),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AccountAvatar(
                      account: displayAccount,
                      size: 52,
                      isDecorative: false,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _identity,
                            overflow: TextOverflow.ellipsis,
                            style: pjs(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          if (_email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _email,
                              overflow: TextOverflow.ellipsis,
                              style: pjs(fontSize: 12, color: palette.textMuted),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tealStart.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Active Learner',
                              style: pjs(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.tealStart,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: palette.textMuted),
                  ],
                ),
              ),
            ),
          ),
          _divider(palette),
          Semantics(
            button: true,
            label: 'Switch profile, $accountsCount ${accountsCount == 1 ? "profile" : "profiles"} registered',
            child: InkWell(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              onTap: () => showAccountSwitcherSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.tealStart),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Switch Profile',
                        style: pjs(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealStart,
                        ),
                      ),
                    ),
                    Text(
                      '$accountsCount ${accountsCount == 1 ? "profile" : "profiles"}',
                      style: pjs(fontSize: 12, color: palette.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppPalette palette) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: pjs(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: palette.textMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildCard(AppPalette palette, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.cardBg,
        border: Border.all(color: palette.borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider(AppPalette palette) =>
      Divider(height: 1, thickness: 1, color: palette.borderColor);

  Widget _buildSelectorRow(
    String label,
    String value,
    AppPalette palette, {
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: pjs(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: pjs(fontSize: 11, color: palette.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: pjs(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tealStart,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: palette.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    String subtitle,
    bool value,
    Future<void> Function(bool) onChanged,
    AppPalette palette,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: pjs(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: pjs(fontSize: 11, color: palette.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              activeTrackColor: AppColors.tealStart,
              onChanged: (v) {
                HapticFeedback.lightImpact();
                onChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkRow(String label, AppPalette palette, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: pjs(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: palette.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticRow(String label, String value, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: pjs(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
          ),
          Text(value, style: pjs(fontSize: 13, fontWeight: FontWeight.w500, color: palette.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSignOutButton(AppPalette palette) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => _confirmSignOut(context, palette),
        icon: const Icon(Icons.logout_rounded, size: 18),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.tajweedError,
          side: const BorderSide(color: AppColors.tajweedError, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
        label: Text(
          'Sign Out',
          style: pjs(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.tajweedError),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AppPalette palette) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out',
          style: pjs(fontSize: 18, fontWeight: FontWeight.bold, color: palette.textPrimary),
        ),
        content: Text(
          'Are you sure you want to sign out of Bayaan?',
          style: pjs(fontSize: 14, color: palette.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: pjs(fontWeight: FontWeight.w600, color: palette.textPrimary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.auth.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tajweedError,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Sign Out', style: pjs(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReciterPicker(BuildContext context, AppPalette palette) {
    _showListPicker<Reciter>(
      context,
      palette,
      title: 'Reference Reciter',
      options: Reciter.all,
      current: _settings.reciter,
      titleBuilder: (r) => r.name,
      subtitleBuilder: (r) => 'Murattal style pronunciation model',
      onSelect: _settings.setReciter,
    );
  }

  void _showSensitivityPicker(BuildContext context, AppPalette palette) {
    _showListPicker<String>(
      context,
      palette,
      title: 'Tajweed Sensitivity',
      options: const ['Relaxed', 'Balanced', 'Strict'],
      current: _settings.tajweedSensitivity,
      titleBuilder: (s) => s,
      subtitleBuilder: (s) => switch (s) {
        'Relaxed' => 'Lenient timing and forgiving vowel lengths for beginners',
        'Balanced' => 'Standard Hafs grading accuracy (Recommended)',
        'Strict' => 'Strict syllable-by-syllable adherence for advanced reciters',
        _ => '',
      },
      onSelect: _settings.setTajweedSensitivity,
    );
  }

  void _showMaddPicker(BuildContext context, AppPalette palette) {
    _showListPicker<MaddStyle>(
      context,
      palette,
      title: 'Tajweed Madd Length',
      options: MaddStyle.all,
      current: _settings.maddStyle,
      titleBuilder: (m) => m.name,
      subtitleBuilder: (m) => m.summary,
      onSelect: _settings.setMaddStyle,
    );
  }

  void _showGoalPicker(BuildContext context, AppPalette palette) {
    _showListPicker<int>(
      context,
      palette,
      title: 'Daily Practice Goal',
      options: const [10, 15, 30, 45, 60],
      current: _settings.dailyGoalMinutes,
      titleBuilder: (m) => '$m minutes per day',
      onSelect: _settings.setDailyGoalMinutes,
    );
  }

  void _showLanguagePicker(BuildContext context, AppPalette palette) {
    _showListPicker<String>(
      context,
      palette,
      title: 'App Language',
      options: const ['en', 'ar'],
      current: _settings.appLanguage,
      titleBuilder: (lang) => lang == 'ar' ? 'العربية (Arabic)' : 'English',
      onSelect: _settings.setAppLanguage,
    );
  }

  Future<void> _pickReminderTime(BuildContext context, AppPalette palette) async {
    final TimeOfDay initial = TimeOfDay(
      hour: _settings.reminderTime.contains('PM') ? 20 : 8,
      minute: 0,
    );
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.tealStart,
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null && mounted) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      _settings.setReminderTime('$hour:$minute $period');
    }
  }

  String _themeModeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System Default',
  };

  void _showAppearancePicker(BuildContext context, AppPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final current = _settings.themeMode;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: palette.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Appearance',
                  style: pjs(fontSize: 18, fontWeight: FontWeight.w800, color: palette.textPrimary),
                ),
                const SizedBox(height: 12),
                _buildAppearanceOption(context, palette, ThemeMode.light, 'Light', Icons.light_mode_outlined, current),
                _buildAppearanceOption(context, palette, ThemeMode.dark, 'Dark', Icons.dark_mode_outlined, current),
                _buildAppearanceOption(context, palette, ThemeMode.system, 'System Default', Icons.smartphone_outlined, current),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppearanceOption(
    BuildContext context,
    AppPalette palette,
    ThemeMode mode,
    String label,
    IconData icon,
    ThemeMode current,
  ) {
    final bool isSelected = mode == current;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        _settings.setThemeMode(mode);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.tealStart : palette.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: pjs(fontSize: 15, fontWeight: FontWeight.w600, color: palette.textPrimary),
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.tealStart, size: 20),
          ],
        ),
      ),
    );
  }

  void _showListPicker<T>(
    BuildContext context,
    AppPalette palette, {
    required String title,
    required List<T> options,
    required T current,
    required String Function(T) titleBuilder,
    String Function(T)? subtitleBuilder,
    required Future<void> Function(T) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: palette.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(title, style: pjs(fontSize: 18, fontWeight: FontWeight.w800, color: palette.textPrimary)),
                const SizedBox(height: 12),
                ...options.map((option) {
                  final bool isSelected = option == current;
                  final subtitle = subtitleBuilder?.call(option);
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(option);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titleBuilder(option),
                                  style: pjs(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                if (subtitle != null && subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(subtitle, style: pjs(fontSize: 12, color: palette.textMuted)),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected) const Icon(Icons.check_circle, color: AppColors.tealStart, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAboutBayaanSheet(BuildContext context, AppPalette palette) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: palette.borderColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('About Bayaan', style: pjs(fontSize: 20, fontWeight: FontWeight.w800, color: palette.textPrimary)),
              const SizedBox(height: 14),
              Text(
                'Bayaan is your patient, AI-powered Quran recitation coach designed to help Muslims improve their Tajweed and Quranic fluency anytime, anywhere.',
                style: pjs(fontSize: 14, height: 1.5, color: palette.textPrimary),
              ),
              const SizedBox(height: 16),
              Text('Key Architecture & Engine:', style: pjs(fontSize: 14, fontWeight: FontWeight.bold, color: palette.textPrimary)),
              const SizedBox(height: 8),
              _buildBullet('Speech Verification: High-precision phoneme alignment checking your voice against noble recitations.', palette),
              _buildBullet('Private & Direct: Instant feedback generated via serverless GPU inference without public storage of your audio recordings.', palette),
              _buildBullet('Tajweed Rules: Deep syllable-level detection of Madd durations, Ghunnah, Qalqalah, and letter articulation points.', palette),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicySheet(BuildContext context, AppPalette palette) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: palette.borderColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Privacy Policy', style: pjs(fontSize: 20, fontWeight: FontWeight.w800, color: palette.textPrimary)),
              const SizedBox(height: 14),
              Text(
                'Your recitation audio is processed strictly for the purpose of generating instant Tajweed feedback. We do not sell your personal audio recordings, and you retain complete control over your profiles and recitation history.',
                style: pjs(fontSize: 14, height: 1.5, color: palette.textPrimary),
              ),
              const SizedBox(height: 14),
              _buildBullet('Audio is encrypted in transit using TLS 1.3.', palette),
              _buildBullet('Recitation analysis is performed in stateless sessions.', palette),
              _buildBullet('You can delete individual learner profiles and history anytime.', palette),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsSheet(BuildContext context, AppPalette palette) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: palette.borderColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Terms of Service', style: pjs(fontSize: 20, fontWeight: FontWeight.w800, color: palette.textPrimary)),
              const SizedBox(height: 14),
              Text(
                'By using Bayaan, you agree to practice recitations in accordance with standard Quranic ethics. Bayaan is an educational learning aid and does not replace classical Sanad certification with certified Quran scholars.',
                style: pjs(fontSize: 14, height: 1.5, color: palette.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBullet(String text, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: pjs(color: AppColors.tealStart, fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, style: pjs(fontSize: 13, height: 1.4, color: palette.textPrimary)),
          ),
        ],
      ),
    );
  }
}


