import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/word_model.dart';
import '../providers/vocabulary_provider.dart';

/// Màn hình chi tiết từ vựng
///
/// Hiển thị: word, IPA, definition VN/EN, example, status, source
/// TTS: Phát âm từ vựng + ví dụ
class WordDetailScreen extends ConsumerStatefulWidget {
  final WordModel word;

  const WordDetailScreen({super.key, required this.word});

  @override
  ConsumerState<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends ConsumerState<WordDetailScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  WordModel get word => widget.word;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    // Đọc settings từ SettingsProvider (persistent)
    final settings = ref.read(settingsProvider);
    await _tts.setLanguage(settings.ttsLanguage);
    await _tts.setSpeechRate(settings.ttsSpeed);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(word.word),
        actions: [
          IconButton(
            onPressed: () => _confirmDelete(),
            icon: const Icon(Icons.delete_outline),
            color: AppColors.error,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Word header ──
            _buildWordHeader(context),
            const SizedBox(height: 24),

            // ── Definitions ──
            _buildDefinitionSection(context),
            const SizedBox(height: 20),

            // ── Example ──
            if (word.exampleSentence != null &&
                word.exampleSentence!.isNotEmpty) ...[
              _buildExampleSection(context),
              const SizedBox(height: 20),
            ],

            // ── Source ──
            if (word.sourceDocTitle != null) ...[
              _buildSourceSection(context),
              const SizedBox(height: 20),
            ],

            // ── Status ──
            _buildStatusSection(context),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  WORD HEADER
  // ═══════════════════════════════════════════

  Widget _buildWordHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
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
          // ── Status badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${word.statusEmoji} ${word.statusLabel}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Word ──
          Text(
            word.word,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),

          // ── IPA ──
          if (word.ipa != null && word.ipa!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              word.ipa!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 18,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── TTS Speak button ──
          GestureDetector(
            onTap: () => _speak(word.word),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSpeaking
                        ? Icons.stop_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isSpeaking ? 'Dừng' : 'Phát âm',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Flashcard indicator ──
          if (word.hasFlashcard)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.style, color: Colors.white70, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Đã liên kết Flashcard',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  DEFINITIONS
  // ═══════════════════════════════════════════

  Widget _buildDefinitionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '📖 Định nghĩa'),
        const SizedBox(height: 12),

        // Vietnamese
        _buildDefinitionCard(
          context,
          flag: '🇻🇳',
          label: 'Tiếng Việt',
          definition: word.definitionVi,
          color: AppColors.secondary,
        ),
        const SizedBox(height: 8),

        // English
        if (word.definitionEn.isNotEmpty)
          _buildDefinitionCard(
            context,
            flag: '🇬🇧',
            label: 'English',
            definition: word.definitionEn,
            color: AppColors.primary,
          ),
      ],
    );
  }

  Widget _buildDefinitionCard(
    BuildContext context, {
    required String flag,
    required String label,
    required String definition,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$flag $label',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            definition,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  EXAMPLE
  // ═══════════════════════════════════════════

  Widget _buildExampleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '💬 Ví dụ'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  word.exampleSentence!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _speak(word.exampleSentence!),
                icon: const Icon(Icons.volume_up_rounded),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppColors.warning,
                tooltip: 'Nghe ví dụ',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  SOURCE
  // ═══════════════════════════════════════════

  Widget _buildSourceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '📄 Nguồn'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.description, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  word.sourceDocTitle!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  STATUS
  // ═══════════════════════════════════════════

  Widget _buildStatusSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '📊 Trạng thái'),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatusChip(
              '🔴 Mới',
              word.status == WordStatus.newWord,
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              '🟡 Đang học',
              word.status == WordStatus.learning,
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              '🟢 Đã thuộc',
              word.status == WordStatus.mastered,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? AppColors.primary
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? AppColors.primary : Colors.grey,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa từ vựng?'),
        content: Text('Bạn có chắc muốn xóa "${word.word}"?\n'
            'Flashcard liên kết cũng sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(vocabularyProvider.notifier).deleteWord(word);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
