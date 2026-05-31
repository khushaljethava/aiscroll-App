import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/core/constants/brand.dart';

void main() {
  test('brand exposes Brevio identity', () {
    expect(Brand.name, 'Brevio');
    expect(Brand.tagline, 'Learn AI Daily, in Seconds.');
    expect(Brand.shareUrl, startsWith('https://'));
    expect(Brand.shareUrl, isNot(contains('aiscroll')));
    expect(Brand.storeSubtitle.length, lessThanOrEqualTo(30));
  });
}
