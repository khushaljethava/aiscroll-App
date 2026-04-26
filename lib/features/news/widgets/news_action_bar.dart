import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Bottom action bar used on [NewsDetailScreen]. Three equally-weighted
/// actions: Save, Share, Read at source. Sits above the system gesture area.
class NewsActionBar extends StatelessWidget {
  const NewsActionBar({
    super.key,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onShare,
    required this.onOpenSource,
  });

  final bool isBookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  label: isBookmarked ? 'Saved' : 'Save',
                  color: isBookmarked ? AppColors.ctaAmber : null,
                  onTap: onBookmark,
                ),
              ),
              const _VDivider(),
              Expanded(
                child: _ActionButton(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  onTap: onShare,
                ),
              ),
              const _VDivider(),
              Expanded(
                child: _ActionButton(
                  icon: Icons.open_in_new_rounded,
                  label: 'Source',
                  onTap: onOpenSource,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: cs.outlineVariant,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = color ?? cs.onSurface;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  color: fg,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: fg,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
