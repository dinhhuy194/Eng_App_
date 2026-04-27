import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/word_model.dart';
import '../../review/models/flashcard_model.dart';
import '../../review/services/flashcard_service.dart';

/// Service CRUD cho Vocabulary trên Firestore
///
/// Firestore path: users/{userId}/vocabulary/{wordId}
class VocabularyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlashcardService _flashcardService = FlashcardService();

  // ── Singleton ──
  static final VocabularyService _instance = VocabularyService._internal();
  factory VocabularyService() => _instance;
  VocabularyService._internal();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _vocabRef {
    if (_userId == null) throw Exception('Chưa đăng nhập');
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('vocabulary');
  }

  // ═══════════════════════════════════════════
  //  CREATE
  // ═══════════════════════════════════════════

  /// Thêm một từ vựng mới + tự động tạo flashcard
  Future<WordModel> addWord(WordModel word) async {
    // Kiểm tra trùng
    final existing = await _vocabRef
        .where('word', isEqualTo: word.word.toLowerCase().trim())
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Từ đã tồn tại, trả về từ hiện có
      return WordModel.fromFirestore(existing.docs.first);
    }

    // Tạo flashcard liên kết
    final flashcardId = await _flashcardService.createFlashcard(
      FlashcardModel(
        id: '',
        front: word.word,
        back: '${word.definitionVi}\n\n📗 ${word.definitionEn}',
        example: word.exampleSentence,
        ipa: word.ipa,
        source: FlashcardSource.document,
        sourceId: word.sourceDocId,
        createdAt: DateTime.now(),
        nextReviewAt: DateTime.now(),
      ),
    );

    // Lưu từ vựng với flashcard ID
    final wordWithFlashcard = word.copyWith(
      word: word.word.toLowerCase().trim(),
      flashcardId: flashcardId,
    );
    final doc = await _vocabRef.add(wordWithFlashcard.toFirestore());

    return wordWithFlashcard.copyWith(id: doc.id);
  }

  /// Thêm nhiều từ vựng (batch) — dùng khi Gemini extract
  Future<List<WordModel>> addWords(List<WordModel> words) async {
    final results = <WordModel>[];
    for (final word in words) {
      try {
        final result = await addWord(word);
        results.add(result);
      } catch (_) {
        // Bỏ qua từ lỗi, tiếp tục từ tiếp theo
        continue;
      }
    }
    return results;
  }

  // ═══════════════════════════════════════════
  //  READ
  // ═══════════════════════════════════════════

  /// Stream tất cả từ vựng (realtime)
  Stream<List<WordModel>> getAllWordsStream() {
    return _vocabRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WordModel.fromFirestore(doc))
            .toList());
  }

  /// Lấy từ vựng theo document ID
  Stream<List<WordModel>> getWordsByDocumentStream(String documentId) {
    return _vocabRef
        .where('sourceDocId', isEqualTo: documentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WordModel.fromFirestore(doc))
            .toList());
  }

  /// Lấy từ vựng theo trạng thái
  Future<List<WordModel>> getWordsByStatus(WordStatus status) async {
    final statusValue = status.name == 'newWord' ? 'new' : status.name;
    final snapshot = await _vocabRef
        .where('status', isEqualTo: statusValue)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => WordModel.fromFirestore(doc))
        .toList();
  }

  /// Tìm kiếm từ vựng
  Future<List<WordModel>> searchWords(String query) async {
    if (query.trim().isEmpty) return [];

    final queryLower = query.toLowerCase().trim();

    // Firestore không hỗ trợ full-text search → query client-side
    final snapshot = await _vocabRef.get();
    final allWords = snapshot.docs
        .map((doc) => WordModel.fromFirestore(doc))
        .toList();

    return allWords.where((w) {
      return w.word.contains(queryLower) ||
          w.definitionVi.toLowerCase().contains(queryLower) ||
          w.definitionEn.toLowerCase().contains(queryLower);
    }).toList();
  }

  /// Thống kê
  Future<Map<String, int>> getStats() async {
    final snapshot = await _vocabRef.get();
    final words =
        snapshot.docs.map((d) => WordModel.fromFirestore(d)).toList();

    return {
      'total': words.length,
      'new': words.where((w) => w.status == WordStatus.newWord).length,
      'learning': words.where((w) => w.status == WordStatus.learning).length,
      'mastered': words.where((w) => w.status == WordStatus.mastered).length,
    };
  }

  // ═══════════════════════════════════════════
  //  UPDATE
  // ═══════════════════════════════════════════

  /// Cập nhật trạng thái từ
  Future<void> updateStatus(String wordId, WordStatus status) async {
    final statusValue = status.name == 'newWord' ? 'new' : status.name;
    await _vocabRef.doc(wordId).update({'status': statusValue});
  }

  /// Đồng bộ status từ vựng dựa trên kết quả review flashcard
  ///
  /// Quy tắc:
  /// - repetitions == 0 → newWord
  /// - interval < 7 ngày → learning
  /// - interval >= 7 ngày → mastered
  Future<void> syncStatusFromFlashcard({
    required String flashcardId,
    required int repetitions,
    required int interval,
  }) async {
    try {
      // Tìm word liên kết với flashcard
      final snapshot = await _vocabRef
          .where('flashcardId', isEqualTo: flashcardId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return;

      final wordDoc = snapshot.docs.first;
      WordStatus newStatus;

      if (repetitions == 0) {
        newStatus = WordStatus.newWord;
      } else if (interval >= 7) {
        newStatus = WordStatus.mastered;
      } else {
        newStatus = WordStatus.learning;
      }

      final statusValue = newStatus.name == 'newWord' ? 'new' : newStatus.name;
      await wordDoc.reference.update({'status': statusValue});
    } catch (_) {
      // Không block nếu sync fail
    }
  }

  /// Cập nhật nội dung từ
  Future<void> updateWord(String wordId, Map<String, dynamic> data) async {
    await _vocabRef.doc(wordId).update(data);
  }

  // ═══════════════════════════════════════════
  //  DELETE
  // ═══════════════════════════════════════════

  /// Xóa từ vựng + flashcard liên kết
  Future<void> deleteWord(WordModel word) async {
    // Xóa flashcard liên kết
    if (word.hasFlashcard) {
      try {
        await _flashcardService.deleteFlashcard(word.flashcardId!);
      } catch (_) {}
    }
    await _vocabRef.doc(word.id).delete();
  }

  /// Xóa tất cả từ của một document
  Future<void> deleteByDocument(String documentId) async {
    final snapshot = await _vocabRef
        .where('sourceDocId', isEqualTo: documentId)
        .get();

    for (final doc in snapshot.docs) {
      final word = WordModel.fromFirestore(doc);
      await deleteWord(word);
    }
  }
}
