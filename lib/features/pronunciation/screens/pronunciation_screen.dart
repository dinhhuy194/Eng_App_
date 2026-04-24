import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/utils/similarity_calculator.dart';

/// Pronunciation Screen — Luyện phát âm
class PronunciationScreen extends ConsumerStatefulWidget {
  final String documentId;
  const PronunciationScreen({super.key, required this.documentId});

  @override
  ConsumerState<PronunciationScreen> createState() =>
      _PronunciationScreenState();
}

class _PronunciationScreenState extends ConsumerState<PronunciationScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();
  final GeminiService _geminiService = GeminiService();

  List<String> _sentences = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isListening = false;
  bool _isAnalyzing = false;
  String _recognizedText = '';
  Map<String, dynamic>? _feedback;
  double? _localScore;

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadSentences();
  }

  Future<void> _initServices() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.4);
    await _stt.initialize();
  }

  Future<void> _loadSentences() async {
    try {
      final chunks =
          await FirebaseService().getChunks(widget.documentId);
      final List<String> sentences = [];

      for (final chunk in chunks) {
        final text = chunk['text'] as String? ?? '';
        // Trích câu từ text
        final extracted = text
            .split(RegExp(r'[.!?]+'))
            .map((s) => s.trim())
            .where((s) => s.length >= 10 && s.length <= 120)
            .toList();
        sentences.addAll(extracted);
      }

      setState(() {
        _sentences = sentences.take(50).toList(); // Tối đa 50 câu
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _listenSpeech() async {
    if (!_stt.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone không khả dụng'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _feedback = null;
      _localScore = null;
    });

    await _stt.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });
        if (result.finalResult) {
          _analyzePronunciation();
        }
      },
      localeId: 'en_US',
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    setState(() => _isListening = false);
    if (_recognizedText.isNotEmpty) {
      _analyzePronunciation();
    }
  }

  Future<void> _analyzePronunciation() async {
    setState(() {
      _isListening = false;
      _isAnalyzing = true;
    });

    final original = _sentences[_currentIndex];

    // 1. Tính điểm local bằng Levenshtein
    _localScore = SimilarityCalculator.normalizedSimilarity(
      original.toLowerCase(),
      _recognizedText.toLowerCase(),
    );

    // 2. Gọi Cloud Function cho AI feedback
    try {
      final result = await _geminiService.getPronunciationFeedback(
        originalText: original,
        recognizedText: _recognizedText,
      );
      setState(() {
        _feedback = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _feedback = {
          'score': (_localScore! * 100).round(),
          'general_feedback': 'Điểm tương đồng: ${(_localScore! * 100).toStringAsFixed(0)}%',
          'improvement_tips': ['Thử đọc chậm và rõ ràng hơn'],
        };
        _isAnalyzing = false;
      });
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện phát âm'),
        actions: [
          if (_sentences.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentIndex + 1}/${_sentences.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sentences.isEmpty
              ? const Center(
                  child: Text('Không tìm thấy câu phù hợp để luyện'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Câu gốc
                      _buildOriginalSentence(),
                      const SizedBox(height: 24),

                      // Mic button
                      _buildMicButton(),
                      const SizedBox(height: 20),

                      // Recognized text
                      if (_recognizedText.isNotEmpty)
                        _buildRecognizedText(),

                      // Feedback
                      if (_isAnalyzing)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        ),

                      if (_feedback != null) _buildFeedbackCard(),

                      const SizedBox(height: 20),

                      // Navigation
                      _buildNavigation(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOriginalSentence() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.volume_up_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Đọc câu sau:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () =>
                    _tts.speak(_sentences[_currentIndex]),
                icon: const Icon(Icons.play_circle_rounded,
                    color: AppColors.primary, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _sentences[_currentIndex],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return Center(
      child: GestureDetector(
        onTap: _isListening ? _stopListening : _listenSpeech,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isListening ? 100 : 80,
          height: _isListening ? 100 : 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _isListening
                ? const LinearGradient(
                    colors: [Color(0xFFF5576C), Color(0xFFF093FB)])
                : const LinearGradient(
                    colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)]),
            boxShadow: [
              BoxShadow(
                color: (_isListening
                        ? const Color(0xFFF5576C)
                        : const Color(0xFF4FACFE))
                    .withValues(alpha: 0.4),
                blurRadius: _isListening ? 24 : 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            _isListening ? Icons.stop_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: _isListening ? 44 : 36,
          ),
        ),
      ),
    );
  }

  Widget _buildRecognizedText() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mic_rounded, size: 18, color: AppColors.secondary),
              SizedBox(width: 6),
              Text(
                'Bạn đã nói:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _recognizedText,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard() {
    final score = _feedback?['score'] ?? 0;
    final generalFeedback =
        _feedback?['general_feedback'] ?? '';
    final tips =
        List<String>.from(_feedback?['improvement_tips'] ?? []);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: score >= 70
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: score >= 70
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color:
                          score >= 70 ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      score >= 80
                          ? 'Xuất sắc! 🎉'
                          : score >= 60
                              ? 'Khá tốt! 👍'
                              : 'Cần luyện thêm 💪',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (generalFeedback.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        generalFeedback,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Tips
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '💡 Gợi ý cải thiện:',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(
                          tip,
                          style:
                              const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _currentIndex > 0
                ? () {
                    setState(() {
                      _currentIndex--;
                      _recognizedText = '';
                      _feedback = null;
                      _localScore = null;
                    });
                  }
                : null,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Câu trước'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _currentIndex < _sentences.length - 1
                ? () {
                    setState(() {
                      _currentIndex++;
                      _recognizedText = '';
                      _feedback = null;
                      _localScore = null;
                    });
                  }
                : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Câu tiếp'),
          ),
        ),
      ],
    );
  }
}
