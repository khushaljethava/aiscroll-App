import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';

class XpEntryBadge extends StatelessWidget {
  const XpEntryBadge({
    super.key,
    required this.xp,
    required this.visible,
  });

  final int xp;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible || xp <= 0) return const SizedBox.shrink();

    return Animate(
      effects: [
        ScaleEffect(
          begin: const Offset(0.4, 0.4),
          end: const Offset(1.0, 1.0),
          duration: 350.ms,
          curve: Curves.elasticOut,
        ),
        FadeEffect(
          begin: 0.0,
          end: 1.0,
          duration: 200.ms,
        ),
        FadeEffect(
          begin: 1.0,
          end: 0.0,
          duration: 400.ms,
          delay: 1600.ms,
          curve: Curves.easeIn,
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.xpGold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.xpGold.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Text(
          '+$xp XP',
          style: const TextStyle(
            color: AppColors.xpGold,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
