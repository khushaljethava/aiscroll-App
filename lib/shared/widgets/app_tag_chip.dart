import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Editorial tag / topic chip. Compact, tinted per accent color.
///
/// Used for topic labels on learning cards, category pills on news, and
/// hashtag-style tags in detail views.
class AppTagChip extends StatelessWidget {
  const AppTagChip({
    super.key,
    required this.label,
    this.accent,
    this.icon,
    this.onTap,
    this.emphasised = false,
  });

  /// Display text. Rendered as-is (no auto-uppercase) so callers control tone.
  final String label;

  /// Optional accent color. Falls back to [AppColors.primary].
  final Color? accent;

  /// Optional leading icon — useful for "verified" or pin-style chips.
  final IconData? icon;

  final VoidCallback? onTap;

  /// When true, uses a solid accent fill with white text — "filled" variant
  /// used sparingly for hero labels.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    final bg = emphasised ? color : color.withValues(alpha: 0.14);
    final fg = emphasised ? Colors.white : color;
    final border = emphasised ? color : color.withValues(alpha: 0.3);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          // Flexible + ellipsis so a long label inside a constrained parent
          // (e.g. a Row with several siblings) shrinks instead of pushing
          // past the row's width and triggering a RenderFlex overflow.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: chip,
    );
  }
}
