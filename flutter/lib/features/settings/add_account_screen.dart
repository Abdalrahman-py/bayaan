import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  String? _pickedAvatarPath;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceSheet(AppPalette palette) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: palette.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.tealStart,
                  ),
                  title: Text(
                    'Choose from Gallery',
                    style: pjs(
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.tealStart,
                  ),
                  title: Text(
                    'Take a Photo',
                    style: pjs(
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                if (_pickedAvatarPath != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: AppColors.tajweedError,
                    ),
                    title: Text(
                      'Remove Photo',
                      style: pjs(
                        fontWeight: FontWeight.w600,
                        color: AppColors.tajweedError,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _pickedAvatarPath = null);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() => _pickedAvatarPath = picked.path);
      }
    } catch (_) {}
  }

  void _createProfile() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    AccountsManager.instance.addAccount(
      name: name,
      avatarPath: _pickedAvatarPath,
    );
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created new learner profile for $name',
            style: pjs(color: Colors.white)),
        backgroundColor: AppColors.tealStart,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    try {
      if (context.canPop()) {
        context.pop();
        return;
      }
    } catch (_) {}
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final previewAccount = Account(
      id: '',
      name: _nameController.text.isEmpty ? '?' : _nameController.text,
      avatarPath: _pickedAvatarPath,
    );

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, palette),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () => _showImageSourceSheet(palette),
                        child: Stack(
                          children: [
                            AccountAvatar(
                              account: previewAccount,
                              size: 100,
                              isDecorative: false,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.tealStart,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: palette.background,
                                    width: 2.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => _showImageSourceSheet(palette),
                        child: Text(
                          _pickedAvatarPath == null
                              ? 'Add Profile Picture'
                              : 'Change Picture',
                          style: pjs(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.tealStart,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Learner Profile Name', palette),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                      style: pjs(fontSize: 15, color: palette.textPrimary),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter a name for the new profile';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'e.g. Fatima, Zayd, Omar',
                        hintStyle: pjs(color: palette.textMuted),
                        filled: true,
                        fillColor: palette.cardBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: palette.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: palette.borderColor),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: AppColors.tealStart,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Profiles share the parent account subscription and reciter settings, but retain isolated lesson progress and mistake metrics.',
                      style: pjs(
                        fontSize: 12,
                        color: palette.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: ElevatedButton(
                    onPressed: _createProfile,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () {
              try {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
              } catch (_) {}
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: palette.cardBg,
              side: BorderSide(color: palette.borderColor),
            ),
            icon: Icon(
              Icons.chevron_left,
              size: 22,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Add Learner Profile',
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
}
