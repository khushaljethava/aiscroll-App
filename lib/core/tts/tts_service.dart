import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around `flutter_tts` exposing a singleton with a reactive
/// `isSpeaking` listener. UI binds to [isSpeaking] to swap the play/stop
/// icon.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> isSpeaking = ValueNotifier(false);
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() => isSpeaking.value = true);
      _tts.setCompletionHandler(() => isSpeaking.value = false);
      _tts.setCancelHandler(() => isSpeaking.value = false);
      _tts.setErrorHandler((_) => isSpeaking.value = false);
    } catch (e, st) {
      debugPrint('TtsService init failed: $e\n$st');
    }
  }

  /// Speaks [text]. If already speaking, stops first — consecutive taps
  /// toggle rather than queue utterances.
  Future<void> speak(String text) async {
    await _ensureInit();
    if (isSpeaking.value) {
      await stop();
      return;
    }
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TtsService.speak failed: $e');
      isSpeaking.value = false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TtsService.stop failed: $e');
    } finally {
      isSpeaking.value = false;
    }
  }
}
