import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Files that have been migrated to the design-system rules. Later UI
/// sub-projects ADD their screens here as they are redesigned.
const _enforcedFiles = <String>[
  'lib/features/onboarding/screens/splash_screen.dart',
  'lib/features/onboarding/screens/welcome_screen.dart',
  'lib/features/profile/screens/profile_screen.dart',
  'lib/features/tracks/screens/tracks_screen.dart',
];

/// Categorical domain palettes that have no ColorScheme/semantic equivalent and
/// are allowed to be referenced directly from AppColors.
final _allowedAppColors = RegExp(
  r'AppColors\.(beginner|intermediate|advanced|categoryAccent|categoryTint|categoryAccents)\b',
);

void main() {
  test('enforced files use textTheme, not raw fontSize', () {
    final offenders = <String>[];
    for (final path in _enforcedFiles) {
      final src = File(path).readAsStringSync();
      final lines = src.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('fontSize:')) offenders.add('$path:${i + 1}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Use textTheme tokens, not raw fontSize:\n${offenders.join('\n')}');
  });

  test('enforced files source chrome colors from theme, not AppColors', () {
    final offenders = <String>[];
    for (final path in _enforcedFiles) {
      final lines = File(path).readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Remove allowed categorical accessors, then flag any remaining AppColors.
        final stripped = line.replaceAll(_allowedAppColors, '');
        if (RegExp(r'AppColors\.').hasMatch(stripped)) {
          offenders.add('$path:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Source chrome colors from colorScheme/context.sem:\n${offenders.join('\n')}');
  });
}
