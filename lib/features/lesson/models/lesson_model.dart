import 'package:cloud_firestore/cloud_firestore.dart';

/// LessonModel — Bài học được chia từ document
///
/// Mỗi lesson = một nhóm chunks liên tiếp từ document
/// Firestore path: users/{uid}/lessons/{lessonId}
class LessonModel {
  final String id;
  final String documentId;
  final String documentTitle;
  final String title;
  final int lessonIndex;       // Thứ tự lesson trong document
  final List<int> chunkIndices; // Các index chunk thuộc lesson này
  final int totalSteps;
  final int currentStep;       // Step hiện tại (0-based)
  final double progress;       // 0.0 → 1.0
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;

  const LessonModel({
    required this.id,
    required this.documentId,
    required this.documentTitle,
    required this.title,
    required this.lessonIndex,
    required this.chunkIndices,
    required this.totalSteps,
    this.currentStep = 0,
    this.progress = 0.0,
    this.completed = false,
    required this.createdAt,
    this.completedAt,
  });

  /// Từ Firestore document
  factory LessonModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LessonModel(
      id: doc.id,
      documentId: data['documentId'] ?? '',
      documentTitle: data['documentTitle'] ?? '',
      title: data['title'] ?? '',
      lessonIndex: data['lessonIndex'] ?? 0,
      chunkIndices: List<int>.from(data['chunkIndices'] ?? []),
      totalSteps: data['totalSteps'] ?? 0,
      currentStep: data['currentStep'] ?? 0,
      progress: (data['progress'] ?? 0.0).toDouble(),
      completed: data['completed'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Chuyển thành Map để lưu Firestore
  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'documentTitle': documentTitle,
      'title': title,
      'lessonIndex': lessonIndex,
      'chunkIndices': chunkIndices,
      'totalSteps': totalSteps,
      'currentStep': currentStep,
      'progress': progress,
      'completed': completed,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
    };
  }

  LessonModel copyWith({
    int? currentStep,
    double? progress,
    bool? completed,
    DateTime? completedAt,
  }) {
    return LessonModel(
      id: id,
      documentId: documentId,
      documentTitle: documentTitle,
      title: title,
      lessonIndex: lessonIndex,
      chunkIndices: chunkIndices,
      totalSteps: totalSteps,
      currentStep: currentStep ?? this.currentStep,
      progress: progress ?? this.progress,
      completed: completed ?? this.completed,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Emoji trạng thái
  String get statusEmoji {
    if (completed) return '✅';
    if (progress > 0) return '📖';
    return '📝';
  }

  String get statusLabel {
    if (completed) return 'Hoàn thành';
    if (progress > 0) return 'Đang học (${(progress * 100).toInt()}%)';
    return 'Chưa bắt đầu';
  }
}
