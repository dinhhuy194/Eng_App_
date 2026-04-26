import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/score_badge.dart';
import '../providers/quiz_provider.dart';
import '../../review/services/flashcard_service.dart';

/// Quiz Result Screen — Hiển thị kết quả quiz
class QuizResultScreen extends ConsumerStatefulWidget {
  final String quizId;
  const QuizResultScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  bool _isCreatingFlashcards = false;
  bool _flashcardsCreated = false;
  int _createdCount = 0;

  Future<void> _createFlashcardsFromErrors() async {
    final quizState = ref.read(quizProvider);
    final quiz = quizState.quiz;
    if (quiz == null) return;

    final wrongQuestions = quiz.questions.where((q) => !q.isCorrect && q.isAnswered).toList();
    if (wrongQuestions.isEmpty) return;

    setState(() => _isCreatingFlashcards = true);

    try {
      final service = FlashcardService();
      int count = 0;
      for (final q in wrongQuestions) {
        await service.createFromQuizError(
          question: q.text,
          correctAnswer: q.options[q.correctIndex],
          explanation: q.explanation,
          quizId: widget.quizId,
        );
        count++;
      }
      setState(() {
        _flashcardsCreated = true;
        _createdCount = count;
        _isCreatingFlashcards = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã tạo $count flashcard để ôn tập!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreatingFlashcards = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tạo flashcard: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);
    final quiz = quizState.quiz;

    if (quiz == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Không tìm thấy kết quả')),
      );
    }

    final correctCount =
        quiz.questions.where((q) => q.isCorrect).length;
    final wrongCount = quiz.totalQuestions - correctCount;
    final scorePercent = (correctCount / quiz.totalQuestions * 100);
    final timeMin = (quiz.timeSpentSec ?? 0) ~/ 60;
    final timeSec = (quiz.timeSpentSec ?? 0) % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả Quiz'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            ref.read(quizProvider.notifier).reset();
            context.go('/');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Score Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: scorePercent >= 60
                    ? AppColors.successGradient
                    : const LinearGradient(
                        colors: [Color(0xFFF5576C), Color(0xFFF093FB)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  ScoreBadge(
                    score: scorePercent,
                    size: 100,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    scorePercent >= 80
                        ? 'Xuất sắc!'
                        : scorePercent >= 60
                            ? 'Khá tốt!'
                            : 'Cần cải thiện',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$correctCount/${quiz.totalQuestions} câu đúng',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thời gian: ${timeMin}p ${timeSec}s',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Action Buttons ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(quizProvider.notifier).reset();
                      context.go('/');
                    },
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Trang chủ'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/review'),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Ôn tập'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            // ── Flashcard từ câu sai ──
            if (wrongCount > 0) ...[
              const SizedBox(height: 16),
              _buildFlashcardCTA(wrongCount),
            ],

            const SizedBox(height: 28),

            // ── Review Questions ──
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chi tiết từng câu',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 12),

            ...List.generate(quiz.questions.length, (index) {
              final q = quiz.questions[index];
              return _buildReviewCard(context, index, q);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(
      BuildContext context, int index, dynamic q) {
    final isCorrect = q.isCorrect;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCorrect
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCorrect
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCorrect
                ? Icons.check_rounded
                : Icons.close_rounded,
            color: isCorrect ? AppColors.success : AppColors.error,
            size: 18,
          ),
        ),
        title: Text(
          'Câu ${index + 1}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          q.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          // Đáp án đúng
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đáp án đúng: ${q.options[q.correctIndex]}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Đáp án user chọn (nếu sai)
          if (!isCorrect && q.selectedIndex != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_rounded,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn chọn: ${q.options[q.selectedIndex!]}',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Giải thích
          if (q.explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    q.explanation,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  FLASHCARD CTA
  // ═══════════════════════════════════════════
  Widget _buildFlashcardCTA(int wrongCount) {
    if (_flashcardsCreated) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đã tạo flashcard!',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    '$_createdCount thẻ đã được thêm vào hệ thống ôn tập',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.success.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/review'),
              child: const Text('Ôn ngay'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF5576C).withValues(alpha: 0.08),
            const Color(0xFFF093FB).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF5576C).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5576C).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.style_rounded,
              color: Color(0xFFF5576C),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$wrongCount câu sai → Flashcard',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tạo thẻ ôn tập từ câu trả lời sai',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          _isCreatingFlashcards
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : ElevatedButton(
                  onPressed: _createFlashcardsFromErrors,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5576C),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('Tạo ngay'),
                ),
        ],
      ),
    );
  }
}
