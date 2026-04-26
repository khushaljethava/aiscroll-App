import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
            // Colour omitted — the AppBar theme's background (scaffold in
            // dark, paper in light) keeps the sliver appbar in step with
            // the rest of the screen when scrolled.
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.ctaAmber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Text('Learn'),
              ],
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                // Adaptive extent — 2 columns on phones (<= ~440 px), 3 on
                // large phones / tablets, 4 on desktop. `mainAxisExtent`
                // fixes tile height so track names that wrap can't clip
                // the progress bar.
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 220,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _TrackCard(track: filtered[index]),
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
// _TrackCard
// ---------------------------------------------------------------------------

class _TrackCard extends ConsumerWidget {
  const _TrackCard({required this.track});

  final LearningTrack track;

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
    // Pro/paywall removed — every track is free; ads are the only
    // monetisation surface. The `isPremium` field on the track model
    // stays so existing manifests parse, but we ignore it for routing.
    final accent = _accent();

    return Material(
      color: AppColors.inkSurface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.learnTrack(track.id)),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.inkHairline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Leading accent bar.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: accent),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.emoji,
                            style: const TextStyle(fontSize: 36)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        track.description,
                        style: tt.bodySmall?.copyWith(
                          color: AppColors.textMutedOnInk,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.inkSurface2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(accent),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$completed / ${track.totalCards} cards',
                      style: tt.labelMedium?.copyWith(
                        color: AppColors.textMutedOnInk,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
