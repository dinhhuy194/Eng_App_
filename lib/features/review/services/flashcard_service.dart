import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flashcard_model.dart';

/// Service CRUD cho Flashcards trên Firestore
///
/// Firestore path: users/{userId}/flashcards/{cardId}
class FlashcardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Singleton ──
  static final FlashcardService _instance = FlashcardService._internal();
  factory FlashcardService() => _instance;
  FlashcardService._internal();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _flashcardsRef {
    if (_userId == null) throw Exception('Chưa đăng nhập');
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('flashcards');
  }

  // ═══════════════════════════════════════════
  //  CREATE
  // ═══════════════════════════════════════════

  /// Tạo flashcard mới
  Future<String> createFlashcard(FlashcardModel card) async {
    final doc = await _flashcardsRef.add(card.toFirestore());
    return doc.id;
  }

  /// Tạo nhiều flashcards cùng lúc (batch write)
  Future<void> createFlashcards(List<FlashcardModel> cards) async {
    final batch = _firestore.batch();
    for (final card in cards) {
      batch.set(_flashcardsRef.doc(), card.toFirestore());
    }
    await batch.commit();
  }

  /// Tạo flashcard từ câu quiz sai
  Future<String> createFromQuizError({
    required String question,
    required String correctAnswer,
    required String explanation,
    required String quizId,
  }) async {
    final card = FlashcardModel(
      id: '',
      front: question,
      back: '$correctAnswer\n\n💡 $explanation',
      source: FlashcardSource.quiz,
      sourceId: quizId,
      createdAt: DateTime.now(),
      nextReviewAt: DateTime.now(), // ôn ngay
    );
    return createFlashcard(card);
  }

  /// Tạo flashcard từ lỗi phát âm
  Future<String> createFromPronunciationError({
    required String word,
    required String correctIpa,
    required String issue,
  }) async {
    final card = FlashcardModel(
      id: '',
      front: '🎤 Phát âm: $word',
      back: 'IPA: $correctIpa\n\nLỗi: $issue',
      ipa: correctIpa,
      source: FlashcardSource.pronunciation,
      createdAt: DateTime.now(),
      nextReviewAt: DateTime.now(),
    );
    return createFlashcard(card);
  }

  // ═══════════════════════════════════════════
  //  READ
  // ═══════════════════════════════════════════

  /// Lấy tất cả flashcards đến hạn ôn (due now)
  Future<List<FlashcardModel>> getDueFlashcards({int limit = 30}) async {
    final now = Timestamp.fromDate(DateTime.now());
    final snapshot = await _flashcardsRef
        .where('nextReviewAt', isLessThanOrEqualTo: now)
        .orderBy('nextReviewAt')
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => FlashcardModel.fromFirestore(doc))
        .toList();
  }

  /// Lấy tất cả flashcards (stream)
  Stream<List<FlashcardModel>> getAllFlashcardsStream() {
    return _flashcardsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FlashcardModel.fromFirestore(doc))
            .toList());
  }

  /// Lấy flashcards theo nguồn
  Future<List<FlashcardModel>> getFlashcardsBySource(
      FlashcardSource source) async {
    final snapshot = await _flashcardsRef
        .where('source', isEqualTo: source.name)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => FlashcardModel.fromFirestore(doc))
        .toList();
  }

  /// Lấy flashcards theo document
  Future<List<FlashcardModel>> getFlashcardsByDocument(
      String documentId) async {
    final snapshot = await _flashcardsRef
        .where('sourceId', isEqualTo: documentId)
        .where('source', isEqualTo: FlashcardSource.document.name)
        .get();

    return snapshot.docs
        .map((doc) => FlashcardModel.fromFirestore(doc))
        .toList();
  }

  /// Đếm số cards đến hạn ôn
  Future<int> getDueCount() async {
    final now = Timestamp.fromDate(DateTime.now());
    final snapshot = await _flashcardsRef
        .where('nextReviewAt', isLessThanOrEqualTo: now)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Thống kê tổng quan
  Future<Map<String, int>> getStats() async {
    final allDocs = await _flashcardsRef.get();
    final cards =
        allDocs.docs.map((d) => FlashcardModel.fromFirestore(d)).toList();

    int newCount = 0;
    int learningCount = 0;
    int masteredCount = 0;
    int dueCount = 0;

    for (final card in cards) {
      if (card.isNew) {
        newCount++;
      } else if (card.isMastered) {
        masteredCount++;
      } else {
        learningCount++;
      }
      if (card.isDue) dueCount++;
    }

    return {
      'total': cards.length,
      'new': newCount,
      'learning': learningCount,
      'mastered': masteredCount,
      'due': dueCount,
    };
  }

  // ═══════════════════════════════════════════
  //  UPDATE
  // ═══════════════════════════════════════════

  /// Cập nhật flashcard sau khi ôn (apply SM-2 result)
  Future<void> updateAfterReview(FlashcardModel updatedCard) async {
    await _flashcardsRef.doc(updatedCard.id).update(updatedCard.toFirestore());
  }

  /// Cập nhật nội dung flashcard
  Future<void> updateContent(
    String cardId, {
    String? front,
    String? back,
    String? example,
    String? ipa,
  }) async {
    final updates = <String, dynamic>{};
    if (front != null) updates['front'] = front;
    if (back != null) updates['back'] = back;
    if (example != null) updates['example'] = example;
    if (ipa != null) updates['ipa'] = ipa;

    if (updates.isNotEmpty) {
      await _flashcardsRef.doc(cardId).update(updates);
    }
  }

  // ═══════════════════════════════════════════
  //  DELETE
  // ═══════════════════════════════════════════

  /// Xóa flashcard
  Future<void> deleteFlashcard(String cardId) async {
    await _flashcardsRef.doc(cardId).delete();
  }

  /// Xóa tất cả flashcards của một document
  Future<void> deleteByDocument(String documentId) async {
    final snapshot = await _flashcardsRef
        .where('sourceId', isEqualTo: documentId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
