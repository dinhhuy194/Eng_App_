import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/quiz_provider.dart';

/// Quiz Play Screen — Làm quiz, chọn đáp án
class QuizPlayScreen extends ConsumerWidget {
  final String quizId;
  const QuizPlayScreen({super.key, required this.quizId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(quizProvider);

    // Khi hoàn thành → chuyển sang result
    ref.listen<QuizState>(quizProvider, (prev, next) {
      if (next.isCompleted && next.quiz != null) {
        context.go('/quiz/result/${next.quiz!.id}');
      }
    });

    if (quizState.quiz == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Không tìm thấy quiz')),
      );
    }

    final quiz = quizState.quiz!;
    final question = quizState.currentQuestion;
    if (question == null) return const SizedBox.shrink();

    final progress =
        (quizState.currentIndex + 1) / quiz.questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Câu ${quizState.currentIndex + 1}/${quiz.totalQuestions}',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _showQuitDialog(context, ref),
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 4,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Difficulty badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(question.difficulty)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getDifficultyLabel(question.difficulty),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getDifficultyColor(question.difficulty),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Question text
                  Text(
                    question.text,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Options
                  ...List.generate(question.options.length, (index) {
                    return _buildOption(
                      context,
                      ref,
                      index: index,
                      text: question.options[index],
                      isSelected: question.selectedIndex == index,
                      isAnswered: question.isAnswered,
                      isCorrect: index == question.correctIndex,
                    );
                  }),
                ],
              ),
            ),
          ),

          // Bottom button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: question.isAnswered
                    ? () => ref.read(quizProvider.notifier).nextQuestion()
                    : null,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  quizState.isLastQuestion ? 'Xem kết quả' : 'Câu tiếp theo',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    WidgetRef ref, {
    required int index,
    required String text,
    required bool isSelected,
    required bool isAnswered,
    required bool isCorrect,
  }) {
    Color bgColor;
    Color borderColor;
    IconData? trailingIcon;

    if (isAnswered) {
      if (isCorrect) {
        bgColor = AppColors.success.withValues(alpha: 0.1);
        borderColor = AppColors.success;
        trailingIcon = Icons.check_circle_rounded;
      } else if (isSelected) {
        bgColor = AppColors.error.withValues(alpha: 0.1);
        borderColor = AppColors.error;
        trailingIcon = Icons.cancel_rounded;
      } else {
        bgColor = Theme.of(context).colorScheme.surface;
        borderColor = Colors.grey.withValues(alpha: 0.15);
      }
    } else {
      bgColor = isSelected
          ? AppColors.primary.withValues(alpha: 0.08)
          : Theme.of(context).colorScheme.surface;
      borderColor = isSelected
          ? AppColors.primary
          : Colors.grey.withValues(alpha: 0.2);
    }

    final labels = ['A', 'B', 'C', 'D'];

    return GestureDetector(
      onTap: isAnswered
          ? null
          : () => ref.read(quizProvider.notifier).selectAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            // Label circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected && !isAnswered
                    ? AppColors.primary
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isSelected && !isAnswered
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Option text
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),

            // Result icon
            if (trailingIcon != null)
              Icon(
                trailingIcon,
                color: isCorrect ? AppColors.success : AppColors.error,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  void _showQuitDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thoát Quiz?'),
        content: const Text('Tiến trình sẽ không được lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tiếp tục làm'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(quizProvider.notifier).reset();
              context.go('/');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String diff) {
    switch (diff) {
      case 'easy': return AppColors.success;
      case 'hard': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  String _getDifficultyLabel(String diff) {
    switch (diff) {
      case 'easy': return '😊 Dễ';
      case 'hard': return '🔥 Khó';
      default: return '🤔 Trung bình';
    }
  }
}
