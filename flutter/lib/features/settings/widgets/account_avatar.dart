import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../models/account.dart';

class AccountAvatar extends StatelessWidget {
  final Account account;
  final double size;
  final bool isDecorative;

  const AccountAvatar({
    super.key,
    required this.account,
    this.size = 44,
    this.isDecorative = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = account.avatarPath != null &&
        account.avatarPath!.isNotEmpty &&
        File(account.avatarPath!).existsSync();

    final Widget avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 2),
        color: hasPhoto ? null : AppColors.tealStart,
        image: hasPhoto
            ? DecorationImage(
                image: FileImage(File(account.avatarPath!)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasPhoto
          ? null
          : Text(
              account.name.isNotEmpty ? account.name[0].toUpperCase() : '?',
              style: pjs(
                fontSize: size * 0.38,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    );

    if (isDecorative) {
      return ExcludeSemantics(child: avatar);
    }
    return Semantics(
      image: true,
      label: 'Avatar for ${account.name}',
      child: avatar,
    );
  }
}
