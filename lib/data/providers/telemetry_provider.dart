import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../remote/telemetry_service.dart';
import 'auth_provider.dart';

/// Singleton TelemetryService. `keepAlive: true` so the batch queue doesn't
/// get torn down when no widgets are listening mid-session.
final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  final dio = ref.watch(authedDioFactoryProvider).attach(Dio());
  final service = TelemetryService(dio: dio);
  ref.onDispose(service.dispose);
  return service;
});
