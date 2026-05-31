import 'package:flutter/material.dart';

import '../../core/constants/brand.dart';

/// The Brevio wordmark, set in the theme's editorial serif (Newsreader via
/// `displaySmall`/`headlineMedium`).
class BrandWordmark extends StatelessWidget {
  /// Hero size for Splash / Welcome (`displaySmall`).
  const BrandWordmark({super.key}) : _hero = true;

  /// Compact size for inline headers (`headlineMedium`).
  const BrandWordmark.compact({super.key}) : _hero = false;

  final bool _hero;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final style = _hero ? tt.displaySmall : tt.headlineMedium;
    return Text(
      Brand.name,
      textAlign: TextAlign.center,
      style: style?.copyWith(color: Theme.of(context).colorScheme.onSurface),
    );
  }
}
