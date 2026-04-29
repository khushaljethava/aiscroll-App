/// Spaced-repetition state for a single card, using the SM-2 algorithm.
///
/// Quality scale (mapped to 60 Second AI interaction events):
///   5 — Quiz answer correct (parent card)
///   4 — Right-swipe "Learned"
///   3 — Card seen ≥15s, not learned, not previously due
///   2 — Card skipped fast (< 5s dwell)
///   1 — Quiz answer wrong
///   0 — Quiz skipped when shown
class CardReview {
  final String cardId;
  final int reps;
  final double ease;
  final int intervalDays;
  final DateTime nextReview;
  final DateTime? lastReview;

  const CardReview({
    required this.cardId,
    required this.reps,
    required this.ease,
    required this.intervalDays,
    required this.nextReview,
    this.lastReview,
  });

  /// A never-reviewed card. Treated as immediately due.
  factory CardReview.fresh(String cardId) => CardReview(
        cardId: cardId,
        reps: 0,
        ease: 2.5,
        intervalDays: 0,
        nextReview: DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Pre-seeded review for an existing learned card on app upgrade — keeps
  /// the migrated user from seeing every previously learned card flood back
  /// as "due" on day 1.
  factory CardReview.seededFromLearned(String cardId, DateTime today) {
    return CardReview(
      cardId: cardId,
      reps: 1,
      ease: 2.5,
      intervalDays: 6,
      nextReview: today.add(const Duration(days: 6)),
      lastReview: today,
    );
  }

  bool isDue(DateTime today) => !nextReview.isAfter(today);

  /// Pure SM-2 transform — returns a new CardReview reflecting this rating.
  CardReview afterReview(int quality, {DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());

    int newReps;
    int newInterval;
    if (quality < 3) {
      newReps = 0;
      newInterval = 1;
    } else {
      if (reps == 0) {
        newInterval = 1;
      } else if (reps == 1) {
        newInterval = 6;
      } else {
        newInterval = (intervalDays * ease).round();
        if (newInterval < 1) newInterval = 1;
      }
      newReps = reps + 1;
    }

    final delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02);
    var newEase = ease + delta;
    if (newEase < 1.3) newEase = 1.3;

    return CardReview(
      cardId: cardId,
      reps: newReps,
      ease: newEase,
      intervalDays: newInterval,
      nextReview: today.add(Duration(days: newInterval)),
      lastReview: today,
    );
  }

  Map<String, dynamic> toMap() => {
        'cardId': cardId,
        'reps': reps,
        'ease': ease,
        'intervalDays': intervalDays,
        'nextReview': nextReview.toIso8601String(),
        'lastReview': lastReview?.toIso8601String(),
      };

  factory CardReview.fromMap(Map<String, dynamic> m) => CardReview(
        cardId: m['cardId'] as String,
        reps: (m['reps'] as int?) ?? 0,
        ease: (m['ease'] as num?)?.toDouble() ?? 2.5,
        intervalDays: (m['intervalDays'] as int?) ?? 0,
        nextReview: DateTime.parse(m['nextReview'] as String),
        lastReview: m['lastReview'] == null
            ? null
            : DateTime.parse(m['lastReview'] as String),
      );

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardReview &&
          cardId == other.cardId &&
          reps == other.reps &&
          ease == other.ease &&
          intervalDays == other.intervalDays &&
          nextReview == other.nextReview &&
          lastReview == other.lastReview;

  @override
  int get hashCode => Object.hash(
        cardId,
        reps,
        ease,
        intervalDays,
        nextReview,
        lastReview,
      );
}
