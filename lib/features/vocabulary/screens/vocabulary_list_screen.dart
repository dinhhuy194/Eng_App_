import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/word_model.dart';
import '../providers/vocabulary_provider.dart';
import 'word_detail_screen.dart';

/// Màn hình danh sách từ vựng
///
/// Features: search, filter by status, stats summary, pull-to-refresh
class VocabularyListScreen extends ConsumerStatefulWidget {
  final String? documentId;
  final String? documentTitle;

  const VocabularyListScreen({
    super.key,
    this.documentId,
    this.documentTitle,
  });

  @override
  ConsumerState<VocabularyListScreen> createState() =>
      _VocabularyListScreenState();
}

class _VocabularyListScreenState extends ConsumerState<VocabularyListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    if (widget.documentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(vocabularyProvider.notifier)
            .setFilterDocId(widget.documentId);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _extractVocabulary() async {
    if (widget.documentId == null) return;
    setState(() => _isExtracting = true);

    final count =
        await ref.read(vocabularyProvider.notifier).extractFromDocument(
              documentId: widget.documentId!,
              documentTitle: widget.documentTitle ?? 'Tài liệu',
            );

    setState(() => _isExtracting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? '✅ Đã trích xuất $count từ vựng mới!'
                : '📝 Không tìm thấy từ vựng mới.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              count > 0 ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  void _showAddWordDialog() {
    final wordCtrl = TextEditingController();
    final viCtrl = TextEditingController();
    final enCtrl = TextEditingController();
    final ipaCtrl = TextEditingController();
    final exCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.bottomSheetRadius)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '➕ Thêm từ vựng',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: wordCtrl,
              decoration: const InputDecoration(
                labelText: 'Từ vựng *',
                hintText: 'vd: sophisticated',
              ),
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: viCtrl,
              decoration: const InputDecoration(
                labelText: 'Nghĩa tiếng Việt *',
                hintText: 'vd: tinh vi, phức tạp',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: enCtrl,
              decoration: const InputDecoration(
                labelText: 'Nghĩa tiếng Anh',
                hintText: 'vd: highly developed and complex',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ipaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'IPA',
                      hintText: '/səˈfɪs../',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: exCtrl,
              decoration: const InputDecoration(
                labelText: 'Câu ví dụ',
                hintText: 'vd: She has sophisticated taste.',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (wordCtrl.text.trim().isEmpty ||
                      viCtrl.text.trim().isEmpty) {
                    return;
                  }
                  await ref
                      .read(vocabularyProvider.notifier)
                      .addManualWord(
                        word: wordCtrl.text,
                        definitionVi: viCtrl.text,
                        definitionEn: enCtrl.text,
                        ipa: ipaCtrl.text.isEmpty ? null : ipaCtrl.text,
                        exampleSentence:
                            exCtrl.text.isEmpty ? null : exCtrl.text,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Thêm từ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vocabState = ref.watch(vocabularyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.documentTitle != null
            ? '📝 ${widget.documentTitle}'
            : '📝 Từ vựng'),
        actions: [
          if (widget.documentId != null)
            IconButton(
              onPressed: _isExtracting ? null : _extractVocabulary,
              icon: _isExtracting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              tooltip: 'Trích xuất từ vựng bằng AI',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Stats bar ──
          _buildStatsBar(vocabState),

          // ── Search bar ──
          _buildSearchBar(),

          // ── Word list ──
          Expanded(
            child: vocabState.filteredWords.isEmpty
                ? _buildEmptyState(vocabState)
                : _buildWordList(vocabState.filteredWords),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWordDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  STATS BAR
  // ═══════════════════════════════════════════

  Widget _buildStatsBar(VocabularyState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('📚', '${state.totalCount}', 'Tổng'),
          _buildStatItem('🔴', '${state.newCount}', 'Mới'),
          _buildStatItem('🟡', '${state.learningCount}', 'Đang học'),
          _buildStatItem('🟢', '${state.masteredCount}', 'Thuộc'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text('$emoji $value',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  SEARCH BAR
  // ═══════════════════════════════════════════

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm từ vựng...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(vocabularyProvider.notifier)
                        .setSearchQuery('');
                  },
                )
              : null,
        ),
        onChanged: (value) {
          ref.read(vocabularyProvider.notifier).setSearchQuery(value);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  WORD LIST
  // ═══════════════════════════════════════════

  Widget _buildWordList(List<WordModel> words) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index];
        return _buildWordCard(word);
      },
    );
  }

  Widget _buildWordCard(WordModel word) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WordDetailScreen(word: word),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Status emoji ──
              Text(word.statusEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),

              // ── Word info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.word,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      word.definitionVi,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondaryLight,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (word.ipa != null && word.ipa!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        word.ipa!,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Source badge ──
              if (word.sourceDocTitle != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '📄',
                    style: TextStyle(fontSize: 12),
                  ),
                ),

              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  EMPTY STATE
  // ═══════════════════════════════════════════

  Widget _buildEmptyState(VocabularyState state) {
    final hasFilter =
        state.searchQuery.isNotEmpty || state.filterDocId != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hasFilter ? '🔍' : '📝',
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? 'Không tìm thấy từ vựng phù hợp'
                  : 'Chưa có từ vựng nào',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Thử từ khóa khác'
                  : 'Nhấn ✨ để trích xuất từ PDF\nhoặc + để thêm thủ công',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
