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

/// Comprehensive settings, preferences, and account management screen.
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
    _accountsManager.load();
  }

  String get _identity {
    final active = _accountsManager.activeAccount;
    if (active.name.isNotEmpty && active.name != 'Learner') return active.name;
    return widget.auth.displayName ?? widget.auth.email ?? 'Learner';
  }

  String get _email {
    final active = _accountsManager.activeAccount;
    if (active.email.isNotEmpty) return active.email;
    return widget.auth.email ?? 'learner@bayaan.app';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([_settings, _accountsManager]),
                builder: (context, _) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      _buildHeader(palette),
                      const SizedBox(height: 20),
                      _buildProfileCard(palette),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Recitation & Audio',
                        Icons.record_voice_over_rounded,
                        palette,
                      ),
                      _buildRecitationSection(palette),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Mushaf & Display',
                        Icons.menu_book_rounded,
                        palette,
                      ),
                      _buildMushafSection(palette),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Practice Goal',
                        Icons.flag_outlined,
                        palette,
                      ),
                      _buildPracticeGoalSection(palette),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Reminders & Alerts',
                        Icons.notifications_active_outlined,
                        palette,
                      ),
                      _buildRemindersSection(palette),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'About & Support',
                        Icons.info_outline_rounded,
                        palette,
                      ),
                      _buildAboutSection(palette),
                      const SizedBox(height: 32),
                      _buildSignOutButton(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
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
        Text(
          'الإعدادات',
          textDirection: TextDirection.rtl,
          style: arabic(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(AppPalette palette) {
    final account = _accountsManager.activeAccount;
    final displayAccount = (account.name == 'Learner' && widget.auth.email != null)
        ? account.copyWith(name: _identity, email: _email)
        : account;
    final accountsCount = _accountsManager.accounts.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        border: Border.all(color: palette.borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.push(AppRoutes.editProfile),
            child: Row(
              children: [
                AccountAvatar(account: displayAccount, size: 50),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _identity,
                        overflow: TextOverflow.ellipsis,
                        style: pjs(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _identity == _email ? 'Bayaan Reciter' : _email,
                        overflow: TextOverflow.ellipsis,
                        style: pjs(fontSize: 12, color: palette.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tealStart.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Bayaan Reciter · Active',
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
          Divider(height: 20, color: palette.borderColor),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => showAccountSwitcherSheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.swap_horiz_rounded,
                    size: 20,
                    color: AppColors.tealStart,
                  ),
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
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.tealStart),
          const SizedBox(width: 8),
          Text(
            title,
            style: pjs(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(AppPalette palette, List<Widget> children) => DecoratedBox(
    decoration: BoxDecoration(
      color: palette.cardBg,
      border: Border.all(color: palette.borderColor),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: children),
  );

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
    required AppPalette palette,
  }) => SwitchListTile(
    title: Text(
      title,
      style: pjs(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: pjs(fontSize: 11, color: palette.textMuted),
    ),
    value: value,
    activeTrackColor: AppColors.tealStart,
    onChanged: (v) {
      onChanged(v);
    },
  );

  Widget _buildRecitationSection(AppPalette palette) {
    return _card(palette, [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reference Reciter',
              style: pjs(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<Reciter>(
              initialValue: _settings.reciter,
              dropdownColor: palette.cardBg,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: palette.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: palette.borderColor),
                ),
              ),
              items: [
                for (final r in Reciter.all)
                  DropdownMenuItem(
                    value: r,
                    child: Text(
                      r.name,
                      style: pjs(color: palette.textPrimary),
                    ),
                  ),
              ],
              onChanged: (r) {
                if (r == null) return;
                _settings.setReciter(r);
              },
            ),
          ],
        ),
      ),
      Divider(height: 1, color: palette.borderColor),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Madd Length',
              style: pjs(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'How long the coach expects you to hold a madd. '
              '${_settings.maddStyle.summary}.',
              style: pjs(fontSize: 11, color: palette.textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: MaddStyle.all.map((style) {
                final bool isSelected = _settings.maddStyle.id == style.id;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        _settings.setMaddStyle(style);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.tealStart
                              : palette.borderColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          style.name,
                          style: pjs(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : palette.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      Divider(height: 1, color: palette.borderColor),
      _switchTile(
        title: 'Auto-play reference audio',
        subtitle: 'Play the qari automatically on the compare screen',
        value: _settings.autoPlayReference,
        onChanged: _settings.setAutoPlayReference,
        palette: palette,
      ),
    ]);
  }

  Widget _buildMushafSection(AppPalette palette) {
    return _card(palette, [
      _switchTile(
        title: 'Show transliteration & translation',
        subtitle: 'Display "How to say it" card on recitation screen',
        value: _settings.showTranslation,
        onChanged: _settings.setShowTranslation,
        palette: palette,
      ),
      Divider(height: 1, color: palette.borderColor),
      InkWell(
        onTap: () => _showAppearancePicker(context, palette),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme & Appearance',
                    style: pjs(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    'Choose between Light, Dark, or System mode',
                    style: pjs(fontSize: 11, color: palette.textMuted),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    _themeModeLabel(_settings.themeMode),
                    style: pjs(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tealStart,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: palette.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _buildPracticeGoalSection(AppPalette palette) {
    return _card(palette, [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Goal',
              style: pjs(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'How long you aim to practice each day. Shown on your stats.',
              style: pjs(fontSize: 11, color: palette.textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [15, 30, 45, 60].map((mins) {
                final isSelected = _settings.dailyGoalMinutes == mins;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => _settings.setDailyGoalMinutes(mins),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.tealStart
                              : palette.borderColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$mins min',
                          style: pjs(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : palette.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildRemindersSection(AppPalette palette) {
    return _card(palette, [
      _switchTile(
        title: 'Daily Practice Reminder',
        subtitle: 'Receive a reminder at ${_settings.reminderTime}',
        value: _settings.dailyReminder,
        onChanged: _settings.setDailyReminder,
        palette: palette,
      ),
      Divider(height: 1, color: palette.borderColor),
      _switchTile(
        title: 'Streak Alerts',
        subtitle: 'Alerts to protect your daily recitation streak',
        value: _settings.streakAlerts,
        onChanged: _settings.setStreakAlerts,
        palette: palette,
      ),
    ]);
  }

  Widget _buildAboutSection(AppPalette palette) {
    return _card(palette, [
      ListTile(
        title: Text(
          'App Version',
          style: pjs(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
        trailing: Text(
          '1.1.0 (Build 2026.08)',
          style: pjs(fontSize: 12, color: palette.textMuted),
        ),
      ),
      Divider(height: 1, color: palette.borderColor),
      ListTile(
        title: Text(
          'Tajweed Analysis Engine',
          style: pjs(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
        trailing: Text(
          'Modal GPU Serverless',
          style: pjs(
            fontSize: 12,
            color: AppColors.tealStart,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ]);
  }

  String _themeModeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };

  void _showAppearancePicker(BuildContext context, AppPalette palette) {
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
                Text(
                  'Appearance',
                  style: pjs(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildAppearanceOption(
                  context,
                  palette,
                  ThemeMode.light,
                  'Light',
                  Icons.light_mode_outlined,
                ),
                _buildAppearanceOption(
                  context,
                  palette,
                  ThemeMode.dark,
                  'Dark',
                  Icons.dark_mode_outlined,
                ),
                _buildAppearanceOption(
                  context,
                  palette,
                  ThemeMode.system,
                  'System default',
                  Icons.smartphone_outlined,
                ),
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
  ) {
    final bool isSelected = mode == _settings.themeMode;
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
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.tealStart : palette.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: pjs(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.tealStart,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => _confirmSignOut(context),
        icon: const Icon(Icons.logout_rounded, size: 18),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.tajweedError,
          side: const BorderSide(color: AppColors.tajweedError, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        label: Text(
          'Sign Out',
          style: pjs(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.tajweedError,
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    final palette = AppPalette.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out',
          style: pjs(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: palette.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of Bayaan?',
          style: pjs(fontSize: 14, color: palette.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: pjs(
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Sign Out',
              style: pjs(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
