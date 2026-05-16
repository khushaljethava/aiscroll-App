import 'dart:math';

/// Generates and validates 6-character referral codes.
///
/// Codes use an unambiguous alphabet (no 0/O/1/I/L) so users can read them
/// off a screen and type them into another phone without errors. Generation
/// is uniformly random — codes are NOT derived from user IDs, so they don't
/// leak identity.
class ReferralCode {
  ReferralCode._();

  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const _length = 6;
  static final _rng = Random.secure();

  /// Generates a fresh 6-char code from the unambiguous alphabet.
  static String generate() {
    final buf = StringBuffer();
    for (var i = 0; i < _length; i++) {
      buf.write(_alphabet[_rng.nextInt(_alphabet.length)]);
    }
    return buf.toString();
  }

  /// Normalises user input — uppercases and strips whitespace + dashes.
  /// Returns null if the result isn't a syntactically valid code.
  static String? normalise(String raw) {
    final cleaned = raw
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.length != _length) return null;
    for (var i = 0; i < cleaned.length; i++) {
      if (!_alphabet.contains(cleaned[i])) return null;
    }
    return cleaned;
  }
}
