import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/card_model.dart';
import '../../../data/models/track_model.dart';
import '../../../data/providers/cards_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../shared/widgets/search_field.dart';

// ---------------------------------------------------------------------------
// Filter state providers
// ---------------------------------------------------------------------------

final _trackFilterProvider = StateProvider<Difficulty?>((ref) => null);
final _trackSearchProvider = StateProvider<String>((ref) => '');

// ---------------------------------------------------------------------------
// TracksScreen
// ---------------------------------------------------------------------------

class TracksScreen extends ConsumerWidget {
  const TracksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTracks = ref.watch(allTracksProvider);
    final filter = ref.watch(_trackFilterProvider);
    final query = ref.watch(_trackSearchProvider).toLowerCase();

    final filtered = allTracks.where((t) {
      if (filter != null && t.level != filter) return false;
      if (query.isEmpty) return true;
      return t.name.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query);
    }).toList();

    // Serves as the Learn tab landing. A Scaffold gives descendants (e.g.
    // the TextField inside SearchField) the Material ancestor they need.
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            centerTitle: false,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            title: Text(
              'Learn',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SearchField(
                hintText: 'Search tracks',
                onChanged: (v) =>
                    ref.read(_trackSearchProvider.notifier).state = v,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _FilterRow(
              selected: filter,
              onSelect: (d) =>
                  ref.read(_trackFilterProvider.notifier).state = d,
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    query.isEmpty
                        ? 'No tracks match this filter'
                        : 'No tracks match "$query"',
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _PathStation(
                    track: filtered[index],
                    side: index.isEven ? _PathSide.left : _PathSide.right,
                    isLast: index == filtered.length - 1,
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter row
// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelect});

  final Difficulty? selected;
  final ValueChanged<Difficulty?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _chip(context, 'All', null),
          const SizedBox(width: 8),
          _chip(context, 'Beginner', Difficulty.beginner),
          const SizedBox(width: 8),
          _chip(context, 'Intermediate', Difficulty.intermediate),
          const SizedBox(width: 8),
          _chip(context, 'Advanced', Difficulty.advanced),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Difficulty? value) {
    final isSelected = selected == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(value),
      showCheckmark: false,
    );
  }
}

// ---------------------------------------------------------------------------
// _PathStation — a single node on the learning path.
//
// Tracks are rendered as alternating-side stations connected by dashed
// vertical trails. Each station shows a circular emoji medallion with a
// progress ring; completed tracks get a gold ring + check overlay,
// not-started tracks get a muted outline ring, in-progress tracks show
// partial fill.
// ---------------------------------------------------------------------------

enum _PathSide { left, right }

class _PathStation extends ConsumerWidget {
  const _PathStation({
    required this.track,
    required this.side,
    required this.isLast,
  });

  final LearningTrack track;
  final _PathSide side;
  final bool isLast;

  Color _accent() {
    switch (track.level) {
      case Difficulty.beginner:
        return AppColors.beginner;
      case Difficulty.intermediate:
        return AppColors.intermediate;
      case Difficulty.advanced:
        return AppColors.advanced;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final user = ref.watch(userProvider);
    final learned = user.learnedCardIds;
    final completed = track.completedCount(learned);
    final progress = track.progressFor(learned);
    final accent = _accent();
    final isCompleted = track.isCompleted(learned);
    final inProgress = !isCompleted && completed > 0;

    final medallion = _Medallion(
      emoji: track.emoji,
      accent: accent,
      progress: progress,
      isCompleted: isCompleted,
      onTap: () => context.push(AppRoutes.learnTrack(track.id)),
    );

    final label = _StationLabel(
      track: track,
      tt: tt,
      completed: completed,
      isCompleted: isCompleted,
      inProgress: inProgress,
      accent: accent,
    );

    final children = side == _PathSide.left
        ? [medallion, const SizedBox(width: 16), Expanded(child: label)]
        : [Expanded(child: label), const SizedBox(width: 16), medallion];

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
        if (!isLast)
          // Trail connector — alternates side to suggest the path winds
          // between stations.
          Padding(
            padding: EdgeInsets.only(
              left: side == _PathSide.left ? 40 : 0,
              right: side == _PathSide.left ? 0 : 40,
              top: 4,
              bottom: 4,
            ),
            child: Align(
              alignment: side == _PathSide.left
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: const _DashedTrail(),
            ),
          ),
      ],
    );
  }
}

class _Medallion extends StatelessWidget {
  const _Medallion({
    required this.emoji,
    required this.accent,
    required this.progress,
    required this.isCompleted,
    required this.onTap,
  });

  final String emoji;
  final Color accent;
  final double progress;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: CircularProgressIndicator(
                value: isCompleted ? 1.0 : progress,
                strokeWidth: 5,
                backgroundColor: AppColors.inkSurface2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? AppColors.xpGold : accent,
                ),
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.inkSurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.inkHairline),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
            if (isCompleted)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.xpGold,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.inkBlack,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StationLabel extends StatelessWidget {
  const _StationLabel({
    required this.track,
    required this.tt,
    required this.completed,
    required this.isCompleted,
    required this.inProgress,
    required this.accent,
  });

  final LearningTrack track;
  final TextTheme tt;
  final int completed;
  final bool isCompleted;
  final bool inProgress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final status = isCompleted
        ? 'Completed'
        : inProgress
            ? '$completed / ${track.totalCards} cards'
            : '${track.totalCards} cards';
    final statusColor =
        isCompleted ? AppColors.xpGold : AppColors.textMutedOnInk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.name,
          style: tt.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          track.description,
          style: tt.bodySmall?.copyWith(
            color: AppColors.textMutedOnInk,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: tt.labelMedium?.copyWith(
                color: statusColor,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashedTrail extends StatelessWidget {
  const _DashedTrail();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 4,
      height: 28,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          4,
          (_) => Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.inkHairline,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
