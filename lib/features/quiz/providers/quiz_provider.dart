import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../shared/models/quiz_model.dart';

/// Trạng thái quiz
enum QuizStatus { idle, generating, playing, completed, error }

class QuizState {
  final QuizStatus status;
  final QuizModel? quiz;
  final int currentIndex;
  final String? errorMessage;
  final DateTime? startTime;

  const QuizState({
    this.status = QuizStatus.idle,
    this.quiz,
    this.currentIndex = 0,
    this.errorMessage,
    this.startTime,
  });

  QuizState copyWith({
    QuizStatus? status,
    QuizModel? quiz,
    int? currentIndex,
    String? errorMessage,
    DateTime? startTime,
  }) {
    return QuizState(
      status: status ?? this.status,
      quiz: quiz ?? this.quiz,
      currentIndex: currentIndex ?? this.currentIndex,
      errorMessage: errorMessage,
      startTime: startTime ?? this.startTime,
    );
  }

  bool get isGenerating => status == QuizStatus.generating;
  bool get isPlaying => status == QuizStatus.playing;
  bool get isCompleted => status == QuizStatus.completed;
  QuizQuestion? get currentQuestion =>
      quiz != null && currentIndex < quiz!.questions.length
          ? quiz!.questions[currentIndex]
          : null;
  bool get isLastQuestion =>
      quiz != null && currentIndex >= quiz!.questions.length - 1;
}

/// Quiz Notifier
class QuizNotifier extends StateNotifier<QuizState> {
  final GeminiService _geminiService = GeminiService();
  final FirebaseService _firebaseService = FirebaseService();

  QuizNotifier() : super(const QuizState());

  /// Tạo quiz mới từ AI
  Future<void> generateQuiz({
    required String documentId,
    required String documentTitle,
    int numQuestions = 10,
    String difficulty = 'mixed',
  }) async {
    try {
      state = state.copyWith(
        status: QuizStatus.generating,
        errorMessage: null,
      );

      final questionsData = await _geminiService.generateQuiz(
        documentId: documentId,
        numQuestions: numQuestions,
        difficulty: difficulty,
      );

      // Convert to QuizQuestion objects
      final questions = questionsData.asMap().entries.map((entry) {
        final q = entry.value;
        q['id'] = 'q_${entry.key}';
        return QuizQuestion.fromMap(q);
      }).toList();

      // Tạo quiz model
      final quiz = QuizModel(
        id: '', // sẽ được set khi lưu Firestore
        documentId: documentId,
        title: 'Quiz: $documentTitle',
        questions: questions,
        difficulty: difficulty,
        createdAt: DateTime.now(),
      );

      // Lưu vào Firestore
      final quizId = await _firebaseService.saveQuiz(quiz.toFirestore());

      state = state.copyWith(
        status: QuizStatus.playing,
        quiz: quiz.copyWith(id: quizId),
        currentIndex: 0,
        startTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        status: QuizStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Chọn đáp án
  void selectAnswer(int answerIndex) {
    if (state.quiz == null) return;

    final questions = List<QuizQuestion>.from(state.quiz!.questions);
    questions[state.currentIndex].selectedIndex = answerIndex;

    state = state.copyWith(
      quiz: state.quiz!.copyWith(questions: questions),
    );
  }

  /// Sang câu tiếp theo
  void nextQuestion() {
    if (state.isLastQuestion) {
      _completeQuiz();
    } else {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  /// Hoàn thành quiz
  Future<void> _completeQuiz() async {
    if (state.quiz == null) return;

    final correctCount =
        state.quiz!.questions.where((q) => q.isCorrect).length;
    final timeSpent = state.startTime != null
        ? DateTime.now().difference(state.startTime!).inSeconds
        : 0;

    // Cập nhật Firestore
    await _firebaseService.updateQuiz(state.quiz!.id, {
      'score': correctCount,
      'completedAt': Timestamp.now(),
      'timeSpentSec': timeSpent,
      'questions':
          state.quiz!.questions.map((q) => q.toMap()).toList(),
    });

    state = state.copyWith(
      status: QuizStatus.completed,
      quiz: state.quiz!.copyWith(
        score: correctCount,
        completedAt: DateTime.now(),
        timeSpentSec: timeSpent,
      ),
    );
  }

  /// Reset để làm lại
  void reset() {
    state = const QuizState();
  }
}

// ── Providers ──

final quizProvider = StateNotifierProvider<QuizNotifier, QuizState>(
  (ref) => QuizNotifier(),
);
