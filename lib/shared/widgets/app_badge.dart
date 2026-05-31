import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// A tinted pill badge (level pill, "EARNED" tag, etc.). Tints [color] for the
/// background (and, in the default form, the border) so it adapts to any accent.
class AppBadge extends StatelessWidget {
  /// Standard pill with a tinted border — e.g. the profile level pill.
  const AppBadge({super.key, required this.label, required this.color, this.icon})
      : _dense = false;

  /// Compact micro-label with no border and tighter padding — e.g. an
  /// "EARNED" tag inside a dense list row.
  const AppBadge.micro({super.key, required this.label, required this.color})
      : icon = null,
        _dense = true;

  final String label;
  final Color color;
  final IconData? icon;
  final bool _dense;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final style = (_dense ? tt.labelSmall : tt.labelMedium)
        ?.copyWith(color: color, fontWeight: FontWeight.w700);
    return Container(
      padding: _dense
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: _dense ? null : Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: style),
        ],
      ),
    );
  }
}

/// Small filled status dot used in meta rows.
class AppStatusDot extends StatelessWidget {
  const AppStatusDot({super.key, required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
