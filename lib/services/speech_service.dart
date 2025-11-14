import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService extends ChangeNotifier {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isAvailable = false;
  String _lastWords = '';
  String _currentLocaleId = 'en_US';

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String get lastWords => _lastWords;

  SpeechService() {
    _initSpeech();
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    _isAvailable = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'listening') {
          _isListening = true;
        } else {
          _isListening = false;
        }
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Speech error: ${error.errorMsg}');
        _isListening = false;
        notifyListeners();
      },
    );
    notifyListeners();
  }

  Future<void> startListening({
    String localeId = 'en_US',
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
    bool partialResults = true,
    bool cancelOnError = false,
    stt.ListenMode listenMode = stt.ListenMode.confirmation,
  }) async {
    if (!_isAvailable) {
      debugPrint('Speech recognition not available');
      return;
    }

    _currentLocaleId = localeId;
    
    await _speech.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;
        debugPrint('Speech result: $_lastWords');
        notifyListeners();
      },
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: partialResults,
      localeId: localeId,
      onSoundLevelChange: (level) {
        // Handle sound level changes if needed
      },
      cancelOnError: cancelOnError,
      listenMode: listenMode,
    );
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
    }
  }

  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
      notifyListeners();
    }
  }

  Future<List<stt.LocaleName>> get locales => _speech.locales();

  void clearLastWords() {
    _lastWords = '';
    notifyListeners();
  }
}
