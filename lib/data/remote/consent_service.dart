import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps the Google UMP SDK so ad widgets never load before consent is
/// resolved (required for EEA/UK/CH users). Also configures the Mobile
/// Ads SDK for a general-audience, non-child-directed app.
class ConsentService {
  ConsentService._();

  static final ConsentService instance = ConsentService._();

  bool _canRequestAds = false;

  /// Whether the user has granted consent (or is outside regions that
  /// require a prompt) and ads may be requested.
  bool get canRequestAds => _canRequestAds;

  /// Runs the UMP consent flow, then initializes AdMob when allowed.
  Future<void> initializeAds() async {
    await _gatherConsent();
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    if (!_canRequestAds) return;

    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        maxAdContentRating: MaxAdContentRating.g,
      ),
    );
    await MobileAds.instance.initialize();
  }

  Future<void> _gatherConsent() async {
    final completer = Completer<void>();
    final params = ConsentRequestParameters(
      consentDebugSettings: kDebugMode
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
            )
          : null,
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((_) {
          if (!completer.isCompleted) completer.complete();
        });
      },
      (FormError error) {
        debugPrint('Consent info update failed: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  /// True when GDPR requires a privacy-options entry point in settings.
  Future<bool> isPrivacyOptionsRequired() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  /// Re-opens the UMP privacy-options form so users can change ad choices.
  Future<void> showPrivacyOptionsForm() {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// Call after the user updates privacy choices so ad widgets know whether
  /// they may reload.
  Future<void> refreshCanRequestAds() async {
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
  }
}

final consentServiceProvider =
    Provider<ConsentService>((_) => ConsentService.instance);
