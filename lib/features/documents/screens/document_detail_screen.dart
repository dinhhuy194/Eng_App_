import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';

/// Document Detail — 4 tabs: Đọc, Quiz, Phát âm, Hỏi đáp
class DocumentDetailScreen extends ConsumerStatefulWidget {
  final String documentId;
  final String title;

  const DocumentDetailScreen({
    super.key,
    required this.documentId,
    required this.title,
  });

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _chunks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadChunks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChunks() async {
    try {
      final chunks =
          await FirebaseService().getChunks(widget.documentId);
      setState(() {
        _chunks = chunks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_rounded, size: 20), text: 'Đọc'),
            Tab(icon: Icon(Icons.quiz_rounded, size: 20), text: 'Quiz'),
            Tab(
                icon: Icon(Icons.record_voice_over_rounded, size: 20),
                text: 'Phát âm'),
            Tab(
                icon: Icon(Icons.chat_rounded, size: 20),
                text: 'Hỏi đáp'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Đọc tài liệu
                _buildReadTab(context),

                // Tab 2: Quiz
                _buildQuizTab(context),

                // Tab 3: Phát âm
                _buildPronunciationTab(context),

                // Tab 4: Hỏi đáp AI
                _buildQATab(context),
              ],
            ),
      floatingActionButton: _buildVocabFab(context),
    );
  }

  // ═══════════════════════════════════════════
  //  TAB 1: Đọc tài liệu
  // ═══════════════════════════════════════════
  Widget _buildReadTab(BuildContext context) {
    if (_chunks.isEmpty) {
      return const Center(
        child: Text('Không có nội dung để hiển thị'),
      );
    }

    return Column(
      children: [
        // Header info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.primary.withValues(alpha: 0.05),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_chunks.length} phần • Chạm để nghe TTS',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/reading/${widget.documentId}'),
                    icon: const Icon(Icons.headphones_rounded, size: 18),
                    label: const Text('Nghe'),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ── Quick access: Từ vựng + Học bài + Ôn tập ──
              Row(
                children: [
                  Expanded(
                    child: _buildQuickAccessChip(
                      context,
                      icon: Icons.book_rounded,
                      label: 'Từ vựng',
                      color: const Color(0xFF667EEA),
                      onTap: () => context.push(
                        '/vocabulary?docId=${widget.documentId}&title=${Uri.encodeComponent(widget.title)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickAccessChip(
                      context,
                      icon: Icons.school_rounded,
                      label: 'Học bài',
                      color: const Color(0xFF38B2AC),
                      onTap: () => context.push(
                        '/lessons/${widget.documentId}?title=${Uri.encodeComponent(widget.title)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickAccessChip(
                      context,
                      icon: Icons.replay_rounded,
                      label: 'Ôn tập',
                      color: const Color(0xFFF5576C),
                      onTap: () => context.push('/review'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _chunks.length,
            itemBuilder: (context, index) {
              final chunk = _chunks[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chunk header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Phần ${index + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '~${chunk['tokenCount']} tokens',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Chunk text
                    SelectableText(
                      chunk['text'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  TAB 2: Quiz
  // ═══════════════════════════════════════════
  Widget _buildQuizTab(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF5576C).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.quiz_rounded,
                size: 40,
                color: Color(0xFFF5576C),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tạo trắc nghiệm từ tài liệu',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI sẽ tạo câu hỏi trắc nghiệm\ndựa trên nội dung tài liệu của bạn.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () =>
                  context.push('/quiz/setup/${widget.documentId}'),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Tạo Quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5576C),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  TAB 3: Phát âm
  // ═══════════════════════════════════════════
  Widget _buildPronunciationTab(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF4FACFE).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.record_voice_over_rounded,
                size: 40,
                color: Color(0xFF4FACFE),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Kiểm tra phát âm',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Đọc theo câu trong tài liệu\nvà nhận đánh giá từ AI.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () =>
                  context.push('/pronunciation/${widget.documentId}'),
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Bắt đầu luyện'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FACFE),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  TAB 4: Hỏi đáp AI
  // ═══════════════════════════════════════════
  Widget _buildQATab(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF43E97B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: Color(0xFF43E97B),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Hỏi đáp thông minh',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hỏi bất kỳ câu hỏi nào về\nnội dung tài liệu, AI sẽ trả lời.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () =>
                  context.push('/qa/${widget.documentId}'),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Bắt đầu chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38A169),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  QUICK ACCESS CHIP (Từ vựng / Ôn tập)
  // ═══════════════════════════════════════════
  Widget _buildQuickAccessChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Floating action button cho Vocabulary ──
  Widget? _buildVocabFab(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'vocab_fab',
      backgroundColor: const Color(0xFF667EEA),
      onPressed: () => context.push(
        '/vocabulary?docId=${widget.documentId}&title=${Uri.encodeComponent(widget.title)}',
      ),
      tooltip: 'Từ vựng',
      child: const Icon(Icons.book_rounded, color: Colors.white, size: 20),
    );
  }
}
