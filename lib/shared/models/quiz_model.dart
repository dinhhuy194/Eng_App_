import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một bài quiz
class QuizModel {
  final String id;
  final String documentId;
  final String title;
  final List<QuizQuestion> questions;
  final int? score;
  final DateTime? completedAt;
  final int? timeSpentSec;
  final String difficulty; // easy, medium, hard, mixed
  final DateTime createdAt;

  const QuizModel({
    required this.id,
    required this.documentId,
    required this.title,
    required this.questions,
    this.score,
    this.completedAt,
    this.timeSpentSec,
    this.difficulty = 'mixed',
    required this.createdAt,
  });

  factory QuizModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuizModel(
      id: doc.id,
      documentId: data['documentId'] ?? '',
      title: data['title'] ?? '',
      questions: (data['questions'] as List<dynamic>?)
              ?.map((q) => QuizQuestion.fromMap(q as Map<String, dynamic>))
              .toList() ??
          [],
      score: data['score'],
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      timeSpentSec: data['timeSpentSec'],
      difficulty: data['difficulty'] ?? 'mixed',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'documentId': documentId,
      'title': title,
      'questions': questions.map((q) => q.toMap()).toList(),
      'score': score,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'timeSpentSec': timeSpentSec,
      'difficulty': difficulty,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  QuizModel copyWith({
    String? id,
    String? documentId,
    String? title,
    List<QuizQuestion>? questions,
    int? score,
    DateTime? completedAt,
    int? timeSpentSec,
    String? difficulty,
    DateTime? createdAt,
  }) {
    return QuizModel(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      title: title ?? this.title,
      questions: questions ?? this.questions,
      score: score ?? this.score,
      completedAt: completedAt ?? this.completedAt,
      timeSpentSec: timeSpentSec ?? this.timeSpentSec,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isCompleted => completedAt != null;
  int get totalQuestions => questions.length;
  double get scorePercent =>
      score != null ? (score! / totalQuestions * 100) : 0;
}

/// Model cho một câu hỏi quiz
class QuizQuestion {
  final String id;
  final String text;
  final String type; // multiple_choice, true_false, fill_blank
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String difficulty; // easy, medium, hard
  int? selectedIndex; // Đáp án người dùng chọn

  QuizQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.difficulty = 'medium',
    this.selectedIndex,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      id: map['id'] ?? '',
      text: map['question'] ?? map['text'] ?? '',
      type: map['type'] ?? 'multiple_choice',
      options: List<String>.from(map['options'] ?? []),
      correctIndex: map['correctIndex'] ?? 0,
      explanation: map['explanation'] ?? '',
      difficulty: map['difficulty'] ?? 'medium',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'type': type,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
      'difficulty': difficulty,
    };
  }

  bool get isAnswered => selectedIndex != null;
  bool get isCorrect => selectedIndex == correctIndex;
}
