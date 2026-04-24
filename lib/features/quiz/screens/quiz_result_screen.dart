import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/score_badge.dart';
import '../providers/quiz_provider.dart';

/// Quiz Result Screen — Hiển thị kết quả quiz
class QuizResultScreen extends ConsumerWidget {
  final String quizId;
  const QuizResultScreen({super.key, required this.quizId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    onPressed: () {
                      // Xem chi tiết từng câu bên dưới
                    },
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('Xem đáp án'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

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
}
