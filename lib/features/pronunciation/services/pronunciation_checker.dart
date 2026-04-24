import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/services/gemini_service.dart';
import '../../../core/utils/similarity_calculator.dart';

/// Kết quả phát âm
class PronunciationResult {
  final String recognizedText;
  final double localScore;
  final Map<String, dynamic>? aiFeedback;
  final bool hasAIFeedback;

  PronunciationResult({
    required this.recognizedText,
    required this.localScore,
    this.aiFeedback,
  }) : hasAIFeedback = aiFeedback != null;

  /// Điểm tổng (ưu tiên AI score nếu có)
  int get score => hasAIFeedback
      ? (aiFeedback!['score'] as num?)?.toInt() ?? (localScore * 100).round()
      : (localScore * 100).round();

  String get generalFeedback =>
      aiFeedback?['general_feedback'] as String? ?? '';

  List<String> get tips =>
      List<String>.from(aiFeedback?['improvement_tips'] ?? []);

  List<Map<String, dynamic>> get errors =>
      List<Map<String, dynamic>>.from(
          aiFeedback?['pronunciation_errors'] ?? []);
}

/// Service kiểm tra phát âm
/// Sử dụng Speech-to-Text + Gemini AI để phân tích và cho feedback
class PronunciationChecker {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final GeminiService _geminiService = GeminiService();

  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';

  // ── Getters ──
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;

  /// Khởi tạo Speech-to-Text
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _stt.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
      onError: (error) {
        _isListening = false;
      },
    );
    return _isInitialized;
  }

  /// Kiểm tra STT có sẵn sàng không
  bool get isAvailable => _stt.isAvailable;

  /// Bắt đầu nghe
  /// [onResult] — callback khi có kết quả real-time
  /// [onFinalResult] — callback khi người dùng ngừng nói
  Future<void> startListening({
    String localeId = 'en_US',
    Duration listenFor = const Duration(seconds: 15),
    Duration pauseFor = const Duration(seconds: 3),
    Function(String)? onResult,
    Function(String)? onFinalResult,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) throw Exception('Không thể khởi tạo microphone');
    }

    _recognizedText = '';
    _isListening = true;

    await _stt.listen(
      onResult: (result) {
        _recognizedText = result.recognizedWords;
        onResult?.call(_recognizedText);

        if (result.finalResult) {
          _isListening = false;
          onFinalResult?.call(_recognizedText);
        }
      },
      localeId: localeId,
      listenFor: listenFor,
      pauseFor: pauseFor,
      listenMode: stt.ListenMode.dictation,
    );
  }

  /// Dừng nghe
  Future<void> stopListening() async {
    await _stt.stop();
    _isListening = false;
  }

  /// Hủy nghe
  Future<void> cancelListening() async {
    await _stt.cancel();
    _isListening = false;
    _recognizedText = '';
  }

  // ═══════════════════════════════════════════
  //  ANALYSIS
  // ═══════════════════════════════════════════

  /// Phân tích phát âm — tính điểm local + gọi AI feedback
  /// [originalText] — câu gốc cần đọc
  /// [recognizedText] — text nhận diện từ STT
  /// [language] — ngôn ngữ (en-US, vi-VN)
  Future<PronunciationResult> analyze({
    required String originalText,
    required String recognizedText,
    String language = 'en-US',
  }) async {
    // 1. Tính điểm similarity local (Levenshtein)
    final localScore = SimilarityCalculator.normalizedSimilarity(
      originalText.toLowerCase(),
      recognizedText.toLowerCase(),
    );

    // 2. Gọi Gemini AI để lấy feedback chi tiết
    Map<String, dynamic>? aiFeedback;
    try {
      aiFeedback = await _geminiService.getPronunciationFeedback(
        originalText: originalText,
        recognizedText: recognizedText,
        language: language,
      );
    } catch (_) {
      // Nếu AI fail, vẫn trả kết quả local
      aiFeedback = {
        'score': (localScore * 100).round(),
        'general_feedback':
            'Điểm tương đồng: ${(localScore * 100).toStringAsFixed(0)}%',
        'improvement_tips': ['Thử đọc chậm và rõ ràng hơn'],
        'pronunciation_errors': [],
      };
    }

    return PronunciationResult(
      recognizedText: recognizedText,
      localScore: localScore,
      aiFeedback: aiFeedback,
    );
  }

  /// Phân tích nhanh chỉ bằng local (không gọi AI)
  PronunciationResult analyzeLocal({
    required String originalText,
    required String recognizedText,
  }) {
    final localScore = SimilarityCalculator.normalizedSimilarity(
      originalText.toLowerCase(),
      recognizedText.toLowerCase(),
    );

    return PronunciationResult(
      recognizedText: recognizedText,
      localScore: localScore,
    );
  }
}
