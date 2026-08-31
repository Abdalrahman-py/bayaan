import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_palette.dart';
import '../../services/accounts_manager.dart';
import 'models/account.dart';
import 'widgets/account_avatar.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _createAccount() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isNotEmpty) {
      AccountsManager.instance.addAccount(
        name: name,
        email: email.isNotEmpty ? email : '$name@bayaan.app',
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final previewAccount = Account(
      id: '',
      name: _nameController.text.isEmpty ? '?' : _nameController.text,
      email: _emailController.text,
    );

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, palette),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: AccountAvatar(account: previewAccount, size: 84),
                  ),
                  const SizedBox(height: 32),
                  _buildLabel('Learner Name', palette),
                  const SizedBox(height: 8),
                  _buildTextField(_nameController, 'e.g. Fatima', palette),
                  const SizedBox(height: 20),
                  _buildLabel('Email Address (Optional)', palette),
                  const SizedBox(height: 8),
                  _buildTextField(
                    _emailController,
                    'fatima@example.com',
                    palette,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _createAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tealStart,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    'Add Learner Profile',
                    style: pjs(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.cardBg,
                border: Border.all(color: palette.borderColor),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_left, size: 20, color: palette.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Add Account',
            style: pjs(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, AppPalette palette) {
    return Text(
      text,
      style: pjs(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: palette.textMuted,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    AppPalette palette, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      style: pjs(fontSize: 15, color: palette.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: pjs(color: palette.textMuted),
        filled: true,
        fillColor: palette.cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
    );
  }
}
