import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/quiz_provider.dart';

/// Quiz Setup Screen — Chọn số câu, độ khó trước khi tạo Quiz
class QuizSetupScreen extends ConsumerStatefulWidget {
  final String documentId;
  const QuizSetupScreen({super.key, required this.documentId});

  @override
  ConsumerState<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends ConsumerState<QuizSetupScreen> {
  int _numQuestions = 10;
  String _difficulty = 'mixed';

  final _questionOptions = [5, 10, 15, 20];
  final _difficultyOptions = [
    {'value': 'easy', 'label': 'Dễ', 'icon': '😊', 'color': AppColors.success},
    {'value': 'medium', 'label': 'Trung bình', 'icon': '🤔', 'color': AppColors.warning},
    {'value': 'hard', 'label': 'Khó', 'icon': '🔥', 'color': AppColors.error},
    {'value': 'mixed', 'label': 'Hỗn hợp', 'icon': '🎯', 'color': AppColors.primary},
  ];

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);

    // Khi quiz tạo xong → chuyển sang quiz play
    ref.listen<QuizState>(quizProvider, (prev, next) {
      if (next.isPlaying && next.quiz != null) {
        context.go('/quiz/play/${next.quiz!.id}');
      }
      if (next.status == QuizStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo Quiz')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 44),
                  SizedBox(height: 12),
                  Text(
                    'AI sẽ tạo câu hỏi\ntrắc nghiệm từ tài liệu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Số câu hỏi
            Text(
              'Số câu hỏi',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: _questionOptions.map((count) {
                final isSelected = _numQuestions == count;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _numQuestions = count),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$num',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Độ khó
            Text(
              'Độ khó',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_difficultyOptions.length, (index) {
              final opt = _difficultyOptions[index];
              final isSelected = _difficulty == opt['value'];
              final color = opt['color'] as Color;

              return GestureDetector(
                onTap: () =>
                    setState(() => _difficulty = opt['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.withValues(alpha: 0.15),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(opt['icon'] as String,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 14),
                      Text(
                        opt['label'] as String,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? color
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            color: color, size: 22),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 32),

            // Start button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: quizState.isGenerating
                    ? null
                    : () {
                        ref.read(quizProvider.notifier).generateQuiz(
                              documentId: widget.documentId,
                              documentTitle: 'Tài liệu',
                              numQuestions: _numQuestions,
                              difficulty: _difficulty,
                            );
                      },
                icon: quizState.isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  quizState.isGenerating
                      ? 'Đang tạo quiz...'
                      : 'Bắt đầu Quiz ($_numQuestions câu)',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5576C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
