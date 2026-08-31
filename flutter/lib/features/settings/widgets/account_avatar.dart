import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../models/account.dart';

class AccountAvatar extends StatelessWidget {
  final Account account;
  final double size;

  const AccountAvatar({super.key, required this.account, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 2),
        color: AppColors.tealStart,
      ),
      child: Text(
        account.name.isNotEmpty ? account.name[0].toUpperCase() : '?',
        style: pjs(
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
