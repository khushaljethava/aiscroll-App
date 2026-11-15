import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/core/constants/brand.dart';

void main() {
  test('brand exposes Brevio identity', () {
    expect(Brand.name, 'Brevio');
    expect(Brand.tagline, 'Learn AI Daily, in Seconds.');
    expect(Brand.shareUrl, startsWith('https://play.google.com/'));
    expect(Brand.shareUrl, contains('com.kj.aiscroll'));
    expect(Brand.storeSubtitle.length, lessThanOrEqualTo(30));
  });
}
