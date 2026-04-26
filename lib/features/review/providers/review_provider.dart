import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flashcard_model.dart';
import '../services/flashcard_service.dart';

/// Trạng thái review session
enum ReviewStatus { idle, loading, reviewing, completed, error }

/// Trạng thái của một phiên ôn tập
class ReviewState {
  final ReviewStatus status;
  final List<FlashcardModel> cards; // Danh sách cards cần ôn
  final int currentIndex;
  final bool isFlipped; // Card đang lật?
  final String? errorMessage;

  // ── Session stats ──
  final int reviewedCount;
  final int correctCount; // quality >= 3
  final DateTime? sessionStartTime;

  const ReviewState({
    this.status = ReviewStatus.idle,
    this.cards = const [],
    this.currentIndex = 0,
    this.isFlipped = false,
    this.errorMessage,
    this.reviewedCount = 0,
    this.correctCount = 0,
    this.sessionStartTime,
  });

  ReviewState copyWith({
    ReviewStatus? status,
    List<FlashcardModel>? cards,
    int? currentIndex,
    bool? isFlipped,
    String? errorMessage,
    int? reviewedCount,
    int? correctCount,
    DateTime? sessionStartTime,
  }) {
    return ReviewState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      currentIndex: currentIndex ?? this.currentIndex,
      isFlipped: isFlipped ?? this.isFlipped,
      errorMessage: errorMessage,
      reviewedCount: reviewedCount ?? this.reviewedCount,
      correctCount: correctCount ?? this.correctCount,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
    );
  }

  /// Card hiện tại
  FlashcardModel? get currentCard =>
      cards.isNotEmpty && currentIndex < cards.length
          ? cards[currentIndex]
          : null;

  /// Đây là card cuối cùng?
  bool get isLastCard => currentIndex >= cards.length - 1;

  /// Tổng số cards trong session
  int get totalCards => cards.length;

  /// Tỷ lệ đúng (%)
  double get accuracy =>
      reviewedCount > 0 ? (correctCount / reviewedCount) * 100 : 0;

  /// Thời gian ôn (giây)
  int get timeSpentSeconds => sessionStartTime != null
      ? DateTime.now().difference(sessionStartTime!).inSeconds
      : 0;
}

/// Review Notifier — Quản lý phiên ôn tập
class ReviewNotifier extends StateNotifier<ReviewState> {
  final FlashcardService _flashcardService = FlashcardService();

  ReviewNotifier() : super(const ReviewState());

  /// Bắt đầu phiên ôn tập mới
  /// Load tất cả cards đến hạn (due)
  Future<void> startSession({int maxCards = 30}) async {
    try {
      state = state.copyWith(
        status: ReviewStatus.loading,
        errorMessage: null,
      );

      final dueCards =
          await _flashcardService.getDueFlashcards(limit: maxCards);

      if (dueCards.isEmpty) {
        state = state.copyWith(
          status: ReviewStatus.completed,
          cards: [],
          reviewedCount: 0,
          correctCount: 0,
        );
        return;
      }

      state = ReviewState(
        status: ReviewStatus.reviewing,
        cards: dueCards,
        currentIndex: 0,
        isFlipped: false,
        sessionStartTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        status: ReviewStatus.error,
        errorMessage: 'Không thể tải flashcards: ${e.toString()}',
      );
    }
  }

  /// Lật card (xem mặt sau)
  void flipCard() {
    state = state.copyWith(isFlipped: true);
  }

  /// User đánh giá card và chuyển sang card tiếp theo
  /// [quality] — 0-5 (SM-2 quality rating)
  Future<void> rateCard(int quality) async {
    final currentCard = state.currentCard;
    if (currentCard == null) return;

    try {
      // Apply SM-2 algorithm
      final updatedCard = currentCard.applyReview(quality);

      // Lưu kết quả lên Firestore
      await _flashcardService.updateAfterReview(updatedCard);

      // Cập nhật card trong danh sách local
      final updatedCards = List<FlashcardModel>.from(state.cards);
      updatedCards[state.currentIndex] = updatedCard;

      final newReviewedCount = state.reviewedCount + 1;
      final newCorrectCount =
          quality >= 3 ? state.correctCount + 1 : state.correctCount;

      if (state.isLastCard) {
        // Hoàn thành session
        state = state.copyWith(
          status: ReviewStatus.completed,
          cards: updatedCards,
          reviewedCount: newReviewedCount,
          correctCount: newCorrectCount,
          isFlipped: false,
        );
      } else {
        // Sang card tiếp theo
        state = state.copyWith(
          cards: updatedCards,
          currentIndex: state.currentIndex + 1,
          isFlipped: false,
          reviewedCount: newReviewedCount,
          correctCount: newCorrectCount,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: ReviewStatus.error,
        errorMessage: 'Lỗi lưu kết quả: ${e.toString()}',
      );
    }
  }

  /// Reset về trạng thái idle
  void reset() {
    state = const ReviewState();
  }
}

// ═══════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════

/// Provider chính cho review session
final reviewProvider =
    StateNotifierProvider<ReviewNotifier, ReviewState>(
  (ref) => ReviewNotifier(),
);

/// Stream tất cả flashcards
final allFlashcardsProvider = StreamProvider<List<FlashcardModel>>((ref) {
  return FlashcardService().getAllFlashcardsStream();
});

/// Số cards đến hạn ôn
final dueCountProvider = FutureProvider<int>((ref) {
  return FlashcardService().getDueCount();
});

/// Thống kê flashcards
final flashcardStatsProvider = FutureProvider<Map<String, int>>((ref) {
  return FlashcardService().getStats();
});
