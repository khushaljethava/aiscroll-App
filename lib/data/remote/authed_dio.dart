import 'package:dio/dio.dart';

import 'auth_service.dart';

/// Factory that wires every remote service (content, news, telemetry) with
/// the same authentication behaviour:
///
///  * Every outgoing request is tagged with `Authorization: Bearer <jwt>`
///    if a token is available.
///  * On a 401 response, we try once to mint a fresh client JWT (which
///    roundtrips to Firebase App Check + `/api/client/token`) and retry
///    the original request. If the retry still fails, the error bubbles.
///
/// The interceptor stays on top of the service's own [Dio] so that request
/// options (timeouts, base URL, headers set by the caller) are preserved.
class AuthedDioFactory {
  AuthedDioFactory({
    required AuthService authService,
    required String Function() guestIdProvider,
  })  : _authService = authService,
        _guestIdProvider = guestIdProvider;

  final AuthService _authService;
  final String Function() _guestIdProvider;

  /// Attach the auth interceptor to [dio] (usually a service-owned
  /// instance). Returns the same [dio] for chainable setup.
  Dio attach(Dio dio) {
    // Prepend so our interceptor runs first on requests and last on
    // responses — exactly the ordering we want for a retry interceptor.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!_authService.isAdminConfigured) {
            return handler.next(options);
          }
          final token = await _authService.getValidToken(
            guestId: _guestIdProvider(),
          );
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Only rotate on 401 and only once — we track the retry flag on
          // the request's extras bag.
          final status = error.response?.statusCode;
          final alreadyRetried =
              error.requestOptions.extra['_auth_retried'] == true;
          if (status != 401 || alreadyRetried) {
            return handler.next(error);
          }

          final token = await _authService.getValidToken(
            guestId: _guestIdProvider(),
            forceRefresh: true,
          );
          if (token == null) {
            return handler.next(error);
          }

          final retryOptions = error.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $token';
          retryOptions.extra['_auth_retried'] = true;
          try {
            final response = await dio.fetch<dynamic>(retryOptions);
            return handler.resolve(response);
          } on DioException catch (e) {
            return handler.next(e);
          }
        },
      ),
    );
    return dio;
  }
}
