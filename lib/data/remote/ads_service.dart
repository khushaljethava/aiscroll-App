import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob configuration. Production unit IDs come from the AdMob console
/// for the AIScroll project; debug builds use Google's universal test
/// units so we never accrue policy strikes against real units while
/// developing.
class AdConfig {
  AdConfig._();

  // ---- Native ----
  // Production native unit registered in AdMob console.
  static const _nativeUnitProd = 'ca-app-pub-5206098172306110/8398969038';
  // Google-published universal test unit for native ads.
  static const _nativeUnitTestAndroid =
      'ca-app-pub-3940256099942544/2247696110';
  static const _nativeUnitTestIos =
      'ca-app-pub-3940256099942544/3986624511';

  // ---- Rewarded ----
  static const _rewardedUnitProd = 'ca-app-pub-5206098172306110/4268152330';
  static const _rewardedUnitTestAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const _rewardedUnitTestIos =
      'ca-app-pub-3940256099942544/1712485313';

  /// Frequency: 1 native ad slot inserted every [adEvery] organic items
  /// (so ad / total ≈ 1/7). 6–8 is the industry sweet spot for in-feed
  /// native — high enough fillrate for revenue, low enough to not feel
  /// spammy. Tweak here if engagement metrics show otherwise.
  static const int adEvery = 7;

  /// Don't show an ad before the user has scrolled past at least this
  /// many real items. Avoids the "first impression = ad" pattern that
  /// triggers churn on day-one.
  static const int adWarmup = 3;

  static String get nativeUnitId {
    if (kReleaseMode) return _nativeUnitProd;
    return Platform.isIOS ? _nativeUnitTestIos : _nativeUnitTestAndroid;
  }

  static String get rewardedUnitId {
    if (kReleaseMode) return _rewardedUnitProd;
    return Platform.isIOS ? _rewardedUnitTestIos : _rewardedUnitTestAndroid;
  }
}

/// Thin wrapper around [RewardedAd] so feature code doesn't depend on the
/// AdMob plugin directly. Native ads have per-instance lifecycle and are
/// loaded inline by [NativeAdCard], so they don't go through this service.
class AdsService {
  AdsService();

  RewardedAd? _rewarded;
  bool _isLoading = false;

  /// Pre-loads a rewarded ad. Call on a screen mount where the user is
  /// likely to redeem one (e.g. profile screen) so the [showRewarded]
  /// call is instant.
  Future<void> preloadRewarded() async {
    if (_rewarded != null || _isLoading) return;
    _isLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: AdConfig.rewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewarded = ad;
            _isLoading = false;
          },
          onAdFailedToLoad: (err) {
            debugPrint('Rewarded ad failed to load: ${err.code} ${err.message}');
            _rewarded = null;
            _isLoading = false;
          },
        ),
      );
    } catch (e) {
      debugPrint('Rewarded ad load threw: $e');
      _isLoading = false;
    }
  }

  /// Shows the pre-loaded rewarded ad. Returns true iff the user watched
  /// to completion and the reward callback fired. After every show (success
  /// or dismiss) we kick off a preload so the next attempt is fast.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      // Nothing pre-loaded — try a one-shot load + show.
      await preloadRewarded();
      if (_rewarded == null) return false;
      return showRewarded();
    }
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _rewarded = null;
        // ignore: discarded_futures
        preloadRewarded();
      },
      onAdFailedToShowFullScreenContent: (a, err) {
        debugPrint('Rewarded ad show failed: ${err.code} ${err.message}');
        a.dispose();
        _rewarded = null;
      },
    );
    await ad.show(onUserEarnedReward: (_, reward) {
      earned = true;
    });
    return earned;
  }

  void dispose() {
    _rewarded?.dispose();
    _rewarded = null;
  }
}

/// Long-lived singleton — one rewarded ad pool per process.
final adsServiceProvider = Provider<AdsService>((ref) {
  final svc = AdsService();
  ref.onDispose(svc.dispose);
  return svc;
});
