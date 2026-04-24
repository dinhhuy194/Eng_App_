import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TTS Controller — Quản lý Text-to-Speech
/// Tách riêng logic TTS để có thể tái sử dụng ở Reading, Pronunciation, v.v.
class TtsController extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  bool _isPlaying = false;
  bool _isPaused = false;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  String _language = 'en-US';
  int _currentWordStart = 0;
  int _currentWordEnd = 0;

  // ── Getters ──
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  String get language => _language;
  int get currentWordStart => _currentWordStart;
  int get currentWordEnd => _currentWordEnd;

  TtsController() {
    _init();
  }

  Future<void> _init() async {
    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_pitch);
    await _tts.setVolume(1.0);

    // Callback khi đọc xong
    _tts.setCompletionHandler(() {
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
      onComplete?.call();
    });

    // Callback khi bắt đầu đọc
    _tts.setStartHandler(() {
      _isPlaying = true;
      _isPaused = false;
      notifyListeners();
    });

    // Callback highlight từ đang đọc
    _tts.setProgressHandler((text, start, end, word) {
      _currentWordStart = start;
      _currentWordEnd = end;
      onProgress?.call(text, start, end, word);
    });

    // Callback khi bị cancel
    _tts.setCancelHandler(() {
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
    });

    // Callback khi pause
    _tts.setPauseHandler(() {
      _isPlaying = false;
      _isPaused = true;
      notifyListeners();
    });

    // Callback khi resume
    _tts.setContinueHandler(() {
      _isPlaying = true;
      _isPaused = false;
      notifyListeners();
    });
  }

  /// Callback khi đọc xong (set bởi consumer)
  VoidCallback? onComplete;

  /// Callback khi đọc progress (text, start, end, word)
  void Function(String, int, int, String)? onProgress;

  // ═══════════════════════════════════════════
  //  CONTROLS
  // ═══════════════════════════════════════════

  /// Đọc text
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.speak(text);
  }

  /// Tạm dừng
  Future<void> pause() async {
    await _tts.pause();
  }

  /// Dừng hoàn toàn
  Future<void> stop() async {
    await _tts.stop();
    _isPlaying = false;
    _isPaused = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  //  SETTINGS
  // ═══════════════════════════════════════════

  /// Đặt tốc độ đọc (0.0 - 1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    await _tts.setSpeechRate(_speechRate);
    notifyListeners();
  }

  /// Đặt cao độ (0.5 - 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
    notifyListeners();
  }

  /// Đặt ngôn ngữ
  Future<void> setLanguage(String lang) async {
    _language = lang;
    await _tts.setLanguage(lang);
    notifyListeners();
  }

  /// Lấy danh sách ngôn ngữ hỗ trợ
  Future<List<dynamic>> getAvailableLanguages() async {
    return await _tts.getLanguages ?? [];
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
