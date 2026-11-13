import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';

class XpPopupWidget extends StatelessWidget {
  const XpPopupWidget({
    super.key,
    required this.xp,
    required this.visible,
    this.label,
  });

  final int xp;
  final bool visible;

  /// Replaces the "+N XP" text (used for level-up / badge toasts).
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (!visible || (label == null && xp <= 0)) return const SizedBox.shrink();

    return Animate(
      effects: [
        ScaleEffect(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
          curve: Curves.elasticOut,
        ),
        MoveEffect(
          begin: const Offset(0, 0),
          end: const Offset(0, -30),
          duration: 1800.ms,
          delay: 200.ms,
          curve: Curves.easeOut,
        ),
        FadeEffect(
          begin: 1.0,
          end: 0.0,
          duration: 600.ms,
          delay: 1400.ms,
          curve: Curves.easeIn,
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.inkSurface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.xpGold.withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.xpGold.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              color: AppColors.xpGold,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              label ?? '+$xp XP',
              style: const TextStyle(
                color: AppColors.xpGold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
