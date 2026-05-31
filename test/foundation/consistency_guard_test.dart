import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Scans lib/ for banned legacy brand strings. Comments are migrated in a
/// later task, so this first pass skips comment-only lines.
void main() {
  test('no legacy brand names in user-facing strings', () {
    final banned = ['60 Second AI', 'AIScroll', 'aiscroll.app'];
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        for (final b in banned) {
          if (line.contains(b)) offenders.add('${file.path}:${i + 1}  $b');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Legacy brand strings:\n${offenders.join('\n')}');
  });
}
