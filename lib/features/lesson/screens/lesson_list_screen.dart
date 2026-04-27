import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../models/lesson_model.dart';
import '../providers/lesson_provider.dart';

/// Danh sách bài học từ document
///
/// Flow: Load lessons → Nếu chưa có → Nút "Tạo bài học" → Generate từ chunks
///       Nếu đã có → Hiển thị danh sách với progress
class LessonListScreen extends ConsumerStatefulWidget {
  final String documentId;
  final String documentTitle;

  const LessonListScreen({
    super.key,
    required this.documentId,
    required this.documentTitle,
  });

  @override
  ConsumerState<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends ConsumerState<LessonListScreen> {
  @override
  void initState() {
    super.initState();
    // Load lessons khi vào screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(lessonListProvider(
                  (docId: widget.documentId, title: widget.documentTitle))
              .notifier)
          .loadLessons();
    });
  }

  Future<void> _generateLessons() async {
    final chunks = await FirebaseService().getChunks(widget.documentId);
    if (!mounted) return;

    if (chunks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Tài liệu chưa có nội dung để tạo bài học'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await ref
        .read(lessonListProvider(
                (docId: widget.documentId, title: widget.documentTitle))
            .notifier)
        .generateLessons(chunks);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lessonListProvider(
        (docId: widget.documentId, title: widget.documentTitle)));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📚 Bài học', style: TextStyle(fontSize: 16)),
            Text(
              widget.documentTitle,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (state.lessons.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'reset') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reset tiến độ?'),
                      content: const Text(
                          'Tất cả bài học sẽ quay về trạng thái chưa bắt đầu.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref
                        .read(lessonListProvider((
                          docId: widget.documentId,
                          title: widget.documentTitle
                        )).notifier)
                        .resetAll();
                  }
                } else if (value == 'regenerate') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Tạo lại bài học?'),
                      content: const Text(
                          'Tất cả bài học hiện tại sẽ bị xóa và tạo lại từ đầu.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning),
                          child: const Text('Tạo lại'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref
                        .read(lessonListProvider((
                          docId: widget.documentId,
                          title: widget.documentTitle
                        )).notifier)
                        .deleteAll();
                    await _generateLessons();
                  }
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 18),
                      SizedBox(width: 8),
                      Text('Reset tiến độ'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'regenerate',
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18),
                      SizedBox(width: 8),
                      Text('Tạo lại bài học'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(LessonListState state) {
    switch (state.status) {
      case LessonStatus.idle:
      case LessonStatus.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang tải bài học...'),
            ],
          ),
        );

      case LessonStatus.generating:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Đang tạo bài học...',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Chia nội dung tài liệu thành các bài học',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        );

      case LessonStatus.loaded:
        if (state.lessons.isEmpty) {
          return _buildEmptyState();
        }
        return _buildLessonList(state);

      case LessonStatus.error:
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
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref
                      .read(lessonListProvider((
                        docId: widget.documentId,
                        title: widget.documentTitle
                      )).notifier)
                      .loadLessons(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        );
    }
  }

  // ═══════════════════════════════════════════
  //  EMPTY STATE
  // ═══════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.secondary.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Text('📚', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 24),
            Text(
              'Tạo bài học từ tài liệu',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nội dung sẽ được chia thành các bài học\nngắn gọn, dễ học theo từng bước.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _generateLessons,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Tạo bài học'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  LESSON LIST
  // ═══════════════════════════════════════════
  Widget _buildLessonList(LessonListState state) {
    return Column(
      children: [
        // ── Overall progress bar ──
        _buildOverallProgress(state),

        // ── Lesson items ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.lessons.length,
            itemBuilder: (context, index) =>
                _buildLessonCard(state.lessons[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallProgress(LessonListState state) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tiến độ tổng',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${state.completedCount}/${state.totalCount} bài',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: state.overallProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(state.overallProgress * 100).toInt()}% hoàn thành',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(LessonModel lesson, int index) {
    final isUnlocked = index == 0 ||
        (index > 0 && ref.read(lessonListProvider((
          docId: widget.documentId,
          title: widget.documentTitle,
        ))).lessons[index - 1].progress > 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUnlocked
              ? () => context.push(
                    '/lesson/${lesson.id}',
                    extra: {
                      'documentId': widget.documentId,
                      'title': widget.documentTitle,
                    },
                  )
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: lesson.completed
                    ? AppColors.success.withValues(alpha: 0.3)
                    : isUnlocked
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // ── Index circle ──
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: lesson.completed
                        ? AppColors.success
                        : isUnlocked
                            ? AppColors.primary
                            : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: lesson.completed
                        ? const Icon(Icons.check, color: Colors.white, size: 22)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color:
                                  isUnlocked ? Colors.white : Colors.grey.shade500,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // ── Info ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isUnlocked ? null : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${lesson.totalSteps} phần • ${lesson.statusLabel}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isUnlocked
                              ? AppColors.textSecondaryLight
                              : Colors.grey.shade400,
                        ),
                      ),
                      if (lesson.progress > 0 && !lesson.completed) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: lesson.progress,
                            minHeight: 4,
                            backgroundColor: Colors.grey.shade200,
                            valueColor:
                                const AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Arrow ──
                Icon(
                  isUnlocked
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.lock_outline,
                  size: 16,
                  color: isUnlocked ? AppColors.primary : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
