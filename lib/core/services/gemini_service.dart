import 'package:cloud_functions/cloud_functions.dart';
import '../constants/api_constants.dart';

/// Service gọi Cloud Functions (Gemini AI qua backend)
/// Tất cả AI calls đều đi qua Cloud Functions để bảo mật API key
class GeminiService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: ApiConstants.functionsRegion);

  // ── Singleton ──
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  /// Tạo quiz từ tài liệu
  /// [documentId] — ID tài liệu trên Firestore
  /// [numQuestions] — Số câu hỏi (5, 10, 20)
  /// [difficulty] — Độ khó (easy, medium, hard, mixed)
  Future<List<Map<String, dynamic>>> generateQuiz({
    required String documentId,
    int numQuestions = 10,
    String difficulty = 'mixed',
  }) async {
    try {
      final result = await _functions
          .httpsCallable(ApiConstants.generateQuizFunction)
          .call({
        'documentId': documentId,
        'numQuestions': numQuestions,
        'difficulty': difficulty,
      });

      final questions = (result.data['questions'] as List<dynamic>)
          .map((q) => Map<String, dynamic>.from(q as Map))
          .toList();

      return questions;
    } on FirebaseFunctionsException catch (e) {
      throw _handleError(e);
    }
  }

  /// Lấy feedback phát âm từ AI
  /// [originalText] — Text gốc người dùng cần đọc
  /// [recognizedText] — Text từ STT
  /// [language] — Ngôn ngữ (en-US, vi-VN)
  Future<Map<String, dynamic>> getPronunciationFeedback({
    required String originalText,
    required String recognizedText,
    String language = 'en-US',
  }) async {
    try {
      final result = await _functions
          .httpsCallable(ApiConstants.pronunciationFeedbackFunction)
          .call({
        'originalText': originalText,
        'recognizedText': recognizedText,
        'language': language,
      });

      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleError(e);
    }
  }

  /// Hỏi đáp thông minh (RAG) về tài liệu
  /// [question] — Câu hỏi của user
  /// [documentId] — ID tài liệu
  /// [conversationHistory] — Lịch sử hội thoại (tối đa 6 turns)
  Future<Map<String, dynamic>> askQuestion({
    required String question,
    required String documentId,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    try {
      final result = await _functions
          .httpsCallable(ApiConstants.askQuestionFunction)
          .call({
        'question': question,
        'documentId': documentId,
        'conversationHistory': conversationHistory,
      });

      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _handleError(e);
    }
  }

  /// Parse DOCX trên server (nếu cần)
  Future<String> parseDocx(String fileUrl) async {
    try {
      final result = await _functions
          .httpsCallable(ApiConstants.parseDocxFunction)
          .call({'fileUrl': fileUrl});

      return result.data['text'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw _handleError(e);
    }
  }

  /// Xử lý lỗi từ Cloud Functions
  Exception _handleError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'resource-exhausted':
        return Exception('Đã đạt giới hạn sử dụng hôm nay. Thử lại vào ngày mai.');
      case 'unauthenticated':
        return Exception('Vui lòng đăng nhập lại.');
      case 'invalid-argument':
        return Exception('Dữ liệu không hợp lệ: ${e.message}');
      case 'unavailable':
        return Exception('Dịch vụ tạm thời không khả dụng. Thử lại sau.');
      default:
        return Exception('Lỗi: ${e.message ?? 'Không xác định'}');
    }
  }
}
