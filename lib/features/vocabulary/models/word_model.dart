import 'package:cloud_firestore/cloud_firestore.dart';

/// Trạng thái học từ vựng (liên kết với SM-2 status)
enum WordStatus {
  newWord,   // 🔴 Mới, chưa bao giờ ôn
  learning,  // 🟡 Đang học
  mastered,  // 🟢 Đã thuộc
}

/// Model đại diện cho một từ vựng trong Vocabulary Builder
///
/// Firestore path: users/{userId}/vocabulary/{wordId}
class WordModel {
  final String id;
  final String word;
  final String definitionVi;   // Nghĩa tiếng Việt
  final String definitionEn;   // Nghĩa tiếng Anh
  final String? ipa;           // Phiên âm IPA
  final String? exampleSentence;
  final String? sourceDocId;   // ID tài liệu gốc
  final String? sourceDocTitle;
  final String? flashcardId;   // ID flashcard liên kết
  final WordStatus status;
  final DateTime createdAt;

  const WordModel({
    required this.id,
    required this.word,
    required this.definitionVi,
    required this.definitionEn,
    this.ipa,
    this.exampleSentence,
    this.sourceDocId,
    this.sourceDocTitle,
    this.flashcardId,
    this.status = WordStatus.newWord,
    required this.createdAt,
  });

  // ═══════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════

  String get statusEmoji {
    switch (status) {
      case WordStatus.newWord:
        return '🔴';
      case WordStatus.learning:
        return '🟡';
      case WordStatus.mastered:
        return '🟢';
    }
  }

  String get statusLabel {
    switch (status) {
      case WordStatus.newWord:
        return 'Mới';
      case WordStatus.learning:
        return 'Đang học';
      case WordStatus.mastered:
        return 'Đã thuộc';
    }
  }

  bool get hasFlashcard => flashcardId != null && flashcardId!.isNotEmpty;

  // ═══════════════════════════════════════════
  //  FIRESTORE SERIALIZATION
  // ═══════════════════════════════════════════

  factory WordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WordModel(
      id: doc.id,
      word: data['word'] ?? '',
      definitionVi: data['definitionVi'] ?? '',
      definitionEn: data['definitionEn'] ?? '',
      ipa: data['ipa'],
      exampleSentence: data['exampleSentence'],
      sourceDocId: data['sourceDocId'],
      sourceDocTitle: data['sourceDocTitle'],
      flashcardId: data['flashcardId'],
      status: _parseStatus(data['status'] ?? 'new'),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'word': word,
      'definitionVi': definitionVi,
      'definitionEn': definitionEn,
      if (ipa != null) 'ipa': ipa,
      if (exampleSentence != null) 'exampleSentence': exampleSentence,
      if (sourceDocId != null) 'sourceDocId': sourceDocId,
      if (sourceDocTitle != null) 'sourceDocTitle': sourceDocTitle,
      if (flashcardId != null) 'flashcardId': flashcardId,
      'status': status.name == 'newWord' ? 'new' : status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static WordStatus _parseStatus(String value) {
    switch (value) {
      case 'learning':
        return WordStatus.learning;
      case 'mastered':
        return WordStatus.mastered;
      default:
        return WordStatus.newWord;
    }
  }

  // ═══════════════════════════════════════════
  //  COPY WITH
  // ═══════════════════════════════════════════

  WordModel copyWith({
    String? id,
    String? word,
    String? definitionVi,
    String? definitionEn,
    String? ipa,
    String? exampleSentence,
    String? sourceDocId,
    String? sourceDocTitle,
    String? flashcardId,
    WordStatus? status,
    DateTime? createdAt,
  }) {
    return WordModel(
      id: id ?? this.id,
      word: word ?? this.word,
      definitionVi: definitionVi ?? this.definitionVi,
      definitionEn: definitionEn ?? this.definitionEn,
      ipa: ipa ?? this.ipa,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      sourceDocId: sourceDocId ?? this.sourceDocId,
      sourceDocTitle: sourceDocTitle ?? this.sourceDocTitle,
      flashcardId: flashcardId ?? this.flashcardId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
