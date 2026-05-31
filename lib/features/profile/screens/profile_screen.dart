import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/brand.dart';
import '../../../core/constants/xp_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../data/local/preferences_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/analytics_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/remote/ads_service.dart';
import '../../../features/feed/providers/srs_provider.dart';
import '../../../features/gamification/providers/gamification_provider.dart';
import '../../../shared/widgets/app_section_card.dart';

// ---------------------------------------------------------------------------
// ProfileScreen
// ---------------------------------------------------------------------------

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            forceMaterialTransparency: false,
            title: const Text('Profile'),
            actions: [
              IconButton(
                tooltip: 'Edit profile',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push(AppRoutes.profileEdit),
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 4),
              _ProfileHeader(user: user),
              const SizedBox(height: AppSpacing.lg),
              _XpProgressCard(user: user),
              const SizedBox(height: AppSpacing.lg),
              _StatsGrid(user: user),
              const SizedBox(height: AppSpacing.lg),
              _StreakCalendar(user: user),
              const SizedBox(height: AppSpacing.lg),
              _StreakFreezeRewardTile(user: user),
              const SizedBox(height: AppSpacing.lg),
              _ReferralCard(user: user),
              const SizedBox(height: AppSpacing.lg),
              _BadgesSection(user: user),
              const SizedBox(height: AppSpacing.xl),
              _SettingsGroup(
                label: 'Settings',
                children: [
                  const _GroupSubheader(label: 'Preferences'),
                  _NavTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit profile',
                    subtitle: 'Name, topics, daily goal',
                    onTap: () => context.push(AppRoutes.profileEdit),
                  ),
                  const _ThemedDivider(),
                  const _AppearanceTile(),
                  const _ThemedDivider(),
                  const _GroupSubheader(label: 'Notifications'),
                  _PushSwitchTile(user: user),
                  const _ThemedDivider(),
                  _ReminderSwitchTile(user: user),
                  const _ThemedDivider(),
                  _ReminderTimeTile(user: user),
                  const _ThemedDivider(),
                  _ReviewCapTile(user: user),
                  const _ThemedDivider(),
                  const _GroupSubheader(label: 'Feedback'),
                  _HapticsTile(user: user),
                  const _ThemedDivider(),
                  _SoundTile(user: user),
                  const _ThemedDivider(),
                  const _GroupSubheader(label: 'Privacy'),
                  const _AnalyticsTile(),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _DangerZone(user: user),
              const SizedBox(height: AppSpacing.xxl),
            ]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile header
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final initial = user.name?.isNotEmpty == true
        ? user.name![0].toUpperCase()
        : '?';
    final level = XPConstants.getLevelFromXP(user.totalXP);
    final title = XPConstants.getTitleFromXP(user.totalXP);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(user: user, initial: initial),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user.isGuest)
                  // Guests get a tappable Sign-in CTA in place of the
                  // username — sends them through the auth flow but
                  // preserves their local progress on return.
                  _SignInButton()
                else ...[
                  Text(
                    user.name ?? 'User',
                    style: tt.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email!,
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                _LevelPill(level: level, title: title),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact pill button shown in the profile header for guest users. Routes
/// to the welcome screen so the user can sign in or register; their local
/// progress is preserved and merged into the cloud profile on return.
class _SignInButton extends StatelessWidget {
  // ignore: unused_element_parameter
  const _SignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        onPressed: () => context.push(AppRoutes.onboardingWelcome),
        icon: const Icon(Icons.login_rounded, size: 18),
        label: const Text('Sign in / Create account'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ctaAmber,
          foregroundColor: AppColors.inkBlack,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.initial});

  final UserProfile user;
  final String initial;

  @override
  Widget build(BuildContext context) {
    // Signed-in users with a photoUrl get their Google avatar. Guests or
    // users whose photo failed to load fall back to a primary-tinted
    // circle with their initial.
    final fallback = CircleAvatar(
      radius: 36,
      backgroundColor: AppColors.primary,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
    final url = user.photoUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level, required this.title});

  final int level;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.ctaAmber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.ctaAmber.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Text(
        'Level $level · $title',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.ctaAmber,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// XP Progress card
// ---------------------------------------------------------------------------

class _XpProgressCard extends StatelessWidget {
  const _XpProgressCard({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = context.sem;
    final level = XPConstants.getLevelFromXP(user.totalXP);
    final title = XPConstants.getTitleFromXP(user.totalXP);
    final nextTitle = level < XPConstants.levelTitles.length
        ? XPConstants.levelTitles[level]
        : title;
    final progress = XPConstants.levelProgress(user.totalXP);
    final xpToNext = XPConstants.xpForNextLevel(user.totalXP);

    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                '${user.totalXP} XP',
                style: TextStyle(
                  color: sem.xpGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Level $level → Level ${level + 1}: $nextTitle',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(sem.xpGold),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$xpToNext XP to next level',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats grid (2x2 instead of cramped 1x4 row)
// ---------------------------------------------------------------------------

class _StatsGrid extends ConsumerWidget {
  const _StatsGrid({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueToday = ref.watch(dueReviewCountProvider);
    final stats = [
      ('🔥', '${user.currentStreak}', 'Day streak'),
      ('📚', '${user.totalCardsRead}', 'Cards read'),
      ('⚡', '${user.quizzesPassed}', 'Quizzes passed'),
      (
        '🔁',
        '${user.reviewsDoneToday}',
        dueToday > 0 ? 'Reviews · $dueToday due' : 'Reviews today',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.0,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final (emoji, value, label) in stats)
            _StatItem(emoji: emoji, value: value, label: label),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppSectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Tooltip(
        message: '$label: $value',
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streak calendar (last 7 days)
// ---------------------------------------------------------------------------

class _StreakCalendar extends StatelessWidget {
  const _StreakCalendar({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - (6 - i)),
    );

    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week', style: tt.titleMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: days.map((day) {
              final isActive = user.currentStreak > 0 &&
                  user.lastActiveDate != null &&
                  day.isBefore(
                    user.lastActiveDate!.add(const Duration(days: 1)),
                  ) &&
                  day.isAfter(
                    user.lastActiveDate!.subtract(
                      Duration(days: user.currentStreak),
                    ),
                  );
              return _DayDot(day: day, isActive: isActive);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.isActive});

  final DateTime day;
  final bool isActive;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = context.sem;
    final label = _dayLabels[day.weekday - 1];
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? sem.success : cs.surfaceContainerHighest,
          ),
          child: isActive
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Badges (compact horizontal teaser + view-all sheet)
// ---------------------------------------------------------------------------

class _BadgesSection extends StatelessWidget {
  const _BadgesSection({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final badges = BadgeDefinitions.allBadges;
    final earnedCount = badges
        .where((b) => user.earnedBadgeIds.contains(b.id))
        .length;
    // Earned first, then locked — better visual reward.
    final ordered = [...badges]..sort((a, b) {
      final ae = user.earnedBadgeIds.contains(a.id) ? 0 : 1;
      final be = user.earnedBadgeIds.contains(b.id) ? 0 : 1;
      return ae.compareTo(be);
    });

    return AppSectionCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Badges', style: tt.titleMedium)),
              Text(
                '$earnedCount of ${badges.length}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openAllBadges(context, badges, user),
                child: Text(
                  'View all',
                  style: tt.labelLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ordered.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final badge = ordered[i];
                final isEarned = user.earnedBadgeIds.contains(badge.id);
                return _BadgeChip(badge: badge, isEarned: isEarned);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openAllBadges(
    BuildContext context,
    List<UserBadge> badges,
    UserProfile user,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Badges',
                    style: Theme.of(sheetCtx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2.2,
                          ),
                      itemCount: badges.length,
                      itemBuilder: (_, i) {
                        final badge = badges[i];
                        final isEarned = user.earnedBadgeIds.contains(badge.id);
                        return _BadgeTile(badge: badge, isEarned: isEarned);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Compact circular badge for the horizontal teaser strip.
class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge, required this.isEarned});

  final UserBadge badge;
  final bool isEarned;

  Color _rarityColor(BuildContext context) {
    final sem = context.sem;
    final cs = Theme.of(context).colorScheme;
    switch (badge.rarity) {
      case BadgeRarity.common:
        return cs.onSurfaceVariant;
      case BadgeRarity.uncommon:
        return sem.success;
      case BadgeRarity.rare:
        return AppColors.primary;
      case BadgeRarity.legendary:
        return sem.xpGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = _rarityColor(context);
    Widget tile = Tooltip(
      message: '${badge.name}${isEarned ? "" : " · locked"}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceContainerHighest,
              border: isEarned
                  ? Border.all(color: color.withValues(alpha: 0.7), width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(badge.emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              badge.name,
              style: tt.labelSmall?.copyWith(
                color: isEarned ? null : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (!isEarned) {
      tile = Opacity(opacity: 0.45, child: tile);
    }
    return tile;
  }
}

/// Larger badge tile shown in the "View all" bottom sheet.
class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.isEarned});

  final UserBadge badge;
  final bool isEarned;

  Color _rarityColor(BuildContext context) {
    final sem = context.sem;
    final cs = Theme.of(context).colorScheme;
    switch (badge.rarity) {
      case BadgeRarity.common:
        return cs.onSurfaceVariant;
      case BadgeRarity.uncommon:
        return sem.success;
      case BadgeRarity.rare:
        return AppColors.primary;
      case BadgeRarity.legendary:
        return sem.xpGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = context.sem;
    final color = _rarityColor(context);
    Widget tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: isEarned
            ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
            : null,
        boxShadow: isEarned
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.16),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Text(badge.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  badge.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (isEarned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: sem.success.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'EARNED',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: sem.success,
                ),
              ),
            ),
        ],
      ),
    );

    if (!isEarned) {
      tile = Opacity(opacity: 0.45, child: tile);
    }
    return tile;
  }
}

// ---------------------------------------------------------------------------
// Streak-freeze reward tile (rewarded-ad redemption)
// ---------------------------------------------------------------------------

class _StreakFreezeRewardTile extends ConsumerStatefulWidget {
  const _StreakFreezeRewardTile({required this.user});

  final UserProfile user;

  @override
  ConsumerState<_StreakFreezeRewardTile> createState() =>
      _StreakFreezeRewardTileState();
}

class _StreakFreezeRewardTileState
    extends ConsumerState<_StreakFreezeRewardTile> {
  bool _watching = false;
  static const _freezeCap = 2;

  @override
  void initState() {
    super.initState();
    // Pre-load on mount so the tap-to-watch is instant most of the time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ignore: discarded_futures
      ref.read(adsServiceProvider).preloadRewarded();
    });
  }

  Future<void> _watchAdForFreeze() async {
    if (_watching) return;
    setState(() => _watching = true);
    try {
      final earned = await ref.read(adsServiceProvider).showRewarded();
      if (!earned || !mounted) return;
      final granted =
          await ref.read(userProvider.notifier).grantBonusFreeze();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              granted
                  ? '+1 streak freeze added.'
                  : 'You already have the maximum ($_freezeCap).',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    } finally {
      if (mounted) setState(() => _watching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final atCap = widget.user.freezesAvailable >= _freezeCap;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppSectionCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('❄️', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Streak freezes',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    atCap
                        ? 'You have ${widget.user.freezesAvailable}/$_freezeCap'
                            ' — at the cap.'
                        : 'You have ${widget.user.freezesAvailable}/$_freezeCap.'
                            ' Watch a short ad to earn one.',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed:
                  (atCap || _watching) ? null : _watchAdForFreeze,
              icon: _watching
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: Text(_watching ? 'Loading' : 'Watch ad'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings groups (labeled sections)
// ---------------------------------------------------------------------------

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg + 4,
            0,
            AppSpacing.lg,
            8,
          ),
          child: Text(
            label.toUpperCase(),
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
        ),
        AppSectionCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _GroupSubheader extends StatelessWidget {
  const _GroupSubheader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: tt.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
          letterSpacing: 1.2,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ThemedDivider extends StatelessWidget {
  const _ThemedDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      color: context.sem.hairline,
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications group tiles
// ---------------------------------------------------------------------------

class _PushSwitchTile extends ConsumerWidget {
  const _PushSwitchTile({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: const Text('News push notifications'),
      subtitle: Text(Brand.pushFromLine),
      secondary: const Icon(Icons.campaign_rounded),
      value: user.pushNotificationsEnabled,
      onChanged: (v) async {
        final ok = await ref.read(userProvider.notifier).setPushEnabled(v);
        if (v && !ok && context.mounted) {
          // Permission denied — Android 13+ won't show the dialog again.
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Push notifications are blocked. Enable them in Settings → Apps → ${Brand.name} → Notifications.',
            ),
            duration: const Duration(seconds: 6),
          ));
        }
      },
    );
  }
}

class _ReminderSwitchTile extends ConsumerWidget {
  const _ReminderSwitchTile({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: const Text('Daily reminder'),
      secondary: const Icon(Icons.notifications_rounded),
      value: user.notificationsEnabled,
      onChanged: (v) async {
        final ok =
            await ref.read(userProvider.notifier).setNotificationsEnabled(v);
        if (v && !ok && context.mounted) {
          // Permission permanently denied — Android 13+ won't re-prompt.
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Notifications are blocked. Enable them in Settings → Apps → ${Brand.name} → Notifications.',
            ),
            duration: const Duration(seconds: 6),
          ));
        }
      },
    );
  }
}

class _ReminderTimeTile extends ConsumerWidget {
  const _ReminderTimeTile({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: const Icon(Icons.access_time_rounded),
      title: const Text('Reminder time'),
      enabled: user.notificationsEnabled,
      trailing: Text(
        _formatMinutes(user.reminderMinutesSinceMidnight),
        style: TextStyle(
          color: user.notificationsEnabled
              ? AppColors.primary
              : cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: user.notificationsEnabled
          ? () => _pickReminderTime(context, ref, user)
          : null,
    );
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) async {
    final current = TimeOfDay(
      hour: user.reminderMinutesSinceMidnight ~/ 60,
      minute: user.reminderMinutesSinceMidnight % 60,
    );
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    await ref
        .read(userProvider.notifier)
        .setReminderTime(picked.hour * 60 + picked.minute);
  }
}

class _ReviewCapTile extends ConsumerWidget {
  const _ReviewCapTile({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: const Icon(Icons.repeat_rounded),
      title: const Text('Daily review cap'),
      subtitle: Text(
        'Max number of spaced-repetition reviews per day',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing: Text(
        '${user.dailyReviewCap}',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () => _showCapPicker(context, ref, user.dailyReviewCap),
    );
  }

  Future<void> _showCapPicker(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    const options = [10, 20, 30, 50, 100];
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Daily review cap',
                style: Theme.of(sheetCtx).textTheme.titleMedium,
              ),
            ),
            for (final n in options)
              ListTile(
                title: Text('$n reviews / day'),
                trailing: n == current
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppColors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetCtx).pop(n),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && picked != current) {
      await ref.read(userProvider.notifier).setDailyReviewCap(picked);
    }
  }
}

// ---------------------------------------------------------------------------
// Feedback group tiles
// ---------------------------------------------------------------------------

class _HapticsTile extends ConsumerWidget {
  const _HapticsTile({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: const Text('Haptic feedback'),
      secondary: const Icon(Icons.vibration_rounded),
      value: user.hapticsEnabled,
      onChanged: (v) =>
          ref.read(userProvider.notifier).setHapticsEnabled(v),
    );
  }
}

class _SoundTile extends ConsumerWidget {
  const _SoundTile({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: const Text('Sound effects'),
      secondary: const Icon(Icons.volume_up_rounded),
      value: user.soundEnabled,
      onChanged: (v) =>
          ref.read(userProvider.notifier).setSoundEnabled(v),
    );
  }
}

// ---------------------------------------------------------------------------
// Privacy: anonymous analytics toggle
// ---------------------------------------------------------------------------

/// Reads/writes the `analytics.enabled` SharedPreference via [AnalyticsService].
/// Stored locally — toggling immediately calls
/// `setAnalyticsCollectionEnabled` on the Firebase SDK so no further events
/// are recorded once the user opts out.
class _AnalyticsTile extends ConsumerStatefulWidget {
  const _AnalyticsTile();

  @override
  ConsumerState<_AnalyticsTile> createState() => _AnalyticsTileState();
}

class _AnalyticsTileState extends ConsumerState<_AnalyticsTile> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    // Read the in-memory cached value populated by AnalyticsService.init()
    // during app boot.
    _enabled = ref.read(analyticsServiceProvider).isEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Help improve the app'),
      subtitle: const Text(
        'Anonymous usage analytics. We never share your name, email, or '
        'reading history with third parties.',
      ),
      secondary: const Icon(Icons.bar_chart_rounded),
      value: _enabled,
      onChanged: (v) async {
        await ref.read(analyticsServiceProvider).setEnabled(v);
        if (!mounted) return;
        setState(() => _enabled = v);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Appearance tile
// ---------------------------------------------------------------------------

class _AppearanceTile extends ConsumerWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final tt = Theme.of(context).textTheme;
    final modeIcon = switch (mode) {
      ThemeMode.system => Icons.brightness_auto_rounded,
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(modeIcon, size: 22),
              const SizedBox(width: 16),
              Expanded(child: Text('Appearance', style: tt.titleMedium)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _ModeChip(
                label: 'System',
                icon: Icons.brightness_auto_rounded,
                selected: mode == ThemeMode.system,
                onSelected: () => ref
                    .read(themeModeProvider.notifier)
                    .set(ThemeMode.system),
              ),
              _ModeChip(
                label: 'Light',
                icon: Icons.light_mode_rounded,
                selected: mode == ThemeMode.light,
                onSelected: () =>
                    ref.read(themeModeProvider.notifier).set(ThemeMode.light),
              ),
              _ModeChip(
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
                selected: mode == ThemeMode.dark,
                onSelected: () =>
                    ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }
}

// ---------------------------------------------------------------------------
// Danger zone (sign out / erase)
// ---------------------------------------------------------------------------

class _DangerZone extends ConsumerWidget {
  const _DangerZone({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg + 4,
            0,
            AppSpacing.lg,
            8,
          ),
          child: Text(
            'DANGER ZONE',
            style: tt.labelMedium?.copyWith(
              color: cs.error,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
        ),
        AppSectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (!user.isGuest) ...[
                _DangerTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  subtitle: 'Keeps your progress on this device',
                  onTap: () => _signOutKeepProgress(context, ref),
                ),
                const _ThemedDivider(),
              ],
              _DangerTile(
                icon: Icons.delete_forever_rounded,
                title: user.isGuest
                    ? 'Reset app'
                    : 'Sign out and erase all data',
                subtitle:
                    'Clears streak, bookmarks, XP, and settings on this device',
                onTap: () => _hardReset(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _signOutKeepProgress(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Sign out?',
      message:
          'You will stay on this device as a guest. Your streak, bookmarks, '
          'and progress will be preserved.',
      actionLabel: 'Sign out',
    );
    if (confirmed != true) return;
    await ref.read(authServiceProvider).signOutFromGoogle();
    await ref.read(userProvider.notifier).signOutKeepProgress();
  }

  Future<void> _hardReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Erase all data?',
      message: 'This clears your streak, bookmarks, XP, and settings. '
          'This cannot be undone.',
      actionLabel: 'Erase',
      destructive: true,
    );
    if (confirmed != true) return;
    await ref.read(authServiceProvider).signOutFromGoogle();
    await PreferencesService.instance.clearAll();
    await ref.read(userProvider.notifier).reset();
    if (context.mounted) {
      context.go(AppRoutes.splash);
    }
  }

  static Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              actionLabel,
              style: TextStyle(
                color: destructive
                    ? Theme.of(ctx).colorScheme.error
                    : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  const _DangerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.error),
      title: Text(
        title,
        style: TextStyle(color: cs.error, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      onTap: onTap,
    );
  }
}

String _formatMinutes(int m) {
  final h = m ~/ 60;
  final min = m % 60;
  final period = h < 12 ? 'AM' : 'PM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:${min.toString().padLeft(2, '0')} $period';
}

// ---------------------------------------------------------------------------
// Referral card — share code, redeem friend's code for +1 streak freeze.
// ---------------------------------------------------------------------------

class _ReferralCard extends ConsumerStatefulWidget {
  const _ReferralCard({required this.user});

  final UserProfile user;

  @override
  ConsumerState<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends ConsumerState<_ReferralCard> {
  final TextEditingController _controller = TextEditingController();
  bool _redeeming = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1200),
          content: Text('Code copied'),
        ),
      );
  }

  Future<void> _share(String code) async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'I\'m learning AI in 60s on ${Brand.name}. Use my code $code when you '
            'sign up and we both get a streak freeze. ${Brand.shareUrl}',
        subject: 'Join me on ${Brand.name}',
      ),
    );
  }

  Future<void> _redeem() async {
    if (_redeeming) return;
    setState(() => _redeeming = true);
    final result =
        await ref.read(userProvider.notifier).redeemReferralCode(_controller.text);
    if (!mounted) return;
    setState(() => _redeeming = false);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    switch (result) {
      case RedeemResult.success:
        _controller.clear();
        messenger.showSnackBar(
          const SnackBar(content: Text('Code accepted — +1 streak freeze!')),
        );
      case RedeemResult.invalid:
        messenger.showSnackBar(
          const SnackBar(content: Text('That code doesn\'t look right.')),
        );
      case RedeemResult.selfReferral:
        messenger.showSnackBar(
          const SnackBar(content: Text('You can\'t redeem your own code.')),
        );
      case RedeemResult.alreadyRedeemed:
        messenger.showSnackBar(
          const SnackBar(content: Text('You\'ve already redeemed a code.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.user.inviteCode;
    if (code == null || code.isEmpty) {
      return const SizedBox.shrink();
    }
    final alreadyRedeemed = widget.user.redeemedInviteCode != null &&
        widget.user.redeemedInviteCode!.isNotEmpty;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return AppSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.card_giftcard_rounded,
                  color: AppColors.ctaAmber,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Invite friends',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Share your code. They get a streak freeze when they redeem.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Text(
                      code,
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () => _copy(code),
                  icon: const Icon(Icons.copy_rounded),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: () => _share(code),
                  icon: const Icon(Icons.ios_share_rounded),
                ),
              ],
            ),
            if (!alreadyRedeemed) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Got a code from a friend?',
                style: tt.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        hintText: 'ABC123',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _redeeming ? null : _redeem,
                    child: Text(_redeeming ? '...' : 'Redeem'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '✓ You redeemed code ${widget.user.redeemedInviteCode}',
                style: tt.bodySmall?.copyWith(color: AppColors.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
