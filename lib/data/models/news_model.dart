class NewsCategory {
  final String key;
  final String label;
  final String emoji;
  final int sortOrder;

  const NewsCategory({
    required this.key,
    required this.label,
    required this.emoji,
    this.sortOrder = 100,
  });

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'emoji': emoji,
        'sortOrder': sortOrder,
      };

  factory NewsCategory.fromMap(Map<String, dynamic> m) => NewsCategory(
        key: m['key'] as String,
        label: m['label'] as String,
        emoji: m['emoji'] as String,
        sortOrder: (m['sortOrder'] as int?) ?? 100,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NewsCategory && key == other.key;

  @override
  int get hashCode => key.hashCode;
}

class NewsArticle {
  final String id;
  final String headline;
  final String summary;
  final String body;
  final String? coverImageUrl;
  final String sourceName;
  final String sourceUrl;
  final DateTime publishedAt;
  final String categoryKey;
  final List<String> tags;
  final bool isPinned;

  const NewsArticle({
    required this.id,
    required this.headline,
    required this.summary,
    required this.body,
    this.coverImageUrl,
    required this.sourceName,
    required this.sourceUrl,
    required this.publishedAt,
    required this.categoryKey,
    this.tags = const [],
    this.isPinned = false,
  });

  NewsArticle copyWith({
    String? headline,
    String? summary,
    String? body,
    String? coverImageUrl,
    String? sourceName,
    String? sourceUrl,
    DateTime? publishedAt,
    String? categoryKey,
    List<String>? tags,
    bool? isPinned,
  }) =>
      NewsArticle(
        id: id,
        headline: headline ?? this.headline,
        summary: summary ?? this.summary,
        body: body ?? this.body,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        sourceName: sourceName ?? this.sourceName,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        publishedAt: publishedAt ?? this.publishedAt,
        categoryKey: categoryKey ?? this.categoryKey,
        tags: tags ?? this.tags,
        isPinned: isPinned ?? this.isPinned,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'headline': headline,
        'summary': summary,
        'body': body,
        'coverImageUrl': coverImageUrl,
        'sourceName': sourceName,
        'sourceUrl': sourceUrl,
        'publishedAt': publishedAt.toIso8601String(),
        'categoryKey': categoryKey,
        'tags': tags,
        'isPinned': isPinned,
      };

  factory NewsArticle.fromMap(Map<String, dynamic> m) => NewsArticle(
        id: m['id'] as String,
        headline: m['headline'] as String,
        summary: m['summary'] as String,
        body: m['body'] as String,
        coverImageUrl: m['coverImageUrl'] as String?,
        sourceName: m['sourceName'] as String,
        sourceUrl: m['sourceUrl'] as String,
        publishedAt: DateTime.parse(m['publishedAt'] as String),
        categoryKey: m['categoryKey'] as String,
        tags: List<String>.from(m['tags'] as List? ?? const []),
        isPinned: (m['isPinned'] as bool?) ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NewsArticle && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
