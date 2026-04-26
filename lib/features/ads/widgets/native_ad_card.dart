import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/remote/ads_service.dart';

/// Full-screen native ad slot used inside the news / learn `PageView`s.
///
/// Loads its own [NativeAd] on mount, disposes on tear-down. While loading
/// (or if the load fails), shows a low-key "sponsored" placeholder so the
/// page isn't blank. Layout matches the news/learn cards: a tall rounded
/// container with a thin "Sponsored" overline, the ad creative, and a
/// muted footer.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = NativeAd(
      adUnitId: AdConfig.nativeUnitId,
      request: const AdRequest(),
      // Built-in template means we don't need to ship a Layout XML on
      // Android or a UIView NIB on iOS. `medium` size matches well in a
      // full-screen card slot.
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: AppColors.inkSurface,
        cornerRadius: 16,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.primary,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textPrimary,
          backgroundColor: AppColors.inkSurface,
          size: 16,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textSecondary,
          backgroundColor: AppColors.inkSurface,
          size: 13,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textSecondary,
          backgroundColor: AppColors.inkSurface,
          size: 12,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() {
            _loaded = true;
            _failed = false;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _failed = true;
            _loaded = false;
          });
        },
      ),
    );
    _ad = ad;
    // ignore: discarded_futures
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SponsoredOverline(),
            Expanded(
              child: _loaded && _ad != null
                  ? AdWidget(ad: _ad!)
                  : _AdPlaceholder(failed: _failed),
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsoredOverline extends StatelessWidget {
  const _SponsoredOverline();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.inkSurface2.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign_rounded, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'SPONSORED',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdPlaceholder extends StatelessWidget {
  const _AdPlaceholder({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (failed)
            Icon(Icons.signal_wifi_bad_rounded,
                size: 36, color: cs.onSurfaceVariant)
          else
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(height: 12),
          Text(
            failed ? "Ad couldn't load" : 'Loading sponsored content',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
