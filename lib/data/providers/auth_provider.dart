import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../remote/auth_service.dart';
import '../remote/authed_dio.dart';
import 'user_provider.dart';

/// Singleton auth service — one per app, holds the cached client JWT.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Factory that attaches the auth interceptor to any Dio instance. Services
/// (content, news, telemetry) call `factory.attach(dio)` during construction.
final authedDioFactoryProvider = Provider<AuthedDioFactory>((ref) {
  return AuthedDioFactory(
    authService: ref.watch(authServiceProvider),
    // Pull the guest id lazily so every request reads the current profile.
    // `userProvider`'s id is stable across launches (seeded on first run in
    // UserNotifier.create) so this is effectively immutable but we keep the
    // indirection for cleanliness.
    guestIdProvider: () => ref.read(userProvider).id,
  );
});
