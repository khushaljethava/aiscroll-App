import 'package:flutter/material.dart';

import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A standard container used for "section" blocks across the app — profile
/// stats, saved-list cards, tracks grid, learn-detail sections, etc.
///
/// Replaces the duplicated `_SectionCard` widgets that used to live inside
/// individual screen files. Uses the editorial `inkSurface` fill with a
/// hairline border so it works on both [AppColors.inkBlack] scaffolds and
/// lighter contexts.
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    this.accentColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  /// When non-null, renders a 3px vertical bar on the leading edge using this
  /// color — used to give a section a categorical affiliation (e.g. topic
  /// accent on a track card).
  final Color? accentColor;

  /// Makes the whole card tappable. When null the card is purely decorative.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(padding: padding, child: child);
    final body = accentColor == null
        ? inner
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(child: inner),
            ],
          );

    final sem = context.sem;
    final card = Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: sem.sectionSurface,
        borderRadius: AppRadius.card,
        border: Border.all(color: sem.hairline),
      ),
      child: body,
    );

    if (onTap == null) return card;
    return Padding(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.card,
          child: card,
        ),
      ),
    );
  }
}
