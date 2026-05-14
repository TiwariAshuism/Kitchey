import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Controls text-to-speech for message transcripts (play / stop).
class MessageTtsController extends ChangeNotifier {
  MessageTtsController() {
    _init();
  }

  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  Future<void> _init() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
      }
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() {
        _speaking = true;
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _speaking = false;
        notifyListeners();
      });
      _tts.setCancelHandler(() {
        _speaking = false;
        notifyListeners();
      });
      _tts.setErrorHandler((_) {
        _speaking = false;
        notifyListeners();
      });
    } catch (e, st) {
      debugPrint('MessageTtsController init failed: $e\n$st');
    }
  }

  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      _speaking = true;
      notifyListeners();
      await _tts.speak(trimmed);
    } catch (e, st) {
      debugPrint('TTS speak failed: $e\n$st');
      _speaking = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e, st) {
      debugPrint('TTS stop failed: $e\n$st');
    }
    _speaking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_tts.stop());
    super.dispose();
  }
}
