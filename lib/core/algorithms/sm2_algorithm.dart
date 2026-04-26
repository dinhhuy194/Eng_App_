import 'dart:math';

/// Kết quả sau khi tính SM-2
class SM2Result {
  final double easeFactor;
  final int interval;
  final int repetition;
  final DateTime nextReviewAt;

  const SM2Result({
    required this.easeFactor,
    required this.interval,
    required this.repetition,
    required this.nextReviewAt,
  });

  @override
  String toString() =>
      'SM2Result(ef=$easeFactor, interval=$interval, rep=$repetition, next=$nextReviewAt)';
}

/// Thuật toán SM-2 (SuperMemo 2) cho Spaced Repetition
///
/// Dựa trên paper gốc của Piotr Wozniak (1990).
/// Anki, Mnemosyne và nhiều app khác dùng biến thể của SM-2.
///
/// Quality scale:
/// - 0: Hoàn toàn quên ("Blackout")
/// - 1: Sai hoàn toàn nhưng nhận ra khi thấy đáp án
/// - 2: Sai nhưng nhớ mang máng
/// - 3: Đúng nhưng rất khó nhớ
/// - 4: Đúng, hơi khó
/// - 5: Đúng, rất dễ nhớ
class SM2Algorithm {
  SM2Algorithm._();

  /// Ease factor tối thiểu (ngưỡng sàn để card không quá dày đặc)
  static const double _minEaseFactor = 1.3;

  /// Ease factor mặc định cho card mới
  static const double defaultEaseFactor = 2.5;

  /// Tính toán lịch ôn tập tiếp theo dựa trên SM-2
  ///
  /// [quality] — Đánh giá của user (0-5)
  /// [repetition] — Số lần ôn thành công liên tiếp trước đó
  /// [easeFactor] — Ease factor hiện tại
  /// [interval] — Khoảng cách ôn trước đó (ngày)
  static SM2Result calculate({
    required int quality,
    required int repetition,
    required double easeFactor,
    required int interval,
  }) {
    assert(quality >= 0 && quality <= 5, 'Quality phải từ 0 đến 5');

    int newRepetition;
    int newInterval;
    double newEaseFactor;

    if (quality >= 3) {
      // ── Trả lời đúng (quality >= 3) ──
      switch (repetition) {
        case 0:
          newInterval = 1; // Lần đầu: ôn lại sau 1 ngày
          break;
        case 1:
          newInterval = 6; // Lần 2: ôn lại sau 6 ngày
          break;
        default:
          // Lần 3+: interval * easeFactor
          newInterval = (interval * easeFactor).round();
          break;
      }
      newRepetition = repetition + 1;
    } else {
      // ── Trả lời sai (quality < 3) ──
      // Reset: học lại từ đầu
      newRepetition = 0;
      newInterval = 1;
    }

    // ── Cập nhật Ease Factor ──
    // Công thức gốc SM-2:
    // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    newEaseFactor = easeFactor +
        (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));

    // Không để EF xuống dưới ngưỡng sàn
    newEaseFactor = max(_minEaseFactor, newEaseFactor);

    // Tính ngày ôn tập tiếp theo
    final now = DateTime.now();
    final nextReview = DateTime(now.year, now.month, now.day)
        .add(Duration(days: newInterval));

    return SM2Result(
      easeFactor: double.parse(newEaseFactor.toStringAsFixed(2)),
      interval: newInterval,
      repetition: newRepetition,
      nextReviewAt: nextReview,
    );
  }

  /// Tiện ích: Chuyển quality number thành label tiếng Việt
  static String qualityLabel(int quality) {
    switch (quality) {
      case 0:
        return 'Quên hoàn toàn';
      case 1:
        return 'Sai, nhận ra khi xem đáp án';
      case 2:
        return 'Sai, nhớ mang máng';
      case 3:
        return 'Đúng nhưng rất khó';
      case 4:
        return 'Đúng, hơi khó';
      case 5:
        return 'Quá dễ';
      default:
        return 'Không xác định';
    }
  }

  /// Tiện ích: Chuyển quality thành emoji
  static String qualityEmoji(int quality) {
    switch (quality) {
      case 0:
      case 1:
        return '😰';
      case 2:
        return '😕';
      case 3:
        return '🤔';
      case 4:
        return '😊';
      case 5:
        return '🤩';
      default:
        return '❓';
    }
  }

  /// Simplified buttons cho UI (4 nút thay vì 6)
  /// Trả về danh sách [quality, label, emoji, color_hex]
  static List<Map<String, dynamic>> get reviewButtons => [
        {
          'quality': 1,
          'label': 'Quên',
          'emoji': '😰',
          'color': 0xFFE53E3E,
        },
        {
          'quality': 3,
          'label': 'Khó',
          'emoji': '🤔',
          'color': 0xFFED8936,
        },
        {
          'quality': 4,
          'label': 'Tốt',
          'emoji': '😊',
          'color': 0xFF38A169,
        },
        {
          'quality': 5,
          'label': 'Dễ',
          'emoji': '🤩',
          'color': 0xFF3182CE,
        },
      ];
}
