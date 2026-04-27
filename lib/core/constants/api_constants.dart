import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API và cấu hình hằng số cho EduApp
class ApiConstants {
  ApiConstants._();

  // ── Gemini AI ──
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String geminiModel = 'gemini-2.5-flash';

  // ── Chunking Config ──
  static const int maxTokensPerChunk = 1500;
  static const int chunkOverlapWords = 100;

  // ── Rate Limits (hiển thị cho user) ──
  static const int dailyQuizLimit = 20;
  static const int dailyQaLimit = 50;
  static const int dailyPronunciationLimit = 30;

  // ── File Upload ──
  static const int maxFileSizeMB = 20;
  static const int maxFileSizeBytes = maxFileSizeMB * 1024 * 1024;
  static const List<String> supportedFileTypes = ['pdf', 'docx', 'epub'];

  // ── Firestore Collections ──
  static const String usersCollection = 'users';
  static const String documentsSubcollection = 'documents';
  static const String chunksSubcollection = 'chunks';
  static const String quizzesSubcollection = 'quizzes';
  static const String sessionsSubcollection = 'sessions';
  static const String flashcardsSubcollection = 'flashcards';
  static const String vocabularySubcollection = 'vocabulary';
  static const String rateLimitsCollection = 'rateLimits';
  static const String quizCacheCollection = 'quizCache';

  // ── Storage Paths ──
  static String userStoragePath(String userId) => 'users/$userId';
  static String documentStoragePath(String userId, String docId) =>
      'users/$userId/documents/$docId';
}
