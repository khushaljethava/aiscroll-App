/// Single source of truth for Brevio brand identity. Never hardcode the
/// product name, tagline, or share URL anywhere else.
class Brand {
  Brand._();

  static const String name = 'Brevio';
  static const String tagline = 'Learn AI Daily, in Seconds.';
  static const String welcomeTitle = 'Welcome to $name';

  /// Marketing/share URL. TODO(pre-launch): confirm domain ownership.
  static const String shareUrl = 'https://brevio.app';

  /// App Store / Play copy. Subtitle must be <= 30 chars (Apple limit).
  static const String storeTitle = '$name: Learn AI Daily';
  static const String storeSubtitle = 'AI news & 60-sec lessons';

  /// Push-notification channel description / Settings deep-link instructions.
  static const String pushFromLine = 'Breaking AI news from the $name team.';
}
