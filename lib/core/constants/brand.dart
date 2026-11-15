/// Single source of truth for AgentBuildLog brand identity. Never hardcode the
/// product name, tagline, or share URL anywhere else.
class Brand {
  Brand._();

  static const String name = 'AgentBuildLog';
  static const String tagline = 'Learn AI in 2 minutes a day.';

  /// Google Play listing used for referral shares and invite links.
  static const String shareUrl =
      'https://play.google.com/store/apps/details?id=com.kj.aiscroll';

  /// The companion website (news, tutorials, blog).
  static const String websiteUrl = 'https://agentbuildlog.com';
  static const String tutorialsUrl = '$websiteUrl/tutorials/';

  /// Public article page for a news item. The site uses the same IDs as the
  /// app, so shares land on a readable page that credits the source.
  static String newsUrl(String id) => '$websiteUrl/news/${Uri.encodeComponent(id)}/';

  /// Play Store copy. Title must be <= 30 chars.
  static const String storeTitle = '$name: Learn AI Daily';
  static const String storeSubtitle = 'AI news & 2-minute lessons';

  /// Push-notification channel description / Settings deep-link instructions.
  static const String pushFromLine = 'Breaking AI news from the $name team.';
}
