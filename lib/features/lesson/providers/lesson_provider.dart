import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lesson_model.dart';
import '../services/lesson_service.dart';

/// Trạng thái Lesson
enum LessonStatus { idle, loading, loaded, generating, error }

class LessonListState {
  final LessonStatus status;
  final List<LessonModel> lessons;
  final String? errorMessage;

  const LessonListState({
    this.status = LessonStatus.idle,
    this.lessons = const [],
    this.errorMessage,
  });

  LessonListState copyWith({
    LessonStatus? status,
    List<LessonModel>? lessons,
    String? errorMessage,
  }) {
    return LessonListState(
      status: status ?? this.status,
      lessons: lessons ?? this.lessons,
      errorMessage: errorMessage,
    );
  }

  int get completedCount => lessons.where((l) => l.completed).length;
  int get totalCount => lessons.length;
  double get overallProgress {
    if (lessons.isEmpty) return 0.0;
    return lessons.fold(0.0, (sum, l) => sum + l.progress) / lessons.length;
  }
}

/// Notifier quản lý danh sách lessons cho 1 document
class LessonListNotifier extends StateNotifier<LessonListState> {
  final LessonService _service = LessonService();
  final String documentId;
  final String documentTitle;

  LessonListNotifier({
    required this.documentId,
    required this.documentTitle,
  }) : super(const LessonListState());

  /// Load lessons từ Firestore (listen stream)
  void loadLessons() {
    state = state.copyWith(status: LessonStatus.loading);

    _service.getLessonsForDocument(documentId).listen(
      (lessons) {
        state = LessonListState(
          status: LessonStatus.loaded,
          lessons: lessons,
        );
      },
      onError: (e) {
        state = state.copyWith(
          status: LessonStatus.error,
          errorMessage: 'Không thể tải bài học: $e',
        );
      },
    );
  }

  /// Tạo lessons từ document chunks
  Future<void> generateLessons(List<Map<String, dynamic>> chunks) async {
    state = state.copyWith(status: LessonStatus.generating);
    try {
      await _service.generateLessonsFromDocument(
        documentId: documentId,
        documentTitle: documentTitle,
        chunks: chunks,
      );
      // Stream sẽ tự cập nhật state
      debugPrint('📚 [LessonProvider] Generate thành công');
    } catch (e) {
      state = state.copyWith(
        status: LessonStatus.error,
        errorMessage: 'Không thể tạo bài học: $e',
      );
    }
  }

  /// Cập nhật progress cho lesson cụ thể
  Future<void> updateProgress(String lessonId, int currentStep, int totalSteps) async {
    await _service.updateProgress(lessonId, currentStep, totalSteps);
  }

  /// Reset tất cả lessons
  Future<void> resetAll() async {
    for (final lesson in state.lessons) {
      await _service.resetProgress(lesson.id);
    }
  }

  /// Xóa tất cả lessons
  Future<void> deleteAll() async {
    await _service.deleteLessonsForDocument(documentId);
  }
}

/// Provider factory — mỗi document có 1 provider riêng
final lessonListProvider = StateNotifierProvider.family<
    LessonListNotifier, LessonListState, ({String docId, String title})>(
  (ref, params) => LessonListNotifier(
    documentId: params.docId,
    documentTitle: params.title,
  ),
);
