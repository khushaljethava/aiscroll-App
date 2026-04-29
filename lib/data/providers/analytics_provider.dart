import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../remote/analytics_service.dart';

/// Singleton AnalyticsService. `init()` is awaited by `app.dart` post-frame
/// callback so the persisted opt-out is in effect before any event fires.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});
