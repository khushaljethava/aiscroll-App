import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Scans lib/ for banned legacy brand strings, including in doc comments.
void main() {
  test('no legacy brand names in user-facing strings', () {
    final banned = ['60 Second AI', 'AIScroll', 'aiscroll.app'];
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final b in banned) {
          if (line.contains(b)) offenders.add('${file.path}:${i + 1}  $b');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Legacy brand strings:\n${offenders.join('\n')}');
  });

  test('no ad-hoc TextStyle(fontSize:) in onboarding widgets', () {
    final offenders = <String>[];
    for (final file
        in Directory('lib/features/onboarding').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.readAsStringSync().contains('fontSize:')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'Use textTheme tokens, not raw fontSize:\n'
            '${offenders.join('\n')}');
  });

  test('no direct AppColors.* in onboarding widgets', () {
    final offenders = <String>[];
    for (final file
        in Directory('lib/features/onboarding').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (RegExp(r'AppColors\.').hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'Source color from colorScheme/context.sem:\n'
            '${offenders.join('\n')}');
  });
}
