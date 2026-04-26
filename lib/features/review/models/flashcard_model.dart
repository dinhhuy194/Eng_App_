import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/algorithms/sm2_algorithm.dart';

/// Nguồn tạo flashcard
enum FlashcardSource {
  document, // Trích xuất từ PDF
  quiz, // Từ câu quiz trả lời sai
  pronunciation, // Từ phát âm sai
  manual, // User tự thêm
}

/// Model đại diện cho một Flashcard trong hệ thống Spaced Repetition
class FlashcardModel {
  final String id;
  final String front; // Mặt trước (từ vựng, câu hỏi)
  final String back; // Mặt sau (định nghĩa, đáp án)
  final String? example; // Câu ví dụ (tùy chọn)
  final String? ipa; // Phiên âm IPA (tùy chọn)
  final FlashcardSource source;
  final String? sourceId; // ID tài liệu/quiz/session gốc
  final DateTime createdAt;
  final DateTime? lastReviewedAt;
  final DateTime nextReviewAt;

  // ── SM-2 Parameters ──
  final double easeFactor;
  final int interval; // ngày
  final int repetition; // số lần ôn thành công liên tiếp
  final int lastQuality; // đánh giá lần cuối (0-5)

  // ── Stats ──
  final int totalReviews; // tổng số lần đã ôn
  final int correctReviews; // số lần ôn đúng (quality >= 3)

  const FlashcardModel({
    required this.id,
    required this.front,
    required this.back,
    this.example,
    this.ipa,
    required this.source,
    this.sourceId,
    required this.createdAt,
    this.lastReviewedAt,
    required this.nextReviewAt,
    this.easeFactor = SM2Algorithm.defaultEaseFactor,
    this.interval = 0,
    this.repetition = 0,
    this.lastQuality = 0,
    this.totalReviews = 0,
    this.correctReviews = 0,
  });

  /// Card mới chưa bao giờ ôn?
  bool get isNew => totalReviews == 0;

  /// Card đến hạn ôn?
  bool get isDue => DateTime.now().isAfter(nextReviewAt) ||
      DateTime.now().isAtSameMomentAs(nextReviewAt);

  /// Card đã "thuộc" (ôn >= 3 lần thành công liên tiếp, interval >= 21 ngày)?
  bool get isMastered => repetition >= 3 && interval >= 21;

  /// Card đang học (đã ôn ít nhất 1 lần, chưa thuộc)?
  bool get isLearning => totalReviews > 0 && !isMastered;

  /// Trạng thái hiển thị
  String get statusLabel {
    if (isNew) return 'Mới';
    if (isMastered) return 'Đã thuộc';
    return 'Đang học';
  }

  /// Emoji trạng thái
  String get statusEmoji {
    if (isNew) return '🔴';
    if (isMastered) return '🟢';
    return '🟡';
  }

  /// Tỷ lệ đúng (%)
  double get accuracy =>
      totalReviews > 0 ? (correctReviews / totalReviews) * 100 : 0;

  /// Áp dụng kết quả SM-2 sau khi ôn
  FlashcardModel applyReview(int quality) {
    final result = SM2Algorithm.calculate(
      quality: quality,
      repetition: repetition,
      easeFactor: easeFactor,
      interval: interval,
    );

    return copyWith(
      easeFactor: result.easeFactor,
      interval: result.interval,
      repetition: result.repetition,
      nextReviewAt: result.nextReviewAt,
      lastReviewedAt: DateTime.now(),
      lastQuality: quality,
      totalReviews: totalReviews + 1,
      correctReviews: quality >= 3 ? correctReviews + 1 : correctReviews,
    );
  }

  // ═══════════════════════════════════════════
  //  FIRESTORE SERIALIZATION
  // ═══════════════════════════════════════════

  factory FlashcardModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FlashcardModel(
      id: doc.id,
      front: data['front'] ?? '',
      back: data['back'] ?? '',
      example: data['example'],
      ipa: data['ipa'],
      source: _parseSource(data['source'] ?? 'manual'),
      sourceId: data['sourceId'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastReviewedAt: (data['lastReviewedAt'] as Timestamp?)?.toDate(),
      nextReviewAt:
          (data['nextReviewAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      easeFactor:
          (data['easeFactor'] as num?)?.toDouble() ?? SM2Algorithm.defaultEaseFactor,
      interval: data['interval'] ?? 0,
      repetition: data['repetition'] ?? 0,
      lastQuality: data['lastQuality'] ?? 0,
      totalReviews: data['totalReviews'] ?? 0,
      correctReviews: data['correctReviews'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'front': front,
      'back': back,
      if (example != null) 'example': example,
      if (ipa != null) 'ipa': ipa,
      'source': source.name,
      if (sourceId != null) 'sourceId': sourceId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastReviewedAt != null)
        'lastReviewedAt': Timestamp.fromDate(lastReviewedAt!),
      'nextReviewAt': Timestamp.fromDate(nextReviewAt),
      'easeFactor': easeFactor,
      'interval': interval,
      'repetition': repetition,
      'lastQuality': lastQuality,
      'totalReviews': totalReviews,
      'correctReviews': correctReviews,
    };
  }

  static FlashcardSource _parseSource(String value) {
    switch (value) {
      case 'document':
        return FlashcardSource.document;
      case 'quiz':
        return FlashcardSource.quiz;
      case 'pronunciation':
        return FlashcardSource.pronunciation;
      default:
        return FlashcardSource.manual;
    }
  }

  // ═══════════════════════════════════════════
  //  COPY WITH
  // ═══════════════════════════════════════════

  FlashcardModel copyWith({
    String? id,
    String? front,
    String? back,
    String? example,
    String? ipa,
    FlashcardSource? source,
    String? sourceId,
    DateTime? createdAt,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    double? easeFactor,
    int? interval,
    int? repetition,
    int? lastQuality,
    int? totalReviews,
    int? correctReviews,
  }) {
    return FlashcardModel(
      id: id ?? this.id,
      front: front ?? this.front,
      back: back ?? this.back,
      example: example ?? this.example,
      ipa: ipa ?? this.ipa,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      createdAt: createdAt ?? this.createdAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      repetition: repetition ?? this.repetition,
      lastQuality: lastQuality ?? this.lastQuality,
      totalReviews: totalReviews ?? this.totalReviews,
      correctReviews: correctReviews ?? this.correctReviews,
    );
  }
}
