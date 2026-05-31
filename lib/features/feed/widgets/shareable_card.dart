import 'package:flutter/material.dart';

import '../../../core/constants/brand.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/card_model.dart';

/// A standalone card design optimised for being rendered to a shareable
/// image (Instagram / WhatsApp / Twitter aspect-friendly).
///
/// Wrap with a RepaintBoundary + GlobalKey upstream so the host widget can
/// capture the rendered pixels via `boundary.toImage(...)`.
class ShareableCard extends StatelessWidget {
  const ShareableCard({super.key, required this.card});

  final LearningCard card;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inkBlack,
      child: SizedBox(
        width: 360,
        height: 450,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.ctaAmber,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'AISCROLL',
                      style: TextStyle(
                        color: AppColors.inkBlack,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    card.topicTag.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textMutedOnInk,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Text(card.emoji, style: const TextStyle(fontSize: 88)),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                card.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.accent, width: 3),
                  ),
                ),
                child: Text(
                  card.takeaway,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              const Spacer(),
              const Divider(color: AppColors.inkHairline, height: 1),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: const [
                  Text(
                    'Learn AI in seconds',
                    style: TextStyle(
                      color: AppColors.textMutedOnInk,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '→ ${Brand.name}',
                    style: TextStyle(
                      color: AppColors.ctaAmber,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
