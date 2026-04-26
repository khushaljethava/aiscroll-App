import 'package:dio/dio.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../local/preferences_service.dart';

/// Thrown when the user cancels the Google sign-in sheet. The calling UI
/// should silently dismiss its loading state, not show an error.
class AuthCancelled implements Exception {
  const AuthCancelled();
  @override
  String toString() => 'AuthCancelled';
}

/// Thrown for every other sign-in failure. [message] is safe to show in
/// a snackbar — `FirebaseAuthException.message` is typically readable.
class AuthFailed implements Exception {
  const AuthFailed(this.message);
  final String message;
  @override
  String toString() => 'AuthFailed: $message';
}

/// Flutter ↔ admin authentication.
///
/// Flow:
///
///  1. Flutter boots and Firebase initialises (see `main.dart`). App Check
///     is activated with the Play Integrity provider on Android and the
///     App Attest provider on iOS (debug provider in debug builds).
///  2. On first request, `AuthService.getValidToken()` asks Firebase for an
///     App Check token, posts `{ appCheckToken, guestId }` to
///     `/api/client/token`, and receives a signed AIScroll client JWT that
///     middleware accepts on every `/api/news`, `/api/content/*`, and
///     `/api/events/*` request.
///  3. The JWT + its expiry are cached in SharedPreferences. We refresh
///     five minutes before expiry, and on any 401 via the Dio interceptor.
///
/// When `ADMIN_API_URL` is unset, the service is a no-op and all cached
/// data still surfaces through the offline-first data layer. When Firebase
/// itself hasn't been configured (missing google-services.json), the
/// initial App Check call throws; we surface the error via [lastError] and
/// let the UI render whatever it has from cache.
class AuthService {
  AuthService({
    Dio? dio,
    PreferencesService? prefs,
    FirebaseAppCheck? appCheck,
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _dio = dio ?? Dio(),
        _prefs = prefs ?? PreferencesService.instance,
        _appCheck = appCheck ?? FirebaseAppCheck.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _google = googleSignIn ?? GoogleSignIn();

  final Dio _dio;
  final PreferencesService _prefs;
  final FirebaseAppCheck _appCheck;
  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  // Raw env value; [_baseUrl] strips a trailing slash to keep the
  // composed `/api/client/token` URL canonical.
  static const _rawBaseUrl = String.fromEnvironment('ADMIN_API_URL');

  static String get _baseUrl => _rawBaseUrl.endsWith('/')
      ? _rawBaseUrl.substring(0, _rawBaseUrl.length - 1)
      : _rawBaseUrl;

  static const _kTokenKey = 'auth.clientJwt.v1';
  static const _kExpiresAtKey = 'auth.clientJwt.expiresAtMs';

  /// Margin before expiry that triggers a proactive refresh. 5 min is
  /// plenty to absorb clock skew without thrashing the network.
  static const _refreshMargin = Duration(minutes: 5);

  String? _lastError;
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;

  /// Human-readable description of the last failure, or null if things are
  /// fine. UI can show this in a debug banner.
  String? get lastError => _lastError;

  bool get isAdminConfigured => _rawBaseUrl.isNotEmpty;

  /// Returns a client JWT suitable for `Authorization: Bearer …` headers.
  /// Fetches one if none is cached or the cached one is near expiry.
  ///
  /// [forceRefresh] skips the cache — used by the 401 retry path.
  ///
  /// Returns null when [_baseUrl] is empty, Firebase isn't initialised, or
  /// the network call fails. Callers can still proceed: Dio just omits the
  /// header and the middleware returns 401, which surfaces through the
  /// existing stale-cache UX.
  Future<String?> getValidToken({
    required String guestId,
    bool forceRefresh = false,
  }) async {
    if (!isAdminConfigured) return null;
    if (!_firebaseAvailable) {
      _lastError = 'Firebase not initialised — skipping remote auth.';
      return null;
    }

    if (!forceRefresh) {
      final cached = _readCached();
      if (cached != null) return cached;
    }

    try {
      final appCheckToken = await _appCheck.getToken(forceRefresh);
      if (appCheckToken == null || appCheckToken.isEmpty) {
        _lastError = 'App Check returned an empty token.';
        return null;
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/api/client/token',
        data: {
          'appCheckToken': appCheckToken,
          'guestId': guestId,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          // We handle 401 in the interceptor chain, not here.
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (response.statusCode != 200 || response.data == null) {
        _lastError = 'Token exchange failed: HTTP ${response.statusCode}';
        return null;
      }
      final body = response.data!;
      if (body['success'] != true) {
        _lastError = body['error']?.toString() ?? 'Token exchange rejected';
        return null;
      }
      final data = body['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      final expiresAtMs = (data['expiresAtMs'] as num).toInt();
      await _prefs.setString(_kTokenKey, token);
      await _prefs.setInt(_kExpiresAtKey, expiresAtMs);
      _lastError = null;
      return token;
    } on DioException catch (e) {
      _lastError = 'Network error: ${e.message ?? e.type.name}';
      return null;
    } catch (e, st) {
      _lastError = 'Unexpected auth error: $e';
      debugPrint('AuthService.getValidToken failed: $e\n$st');
      return null;
    }
  }

  /// Drops any cached token. Called on hard sign-out events — currently
  /// unused in the app but wired for completeness.
  Future<void> clear() async {
    await _prefs.remove(_kTokenKey);
    await _prefs.remove(_kExpiresAtKey);
  }

  String? _readCached() {
    final token = _prefs.getString(_kTokenKey);
    final expiresAtMs = _prefs.getInt(_kExpiresAtKey);
    if (token == null || expiresAtMs == null) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
    if (expiresAt.isBefore(DateTime.now().add(_refreshMargin))) {
      return null;
    }
    return token;
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  //
  // Firebase Auth is the source of truth for user identity. Google acts as
  // the OAuth provider. Server-side there's nothing to do — the admin
  // sees `UserProfile.firebaseUid` when telemetry fires, and can verify
  // it via Firebase Admin if needed (future feature).
  // ---------------------------------------------------------------------------

  /// Opens the native Google account picker, exchanges the result for a
  /// Firebase credential, and returns the authenticated [User].
  ///
  /// Throws [AuthCancelled] when the user dismisses the sheet. Wraps every
  /// other failure in [AuthFailed] with a human-readable message.
  Future<User> signInWithGoogle() async {
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) throw const AuthCancelled();
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) {
        throw const AuthFailed('Google returned no user. Try again.');
      }
      return user;
    } on AuthCancelled {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthFailed(_friendlyMessage(e));
    } catch (e) {
      throw AuthFailed('Google sign-in failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Email + password
  //
  // Companion path to Google sign-in. Same Firebase Auth backend; the only
  // difference at the call site is the credential used. We surface common
  // errors (`email-already-in-use`, `weak-password`, …) via [AuthFailed]
  // with a friendly message so screens can show them in a snackbar.
  // ---------------------------------------------------------------------------

  /// Creates a new Firebase user with the given credentials and updates
  /// the display name. Caller is responsible for then calling
  /// [UserNotifier.pullFromCloudAndMerge] (or signInWithFirebaseUser) to
  /// hydrate local state.
  Future<User> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw const AuthFailed('Registration failed. Please try again.');
      }
      if (displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
        // updateDisplayName mutates the FirebaseUser in place but the
        // cached `cred.user` reference is stale — reload to pick it up.
        await user.reload();
      }
      return _auth.currentUser ?? user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailed(_friendlyMessage(e));
    } catch (e) {
      throw AuthFailed('Registration failed: $e');
    }
  }

  /// Signs an existing user in with email + password.
  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw const AuthFailed('Sign-in failed. Please try again.');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailed(_friendlyMessage(e));
    } catch (e) {
      throw AuthFailed('Sign-in failed: $e');
    }
  }

  /// Signs out of both Firebase and Google. The double call is important —
  /// without `_google.signOut()`, the next `signIn()` silently reuses the
  /// previously-selected Google account instead of showing the picker.
  Future<void> signOutFromGoogle() async {
    try {
      await _google.signOut();
    } catch (_) {
      // Best-effort. A failure here doesn't prevent Firebase sign-out.
    }
    try {
      await _auth.signOut();
    } catch (_) {
      // Same — local state flip is what matters to the user.
    }
    await clear();
  }

  /// Firebase stream — `null` when signed out. Exposed so the UI can
  /// react to silent sign-outs (token revocation, account deletion).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  String _friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'That email is already registered with a different sign-in method.';
      case 'invalid-credential':
        return 'Credentials were rejected. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      // Email + password specifics:
      case 'email-already-in-use':
        return 'That email is already registered. Try signing in instead.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'weak-password':
        return 'Please choose a longer password (at least 6 characters).';
      case 'user-not-found':
      case 'wrong-password':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return e.message ?? 'Sign-in failed (${e.code}).';
    }
  }
}
