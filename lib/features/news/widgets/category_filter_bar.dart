import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/news_model.dart';

/// Horizontal category selector used by the News feed-style list views.
/// Uses the same editorial chip design as the vertical feed's rail.
class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedKey,
    required this.onSelect,
  });

  final List<NewsCategory> categories;
  final String? selectedKey;
  final void Function(String? key) onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.sm,
        ),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _Chip(
              label: 'All',
              accent: AppColors.ctaAmber,
              selected: selectedKey == null,
              onTap: () => onSelect(null),
            );
          }
          final cat = categories[index - 1];
          return _Chip(
            label: cat.label,
            accent: AppColors.categoryAccent(cat.key),
            selected: selectedKey == cat.key,
            onTap: () => onSelect(cat.key),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.onSurface : Colors.transparent;
    final fg = selected ? cs.surface : cs.onSurfaceVariant;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? cs.onSurface : cs.outlineVariant,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12.5,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
