import 'package:flutter/material.dart';

import '../../core/constants/brand.dart';

/// The Brevio wordmark, set in the theme's editorial serif (Newsreader via
/// `displaySmall`/`headlineMedium`). Use on Splash and Welcome.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.large = true});

  /// Hero size (Splash) vs. compact (inline headers).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final style = large ? tt.displaySmall : tt.headlineMedium;
    return Text(
      Brand.name,
      textAlign: TextAlign.center,
      style: style?.copyWith(color: Theme.of(context).colorScheme.onSurface),
    );
  }
}
