import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_palette.dart';
import '../../../services/accounts_manager.dart';
import 'account_avatar.dart';

void showAccountSwitcherSheet(BuildContext context) {
  final palette = AppPalette.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: palette.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _AccountSwitcherSheet(),
  );
}

class _AccountSwitcherSheet extends StatelessWidget {
  const _AccountSwitcherSheet();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accountsManager = AccountsManager.instance;

    return ListenableBuilder(
      listenable: accountsManager,
      builder: (context, _) {
        final accounts = accountsManager.accounts;
        final activeAccount = accountsManager.activeAccount;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                Semantics(
                  header: true,
                  child: Text(
                    'Switch Learner Profile',
                    style: pjs(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a profile to continue their personalized recitation journey.',
                  style: pjs(fontSize: 12, color: palette.textMuted),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: accounts.map((account) {
                        final bool isActive = account.id == activeAccount.id;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Semantics(
                            button: true,
                            selected: isActive,
                            label: '${account.name}${isActive ? ", active learner" : ""}',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                accountsManager.switchAccount(account.id);
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.tealStart.withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive
                                        ? AppColors.tealStart.withValues(alpha: 0.3)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    AccountAvatar(account: account, size: 44),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            account.name,
                                            style: pjs(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: palette.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isActive ? 'Active Profile' : 'Learner',
                                            style: pjs(
                                              fontSize: 12,
                                              fontWeight: isActive
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color: isActive
                                                  ? AppColors.tealStart
                                                  : palette.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isActive)
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppColors.tealStart,
                                        size: 22,
                                      )
                                    else if (accounts.length > 1)
                                      IconButton(
                                        tooltip: 'Delete Profile ${account.name}',
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 20,
                                          color: AppColors.tajweedError,
                                        ),
                                        onPressed: () => _confirmDeleteProfile(
                                          context,
                                          account.id,
                                          account.name,
                                          palette,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Divider(height: 24, color: palette.borderColor),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.addAccount);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.tealStart,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: AppColors.tealStart,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Add Learner Profile',
                          style: pjs(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.tealStart,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteProfile(
    BuildContext context,
    String id,
    String name,
    AppPalette palette,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Profile',
          style: pjs(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: palette.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete profile "$name"? Their practice history under this profile will be removed.',
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
              AccountsManager.instance.removeAccount(id);
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
              'Delete',
              style: pjs(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

