import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../remote/telemetry_service.dart';
import 'analytics_provider.dart';
import 'auth_provider.dart';

/// Singleton TelemetryService. `keepAlive: true` so the batch queue doesn't
/// get torn down when no widgets are listening mid-session.
///
/// Also injects [AnalyticsService] so every event fans out to Firebase
/// Analytics in addition to the admin `/api/events/ingest` endpoint.
final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  final dio = ref.watch(authedDioFactoryProvider).attach(Dio());
  final analytics = ref.watch(analyticsServiceProvider);
  final service = TelemetryService(dio: dio, analytics: analytics);
  ref.onDispose(service.dispose);
  return service;
});
