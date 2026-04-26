import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/algorithms/sm2_algorithm.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/flashcard_model.dart';
import '../providers/review_provider.dart';

/// Màn hình ôn tập Flashcard — Spaced Repetition
///
/// Flow: Load due cards → Flip card → Rate (4 buttons) → Next → Summary
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();

    // Animation cho lật card
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    // Tự động load due cards
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reviewProvider.notifier).startSession();
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    final state = ref.read(reviewProvider);
    if (state.isFlipped) return;
    _flipController.forward();
    ref.read(reviewProvider.notifier).flipCard();
  }

  Future<void> _rateCard(int quality) async {
    await ref.read(reviewProvider.notifier).rateCard(quality);
    _flipController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 Ôn tập'),
        actions: [
          if (state.status == ReviewStatus.reviewing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${state.currentIndex + 1}/${state.totalCards}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(ReviewState state) {
    switch (state.status) {
      case ReviewStatus.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang tải flashcards...'),
            ],
          ),
        );

      case ReviewStatus.reviewing:
        return _buildReviewContent(state);

      case ReviewStatus.completed:
        if (state.cards.isEmpty) {
          return _buildNoCardsView();
        }
        return _buildCompletedView(state);

      case ReviewStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage ?? 'Đã xảy ra lỗi',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.read(reviewProvider.notifier).startSession(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        );

      case ReviewStatus.idle:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════
  //  REVIEW CONTENT (card + buttons)
  // ═══════════════════════════════════════════

  Widget _buildReviewContent(ReviewState state) {
    final card = state.currentCard;
    if (card == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        children: [
          // ── Progress bar ──
          _buildProgressBar(state),
          const SizedBox(height: AppTheme.spacing24),

          // ── Flashcard (tap to flip) ──
          Expanded(
            child: GestureDetector(
              onTap: _flipCard,
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (context, child) => _buildFlipCard(card, state),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),

          // ── Action area ──
          if (!state.isFlipped)
            _buildTapToFlipHint()
          else
            _buildRatingButtons(),

          const SizedBox(height: AppTheme.spacing16),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ReviewState state) {
    final progress = state.totalCards > 0
        ? (state.currentIndex) / state.totalCards
        : 0.0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '✅ ${state.correctCount} đúng',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              '❌ ${state.reviewedCount - state.correctCount} sai',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlipCard(FlashcardModel card, ReviewState state) {
    final angle = _flipAnimation.value * math.pi;
    final isFrontVisible = angle < math.pi / 2;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // perspective
        ..rotateY(angle),
      child: isFrontVisible
          ? _buildCardFace(
              content: card.front,
              isBack: false,
              card: card,
            )
          : Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: _buildCardFace(
                content: card.back,
                isBack: true,
                card: card,
              ),
            ),
    );
  }

  Widget _buildCardFace({
    required String content,
    required bool isBack,
    required FlashcardModel card,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isBack ? AppColors.successGradient : AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isBack ? AppColors.success : AppColors.primary)
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Badge ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isBack ? '📖 Đáp án' : '❓ Câu hỏi',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Content ──
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),

            // ── IPA (nếu có) ──
            if (card.ipa != null && card.ipa!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '/${card.ipa}/',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // ── Example (nếu có, chỉ mặt sau) ──
            if (isBack && card.example != null && card.example!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '💬 ${card.example}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],

            // ── Status badge (mặt trước) ──
            if (!isBack) ...[
              const SizedBox(height: 16),
              Text(
                '${card.statusEmoji} ${card.statusLabel}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTapToFlipHint() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, color: Colors.grey.shade400, size: 20),
          const SizedBox(width: 8),
          Text(
            'Nhấn card để xem đáp án',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  RATING BUTTONS (4 nút simplified)
  // ═══════════════════════════════════════════

  Widget _buildRatingButtons() {
    final buttons = SM2Algorithm.reviewButtons;

    return Row(
      children: buttons.map((btn) {
        final quality = btn['quality'] as int;
        final label = btn['label'] as String;
        final emoji = btn['emoji'] as String;
        final color = Color(btn['color'] as int);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              onPressed: () => _rateCard(quality),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════
  //  NO CARDS VIEW
  // ═══════════════════════════════════════════

  Widget _buildNoCardsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.secondaryLight,
                shape: BoxShape.circle,
              ),
              child: const Text('🎉', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 24),
            Text(
              'Không có thẻ nào cần ôn!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã ôn xong tất cả. Quay lại sau nhé! 💪',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Quay về'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  COMPLETED VIEW (Summary)
  // ═══════════════════════════════════════════

  Widget _buildCompletedView(ReviewState state) {
    final accuracy = state.accuracy;
    final accColor = accuracy >= 80
        ? AppColors.success
        : accuracy >= 50
            ? AppColors.warning
            : AppColors.error;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Celebration header ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text(
                    'Hoàn thành ôn tập!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bạn đã ôn ${state.reviewedCount} thẻ',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Stats cards ──
            Row(
              children: [
                _buildStatCard(
                  icon: '🎯',
                  label: 'Chính xác',
                  value: '${accuracy.toStringAsFixed(0)}%',
                  color: accColor,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  icon: '✅',
                  label: 'Đúng',
                  value: '${state.correctCount}',
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  icon: '⏱️',
                  label: 'Thời gian',
                  value: _formatTime(state.timeSpentSeconds),
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Actions ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    ref.read(reviewProvider.notifier).startSession(),
                icon: const Icon(Icons.refresh),
                label: const Text('Ôn tiếp'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.home),
                label: const Text('Về trang chính'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min}m ${sec}s';
  }
}
