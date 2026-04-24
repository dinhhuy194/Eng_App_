import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';

/// Reading Screen — Đọc tài liệu + TTS controls
class ReadingScreen extends ConsumerStatefulWidget {
  final String documentId;
  const ReadingScreen({super.key, required this.documentId});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  final FlutterTts _tts = FlutterTts();
  List<Map<String, dynamic>> _chunks = [];
  bool _isLoading = true;
  int _currentChunk = 0;
  bool _isPlaying = false;
  bool _isPaused = false;
  double _speechRate = 0.5;
  double _pitch = 1.0;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadContent();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_pitch);

    _tts.setCompletionHandler(() {
      // Tự động đọc chunk tiếp theo
      if (_currentChunk < _chunks.length - 1) {
        setState(() => _currentChunk++);
        _speak(_chunks[_currentChunk]['text'] ?? '');
      } else {
        setState(() {
          _isPlaying = false;
          _isPaused = false;
        });
      }
    });
  }

  Future<void> _loadContent() async {
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

  Future<void> _speak(String text) async {
    await _tts.speak(text);
    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });
  }

  Future<void> _pause() async {
    await _tts.pause();
    setState(() {
      _isPlaying = false;
      _isPaused = true;
    });
  }

  Future<void> _stop() async {
    await _tts.stop();
    setState(() {
      _isPlaying = false;
      _isPaused = false;
    });
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
        title: const Text('Đọc & Nghe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Chunk info
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppColors.primary.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      Text(
                        'Phần ${_currentChunk + 1}/${_chunks.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      // Previous / Next buttons
                      IconButton(
                        onPressed: _currentChunk > 0
                            ? () {
                                _stop();
                                setState(() => _currentChunk--);
                              }
                            : null,
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: _currentChunk < _chunks.length - 1
                            ? () {
                                _stop();
                                setState(() => _currentChunk++);
                              }
                            : null,
                        icon: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Text content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: SelectableText(
                      _chunks.isNotEmpty
                          ? _chunks[_currentChunk]['text'] ?? ''
                          : 'Không có nội dung',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.8,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),

                // TTS Controls
                _buildTtsControls(),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════
  //  TTS CONTROLS
  // ═══════════════════════════════════════════
  Widget _buildTtsControls() {
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tua lại
            IconButton(
              onPressed: () {
                if (_currentChunk > 0) {
                  _stop();
                  setState(() => _currentChunk--);
                  _speak(_chunks[_currentChunk]['text'] ?? '');
                }
              },
              icon: const Icon(Icons.skip_previous_rounded, size: 32),
            ),
            const SizedBox(width: 16),

            // Play / Pause
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () {
                  if (_isPlaying) {
                    _pause();
                  } else if (_isPaused) {
                    _speak(_chunks[_currentChunk]['text'] ?? '');
                  } else {
                    _speak(_chunks[_currentChunk]['text'] ?? '');
                  }
                },
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Tua tới
            IconButton(
              onPressed: () {
                if (_currentChunk < _chunks.length - 1) {
                  _stop();
                  setState(() => _currentChunk++);
                  _speak(_chunks[_currentChunk]['text'] ?? '');
                }
              },
              icon: const Icon(Icons.skip_next_rounded, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  SETTINGS BOTTOM SHEET
  // ═══════════════════════════════════════════
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Cài đặt giọng đọc',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),

              // Tốc độ
              Row(
                children: [
                  const Icon(Icons.speed_rounded, size: 20),
                  const SizedBox(width: 8),
                  const Text('Tốc độ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${(_speechRate * 2).toStringAsFixed(1)}x'),
                ],
              ),
              Slider(
                value: _speechRate,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                onChanged: (val) {
                  setSheetState(() => _speechRate = val);
                  setState(() => _speechRate = val);
                  _tts.setSpeechRate(val);
                },
              ),

              // Cao độ
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 20),
                  const SizedBox(width: 8),
                  const Text('Cao độ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(_pitch.toStringAsFixed(1)),
                ],
              ),
              Slider(
                value: _pitch,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: (val) {
                  setSheetState(() => _pitch = val);
                  setState(() => _pitch = val);
                  _tts.setPitch(val);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
