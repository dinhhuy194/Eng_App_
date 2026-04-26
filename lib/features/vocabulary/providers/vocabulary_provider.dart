import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/firebase_service.dart';
import '../models/word_model.dart';
import '../services/vocabulary_service.dart';

/// Trạng thái extraction
enum ExtractStatus { idle, extracting, saving, done, error }

/// State cho Vocabulary feature
class VocabularyState {
  final List<WordModel> words;
  final ExtractStatus extractStatus;
  final String? errorMessage;
  final String searchQuery;
  final String? filterDocId; // null = show all

  const VocabularyState({
    this.words = const [],
    this.extractStatus = ExtractStatus.idle,
    this.errorMessage,
    this.searchQuery = '',
    this.filterDocId,
  });

  VocabularyState copyWith({
    List<WordModel>? words,
    ExtractStatus? extractStatus,
    String? errorMessage,
    String? searchQuery,
    String? filterDocId,
    bool clearFilter = false,
  }) {
    return VocabularyState(
      words: words ?? this.words,
      extractStatus: extractStatus ?? this.extractStatus,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      filterDocId: clearFilter ? null : (filterDocId ?? this.filterDocId),
    );
  }

  /// Filtered & searched words
  List<WordModel> get filteredWords {
    var result = words;

    // Filter by document
    if (filterDocId != null) {
      result = result.where((w) => w.sourceDocId == filterDocId).toList();
    }

    // Filter by search
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((w) {
        return w.word.contains(q) ||
            w.definitionVi.toLowerCase().contains(q) ||
            w.definitionEn.toLowerCase().contains(q);
      }).toList();
    }

    return result;
  }

  /// Stats
  int get totalCount => words.length;
  int get newCount =>
      words.where((w) => w.status == WordStatus.newWord).length;
  int get learningCount =>
      words.where((w) => w.status == WordStatus.learning).length;
  int get masteredCount =>
      words.where((w) => w.status == WordStatus.mastered).length;
}

/// Vocabulary Notifier — quản lý từ vựng + AI extraction
class VocabularyNotifier extends StateNotifier<VocabularyState> {
  final VocabularyService _vocabService = VocabularyService();
  final GeminiService _geminiService = GeminiService();
  final FirebaseService _firebaseService = FirebaseService();

  VocabularyNotifier() : super(const VocabularyState());

  /// Subscribe stream từ Firestore
  void listenToWords() {
    _vocabService.getAllWordsStream().listen(
      (words) {
        state = state.copyWith(words: words);
      },
      onError: (e) {
        state = state.copyWith(
          errorMessage: 'Lỗi tải từ vựng: $e',
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  //  AI EXTRACTION — Core Feature
  // ═══════════════════════════════════════════

  /// Trích xuất từ vựng từ tài liệu bằng Gemini AI
  ///
  /// Flow: getChunks → Gemini prompt → parse JSON → save words + flashcards
  Future<int> extractFromDocument({
    required String documentId,
    required String documentTitle,
    int maxWords = 20,
  }) async {
    try {
      state = state.copyWith(
        extractStatus: ExtractStatus.extracting,
        errorMessage: null,
      );

      // 1. Lấy chunks từ Firestore
      final chunks = await _firebaseService.getChunks(documentId);
      if (chunks.isEmpty) {
        throw Exception('Tài liệu chưa được parse.');
      }

      // 2. Lấy tối đa 5 chunks làm context (đủ phong phú)
      final contextText = chunks
          .take(5)
          .map((c) => c['text'] ?? '')
          .join('\n\n');

      // 3. Gọi Gemini AI extract từ vựng
      final extractedWords = await _extractVocabulary(
        contextText,
        maxWords: maxWords,
      );

      if (extractedWords.isEmpty) {
        state = state.copyWith(extractStatus: ExtractStatus.done);
        return 0;
      }

      // 4. Chuyển thành WordModel và lưu
      state = state.copyWith(extractStatus: ExtractStatus.saving);

      final wordModels = extractedWords.map((w) => WordModel(
            id: '',
            word: (w['word'] ?? '').toString().toLowerCase().trim(),
            definitionVi: (w['definition_vi'] ?? '').toString(),
            definitionEn: (w['definition_en'] ?? '').toString(),
            ipa: w['ipa']?.toString(),
            exampleSentence: w['example_sentence']?.toString(),
            sourceDocId: documentId,
            sourceDocTitle: documentTitle,
            createdAt: DateTime.now(),
          )).toList();

      final saved = await _vocabService.addWords(wordModels);

      state = state.copyWith(extractStatus: ExtractStatus.done);
      return saved.length;
    } catch (e) {
      state = state.copyWith(
        extractStatus: ExtractStatus.error,
        errorMessage: e.toString(),
      );
      return 0;
    }
  }

  /// Gọi Gemini để trích xuất từ vựng
  Future<List<Map<String, dynamic>>> _extractVocabulary(
    String text, {
    int maxWords = 20,
  }) async {
    final prompt = '''Bạn là giáo viên tiếng Anh chuyên nghiệp.
Từ đoạn text sau, hãy trích xuất $maxWords từ vựng tiếng Anh quan trọng nhất
mà người Việt học tiếng Anh cần biết.

Ưu tiên: từ vựng học thuật, từ khó, cụm từ quan trọng.
Bỏ qua: từ quá đơn giản (the, is, a, etc.)

Trả về JSON array duy nhất, KHÔNG thêm text khác:
[
  {
    "word": "sophisticated",
    "definition_vi": "tinh vi, phức tạp",
    "definition_en": "highly developed and complex",
    "ipa": "/səˈfɪstɪkeɪtɪd/",
    "example_sentence": "She has sophisticated taste in art."
  }
]

ĐẠT TEXT:
$text''';

    final response = await _geminiService.callGeminiRaw(prompt, maxTokens: 4096);
    final jsonStr = _geminiService.extractJsonFromResponse(response);
    final parsed = jsonDecode(jsonStr) as List<dynamic>;
    return parsed
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  // ═══════════════════════════════════════════
  //  MANUAL ADD
  // ═══════════════════════════════════════════

  /// User tự thêm từ vựng
  Future<WordModel?> addManualWord({
    required String word,
    required String definitionVi,
    String definitionEn = '',
    String? ipa,
    String? exampleSentence,
  }) async {
    try {
      final model = WordModel(
        id: '',
        word: word.toLowerCase().trim(),
        definitionVi: definitionVi,
        definitionEn: definitionEn,
        ipa: ipa,
        exampleSentence: exampleSentence,
        createdAt: DateTime.now(),
      );
      return await _vocabService.addWord(model);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Không thể thêm từ: $e',
      );
      return null;
    }
  }

  // ═══════════════════════════════════════════
  //  SEARCH & FILTER
  // ═══════════════════════════════════════════

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilterDocId(String? docId) {
    if (docId == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterDocId: docId);
    }
  }

  // ═══════════════════════════════════════════
  //  DELETE
  // ═══════════════════════════════════════════

  Future<void> deleteWord(WordModel word) async {
    try {
      await _vocabService.deleteWord(word);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Không thể xóa từ: $e',
      );
    }
  }
}

// ═══════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════

final vocabularyProvider =
    StateNotifierProvider<VocabularyNotifier, VocabularyState>(
  (ref) {
    final notifier = VocabularyNotifier();
    notifier.listenToWords();
    return notifier;
  },
);

/// Stats provider
final vocabStatsProvider = FutureProvider<Map<String, int>>((ref) {
  return VocabularyService().getStats();
});
