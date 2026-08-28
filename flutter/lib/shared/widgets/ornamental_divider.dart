import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class OrnamentalDivider extends StatelessWidget {
  final double width;
  final double opacity;

  const OrnamentalDivider({super.key, this.width = 120, this.opacity = 0.3});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            const Expanded(child: Divider(color: AppColors.gold, height: 1)),
            const SizedBox(width: 12),
            Transform.rotate(
              angle: 45 * 3.14159 / 180,
              child: Container(
                width: 12,
                height: 12,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: Transform.rotate(
                  angle: 45 * 3.14159 / 180,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gold, width: 1),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Divider(color: AppColors.gold, height: 1)),
          ],
        ),
      ),
    );
  }
}
