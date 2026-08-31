import 'package:flutter/material.dart';
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
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Switch Account',
                  style: pjs(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ...accounts.map((account) {
                  final bool isActive = account.id == activeAccount.id;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      accountsManager.switchAccount(account.id);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          AccountAvatar(account: account, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.name,
                                  style: pjs(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                Text(
                                  account.email,
                                  style: pjs(
                                    fontSize: 12,
                                    color: palette.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isActive)
                            Icon(Icons.check_circle,
                                color: AppColors.tealStart, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
                Divider(height: 24, color: palette.borderColor),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.addAccount);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.gold, width: 1.5),
                          ),
                          child: Icon(Icons.add, color: AppColors.tealStart, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Add Account',
                          style: pjs(
                            fontSize: 14,
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
}
