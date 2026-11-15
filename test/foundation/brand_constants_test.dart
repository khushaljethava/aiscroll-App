import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/core/constants/brand.dart';

void main() {
  test('brand exposes AgentBuildLog identity', () {
    expect(Brand.name, 'AgentBuildLog');
    expect(Brand.tagline, 'Learn AI in 2 minutes a day.');
    expect(Brand.shareUrl, startsWith('https://play.google.com/'));
    expect(Brand.shareUrl, contains('com.kj.aiscroll'));
    // Play Store limits: title <= 30 chars, short description <= 80.
    expect(Brand.storeTitle.length, lessThanOrEqualTo(30));
    expect(Brand.storeSubtitle.length, lessThanOrEqualTo(30));
  });

  test('news links point at the agentbuildlog.com article page', () {
    expect(Brand.websiteUrl, 'https://agentbuildlog.com');
    expect(Brand.newsUrl('openai-ships-x-1a2b'), 'https://agentbuildlog.com/news/openai-ships-x-1a2b/');
    // IDs are slugs today, but never let an odd character break the URL.
    expect(Brand.newsUrl('a b/c'), 'https://agentbuildlog.com/news/a%20b%2Fc/');
  });
}
