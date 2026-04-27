import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/api_constants.dart';
import 'firebase_service.dart';

/// Service gọi Gemini AI trực tiếp từ Flutter
/// Không cần Cloud Functions — dùng API key từ .env
class GeminiService {
  late final GenerativeModel _model;
  final FirebaseService _firebaseService = FirebaseService();

  // ── Singleton ──
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal() {
    _model = GenerativeModel(
      model: ApiConstants.geminiModel,
      apiKey: ApiConstants.geminiApiKey,
      generationConfig: GenerationConfig(
        maxOutputTokens: 2048,
        temperature: 0.3,
      ),
    );
  }

  /// Gọi Gemini với prompt và trả về text
  /// Có retry tự động khi bị rate limit
  Future<String> _callGemini(String prompt, {int? maxTokens}) async {
    final model = maxTokens != null
        ? GenerativeModel(
            model: ApiConstants.geminiModel,
            apiKey: ApiConstants.geminiApiKey,
            generationConfig: GenerationConfig(
              maxOutputTokens: maxTokens,
              temperature: 0.3,
            ),
          )
        : _model;

    const maxRetries = 3;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);

        if (response.text == null || response.text!.isEmpty) {
          throw Exception('Gemini không trả về kết quả');
        }

        return response.text!;
      } on GenerativeAIException catch (e) {
        final msg = e.message.toLowerCase();
        final isRateLimit = msg.contains('quota') ||
            msg.contains('rate') ||
            msg.contains('429') ||
            msg.contains('resource_exhausted');

        if (isRateLimit && attempt < maxRetries - 1) {
          // Đợi rồi thử lại: 15s, 30s, 60s
          final waitSeconds = 15 * (attempt + 1);
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }
        throw _handleError(e);
      }
    }
    throw Exception('Không thể kết nối Gemini sau nhiều lần thử.');
  }

  /// Extract JSON từ response (Gemini đôi khi wrap trong markdown)
  String _extractJson(String text) {
    // Thử tìm JSON array
    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
    if (arrayMatch != null) return arrayMatch.group(0)!;

    // Thử tìm JSON object
    final objectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (objectMatch != null) return objectMatch.group(0)!;

    return text;
  }

  // ═══════════════════════════════════════════
  //  PUBLIC API — cho các service khác gọi
  // ═══════════════════════════════════════════

  /// Gọi Gemini AI với prompt tùy chỉnh (public wrapper)
  Future<String> callGeminiRaw(String prompt, {int? maxTokens}) =>
      _callGemini(prompt, maxTokens: maxTokens);

  /// Extract JSON từ response (public wrapper)
  String extractJsonFromResponse(String text) => _extractJson(text);

  // ═══════════════════════════════════════════
  //  GENERATE QUIZ
  // ═══════════════════════════════════════════

  /// Tạo quiz từ tài liệu
  /// [documentId] — ID tài liệu trên Firestore
  /// [numQuestions] — Số câu hỏi (5, 10, 20)
  /// [difficulty] — Độ khó (easy, medium, hard, mixed)
  Future<List<Map<String, dynamic>>> generateQuiz({
    required String documentId,
    int numQuestions = 10,
    String difficulty = 'mixed',
  }) async {
    // Lấy chunks từ Firestore
    final chunks = await _firebaseService.getChunks(documentId);
    if (chunks.isEmpty) {
      throw Exception('Tài liệu chưa được parse. Vui lòng thử lại.');
    }

    // Lấy 3 chunks đầu làm context
    final contextText = chunks
        .take(3)
        .map((c) => c['text'] ?? '')
        .join('\n\n');

    final prompt = '''Từ nội dung sau, tạo $numQuestions câu hỏi trắc nghiệm.
Độ khó: $difficulty. Trả về JSON hợp lệ với format:
[{"question": "...", "options": ["A","B","C","D"],
 "correctIndex": 0, "explanation": "..."}]
Chỉ trả về JSON, không thêm text khác.

Nội dung: $contextText''';

    final response = await _callGemini(prompt, maxTokens: 4096);
    final jsonStr = _extractJson(response);
    final questions = (jsonDecode(jsonStr) as List<dynamic>)
        .map((q) => Map<String, dynamic>.from(q as Map))
        .toList();

    return questions;
  }

  // ═══════════════════════════════════════════
  //  PRONUNCIATION FEEDBACK
  // ═══════════════════════════════════════════

  /// Lấy feedback phát âm từ AI
  /// [originalText] — Text gốc người dùng cần đọc
  /// [recognizedText] — Text từ STT
  /// [language] — Ngôn ngữ (en-US, vi-VN)
  Future<Map<String, dynamic>> getPronunciationFeedback({
    required String originalText,
    required String recognizedText,
    String language = 'en-US',
  }) async {
    final prompt = '''Bạn là giáo viên ngôn ngữ chuyên nghiệp.
Ngôn ngữ: $language
Câu gốc:  "$originalText"
Người dùng nói: "$recognizedText"

Hãy phân tích và cho feedback theo format JSON:
{
  "score": 0-100,
  "pronunciation_errors": [{"word": "...", "issue": "...", "correct_ipa": "..."}],
  "general_feedback": "...",
  "improvement_tips": ["tip1", "tip2"]
}
Chỉ trả về JSON, không thêm text khác.''';

    final response = await _callGemini(prompt);
    final jsonStr = _extractJson(response);
    return Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
  }

  // ═══════════════════════════════════════════
  //  Q&A (RAG)
  // ═══════════════════════════════════════════

  /// Hỏi đáp thông minh (RAG) về tài liệu
  /// [question] — Câu hỏi của user
  /// [documentId] — ID tài liệu
  /// [conversationHistory] — Lịch sử hội thoại (tối đa 6 turns)
  Future<Map<String, dynamic>> askQuestion({
    required String question,
    required String documentId,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    // Lấy chunks từ Firestore
    final chunks = await _firebaseService.getChunks(documentId);
    if (chunks.isEmpty) {
      throw Exception('Tài liệu chưa được parse.');
    }

    // Tìm chunks liên quan
    final relevant = _findRelevantChunks(question, chunks, 3);
    final contextText = relevant.map((c) => c['text'] ?? '').join('\n\n');

    // Build conversation history
    final history = conversationHistory
        .take(6)
        .map((m) => '${m['role']}: ${m['content']}')
        .join('\n');

    final prompt = '''Bạn là trợ lý học tập. Chỉ trả lời dựa trên tài liệu được cung cấp.
Nếu không có đủ thông tin, hãy nói rõ.

TÀI LIỆU:
$contextText

LỊCH SỬ HỘI THOẠI:
$history

CÂU HỎI: $question

Trả lời ngắn gọn, chính xác. Nếu trích dẫn, ghi rõ nguồn.''';

    final answer = await _callGemini(prompt);
    return {
      'answer': answer,
      'sourcesUsed': relevant.map((c) => c['index']).toList(),
    };
  }

  /// Tìm chunks liên quan đến câu hỏi (keyword matching)
  List<Map<String, dynamic>> _findRelevantChunks(
    String question,
    List<Map<String, dynamic>> chunks,
    int topK,
  ) {
    final qWords = question
        .toLowerCase()
        .split(' ')
        .where((w) => w.length > 3)
        .toList();

    final scored = chunks.map((chunk) {
      final text = (chunk['text'] ?? '').toString().toLowerCase();
      final score = qWords.where((w) => text.contains(w)).length;
      return {...chunk, 'score': score};
    }).toList();

    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return scored.take(topK).toList();
  }

  // ═══════════════════════════════════════════
  //  ERROR HANDLING
  // ═══════════════════════════════════════════

  /// Xử lý lỗi từ Gemini API
  Exception _handleError(GenerativeAIException e) {
    final message = e.message.toLowerCase();
    if (message.contains('quota') || message.contains('rate')) {
      return Exception('Đã đạt giới hạn API. Vui lòng thử lại sau.');
    } else if (message.contains('safety')) {
      return Exception('Nội dung không phù hợp. Vui lòng thử với nội dung khác.');
    } else if (message.contains('invalid')) {
      return Exception('API key không hợp lệ. Kiểm tra lại cấu hình.');
    }
    return Exception('Lỗi AI: ${e.message}');
  }
}
