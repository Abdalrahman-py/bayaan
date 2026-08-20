import 'package:flutter/material.dart';

/// Colors and metrics below are pulled directly from the Figma frame
/// `bayaan-settings` (node 19:941) so this screen matches the design 1:1.
class _SettingsPalette {
  static const background = Color(0xFFFAF8F2);
  static const cardBorder = Color(0xFFF5F1E6);
  static const textPrimary = Color(0xFF2C3531);
  static const textSecondary = Color(0xFF6D7A75);
  static const teal = Color(0xFF0F766E);
  static const avatarRing = Color(0xFFC9A227);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _userName = 'Yusuf Ahmed';
  static const _userEmail = 'yusuf@example.com';
  static const _appLanguage = 'English';

  bool _darkModeEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SettingsPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _SettingsPalette.textPrimary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _ProfileCard(name: _userName, email: _userEmail),
                          const SizedBox(height: 24),
                          _SettingsGroup(
                            appLanguage: _appLanguage,
                            darkModeEnabled: _darkModeEnabled,
                            onDarkModeChanged: (value) {
                              setState(() => _darkModeEnabled = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _BottomNav(),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _SettingsPalette.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _SettingsPalette.teal,
              shape: BoxShape.circle,
              border: Border.all(color: _SettingsPalette.avatarRing, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _SettingsPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _SettingsPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.appLanguage,
    required this.darkModeEnabled,
    required this.onDarkModeChanged,
  });

  final String appLanguage;
  final bool darkModeEnabled;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _SettingsPalette.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _SettingsPalette.cardBorder),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'App Language',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _SettingsPalette.textPrimary,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    '$appLanguage ›',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _SettingsPalette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Dark Mode',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _SettingsPalette.textPrimary,
                    ),
                  ),
                ),
                _SettingsToggle(value: darkModeEnabled, onChanged: onDarkModeChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A 48x28 pill toggle matching the Figma `toggle-container` node exactly,
/// rather than the platform Switch (which has different proportions).
class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? _SettingsPalette.teal : const Color(0xFFE3DFD2),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _SettingsPalette.cardBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _NavTab(icon: Icons.home_outlined, label: 'Home', active: false),
                _NavTab(icon: Icons.menu_book_outlined, label: 'Surahs', active: false),
                _NavTab(icon: Icons.emoji_events_outlined, label: 'Stats', active: false),
                _NavTab(icon: Icons.settings_outlined, label: 'Settings', active: true),
              ],
            ),
          ),
          Container(
            height: 34,
            alignment: Alignment.center,
            child: Container(
              width: 139,
              height: 5,
              decoration: BoxDecoration(
                color: _SettingsPalette.textPrimary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({required this.icon, required this.label, required this.active});

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? _SettingsPalette.teal : _SettingsPalette.textSecondary;
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
