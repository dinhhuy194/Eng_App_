import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/firebase_service.dart';
import '../models/lesson_model.dart';
import '../services/lesson_service.dart';

/// Lesson Screen — Học step-by-step
///
/// Mỗi step = 1 chunk content
/// Navigation: Previous / Next với auto-save progress
class LessonScreen extends ConsumerStatefulWidget {
  final String lessonId;
  final String documentId;
  final String documentTitle;

  const LessonScreen({
    super.key,
    required this.lessonId,
    required this.documentId,
    required this.documentTitle,
  });

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  final FlutterTts _tts = FlutterTts();
  final PageController _pageController = PageController();
  final LessonService _lessonService = LessonService();

  LessonModel? _lesson;
  List<Map<String, dynamic>> _allChunks = [];
  List<Map<String, dynamic>> _lessonChunks = [];
  bool _isLoading = true;
  int _currentStep = 0;
  bool _isSpeaking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadLesson();
  }

  Future<void> _initTts() async {
    final settings = ref.read(settingsProvider);
    await _tts.setLanguage(settings.ttsLanguage);
    await _tts.setSpeechRate(settings.ttsSpeed);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _loadLesson() async {
    try {
      // 1. Load lesson metadata
      final lesson = await _lessonService.getLesson(widget.lessonId);
      if (lesson == null) {
        setState(() {
          _errorMessage = 'Không tìm thấy bài học';
          _isLoading = false;
        });
        return;
      }

      // 2. Load chunks
      final allChunks =
          await FirebaseService().getChunks(widget.documentId);

      // 3. Lọc chunks thuộc lesson
      final lessonChunks = lesson.chunkIndices
          .where((i) => i < allChunks.length)
          .map((i) => allChunks[i])
          .toList();

      setState(() {
        _lesson = lesson;
        _allChunks = allChunks;
        _lessonChunks = lessonChunks;
        _currentStep = lesson.currentStep.clamp(0, lessonChunks.length - 1);
        _isLoading = false;
      });

      // Jump đến step đã lưu
      if (_currentStep > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.jumpToPage(_currentStep);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi tải bài học: $e';
        _isLoading = false;
      });
    }
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

  Future<void> _goToStep(int step) async {
    if (step < 0 || step >= _lessonChunks.length) return;

    await _tts.stop();
    setState(() {
      _isSpeaking = false;
      _currentStep = step;
    });

    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // Auto-save progress
    await _lessonService.updateProgress(
      widget.lessonId,
      step + 1, // step completed (1-based)
      _lessonChunks.length,
    );
  }

  Future<void> _completeLesson() async {
    await _tts.stop();
    await _lessonService.markCompleted(widget.lessonId);

    if (!mounted) return;

    // Hiện dialog chúc mừng
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Hoàn thành bài học!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã hoàn thành "${_lesson?.title ?? ''}"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Back to lesson list
              },
              child: const Text('Quay về danh sách'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đang tải...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lỗi')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay về'),
              ),
            ],
          ),
        ),
      );
    }

    final isLastStep = _currentStep >= _lessonChunks.length - 1;
    final progress = _lessonChunks.isNotEmpty
        ? (_currentStep + 1) / _lessonChunks.length
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _lesson?.title ?? 'Bài học',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentStep + 1}/${_lessonChunks.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress bar ──
          _buildProgressBar(progress),

          // ── Content pages ──
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lessonChunks.length,
              onPageChanged: (index) {
                setState(() => _currentStep = index);
              },
              itemBuilder: (context, index) =>
                  _buildStepContent(index),
            ),
          ),

          // ── Navigation buttons ──
          _buildNavigation(isLastStep),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  PROGRESS BAR
  // ═══════════════════════════════════════════
  Widget _buildProgressBar(double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
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
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}% hoàn thành',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  STEP CONTENT
  // ═══════════════════════════════════════════
  Widget _buildStepContent(int index) {
    final chunk = _lessonChunks[index];
    final text = chunk['text'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Step header ──
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Phần ${index + 1}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              // TTS button
              IconButton(
                onPressed: () => _speak(text),
                icon: Icon(
                  _isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                  color: AppColors.primary,
                ),
                tooltip: _isSpeaking ? 'Dừng' : 'Nghe',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Content ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: SelectableText(
              text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.8,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Token count badge ──
          if (chunk['tokenCount'] != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '~${chunk['tokenCount']} tokens',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  NAVIGATION
  // ═══════════════════════════════════════════
  Widget _buildNavigation(bool isLastStep) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Previous
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _currentStep > 0 ? () => _goToStep(_currentStep - 1) : null,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Trước'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Next / Complete
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: isLastStep
                    ? _completeLesson
                    : () => _goToStep(_currentStep + 1),
                icon: Icon(
                  isLastStep
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(isLastStep ? 'Hoàn thành' : 'Tiếp theo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isLastStep ? AppColors.success : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
