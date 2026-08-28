import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../services/auth_controller.dart';
import '../../services/reciter_audio.dart';

/// Comprehensive settings, preferences, and account management screen.
class SettingsScreen extends StatefulWidget {
  final AuthController auth;
  const SettingsScreen({super.key, required this.auth});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Reciter _reciter = Reciter.fallback;

  @override
  void initState() {
    super.initState();
    Reciter.selected().then((r) {
      if (mounted) setState(() => _reciter = r);
    });
  }

  String _tajweedSensitivity = 'Standard';
  bool _autoPlayReference = true;
  bool _showTajweedColors = true;
  bool _showTransliteration = true;
  bool _dailyReminder = true;
  bool _soundEffects = true;
  int _dailyGoalMinutes = 10;

  String? get _userEmail => widget.auth.email;
  String get _avatarInitial =>
      (_userEmail != null && _userEmail!.isNotEmpty)
          ? _userEmail![0].toUpperCase()
          : 'B';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildProfileCard(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Recitation & Audio', Icons.record_voice_over_rounded),
                  _buildRecitationSection(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Mushaf & Display', Icons.menu_book_rounded),
                  _buildMushafSection(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Practice & Reminders', Icons.notifications_active_rounded),
                  _buildPracticeSection(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('About & Support', Icons.info_outline_rounded),
                  _buildAboutSection(),
                  const SizedBox(height: 32),
                  _buildSignOutButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Preferences and audio customization',
              style: pjs(fontSize: 13, color: AppColors.textMuted),
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

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF5F1E6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealStart,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Text(
              _avatarInitial,
              style: pjs(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userEmail ?? 'Learner',
                  overflow: TextOverflow.ellipsis,
                  style: pjs(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
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
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecitationSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF5F1E6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reference Reciter',
                  style: pjs(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<Reciter>(
                  initialValue: _reciter,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFF5F1E6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFF5F1E6)),
                    ),
                  ),
                  items: [
                    for (final r in Reciter.all)
                      DropdownMenuItem(value: r, child: Text(r.name)),
                  ],
                  onChanged: (r) {
                    if (r == null) return;
                    setState(() => _reciter = r);
                    Reciter.select(r);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F1E6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Tajweed Sensitivity',
                  style: pjs(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['Lenient', 'Standard', 'Strict'].map((level) {
                    final bool isSelected = _tajweedSensitivity == level;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _tajweedSensitivity = level),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.tealStart : const Color(0xFFF5F1E6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              level,
                              style: pjs(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppColors.textDark,
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
          const Divider(height: 1, color: Color(0xFFF5F1E6)),
          SwitchListTile(
            title: Text('Auto-play reference audio', style: pjs(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            subtitle: Text('Listen to correct recitation after recording', style: pjs(fontSize: 11, color: AppColors.textMuted)),
            value: _autoPlayReference,
            activeTrackColor: AppColors.tealStart,
            onChanged: (v) => setState(() => _autoPlayReference = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMushafSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF5F1E6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text('Tajweed color highlights', style: pjs(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            subtitle: Text('Highlight Ghunnah, Madd, and Qalqalah rules in text', style: pjs(fontSize: 11, color: AppColors.textMuted)),
            value: _showTajweedColors,
            activeTrackColor: AppColors.tealStart,
            onChanged: (v) => setState(() => _showTajweedColors = v),
          ),
          const Divider(height: 1, color: Color(0xFFF5F1E6)),
          SwitchListTile(
            title: Text('Show transliteration & translation', style: pjs(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            subtitle: Text('Display "How to say it" card on recitation screen', style: pjs(fontSize: 11, color: AppColors.textMuted)),
            value: _showTransliteration,
            activeTrackColor: AppColors.tealStart,
            onChanged: (v) => setState(() => _showTransliteration = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF5F1E6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Practice Goal', style: pjs(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    Text('Commit to daily Quran recitation', style: pjs(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
                DropdownButton<int>(
                  value: _dailyGoalMinutes,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 min')),
                    DropdownMenuItem(value: 10, child: Text('10 min')),
                    DropdownMenuItem(value: 15, child: Text('15 min')),
                    DropdownMenuItem(value: 30, child: Text('30 min')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _dailyGoalMinutes = v);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F1E6)),
          SwitchListTile(
            title: Text('Daily reminder', style: pjs(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            subtitle: Text('Gentle notification at 7:00 AM', style: pjs(fontSize: 11, color: AppColors.textMuted)),
            value: _dailyReminder,
            activeTrackColor: AppColors.tealStart,
            onChanged: (v) => setState(() => _dailyReminder = v),
          ),
          const Divider(height: 1, color: Color(0xFFF5F1E6)),
          SwitchListTile(
            title: Text('Sound effects & celebrations', style: pjs(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            subtitle: Text('Celebratory chimes for correct recitation', style: pjs(fontSize: 11, color: AppColors.textMuted)),
            value: _soundEffects,
            activeTrackColor: AppColors.tealStart,
            onChanged: (v) => setState(() => _soundEffects = v),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF5F1E6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text('App Version', style: pjs(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            trailing: Text('1.0.0 (Build 2026.08)', style: pjs(fontSize: 12, color: AppColors.textMuted)),
          ),
          const Divider(height: 1, color: Color(0xFFF5F1E6)),
          ListTile(
            title: Text('Tajweed Analysis Engine', style: pjs(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            trailing: Text('Modal GPU Serverless', style: pjs(fontSize: 12, color: AppColors.tealStart, fontWeight: FontWeight.w600)),
          ),
        ],
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out', style: pjs(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        content: Text(
          'Are you sure you want to sign out of Bayaan?',
          style: pjs(fontSize: 14, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: pjs(fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
}

