import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho một phiên học tập (Q&A, pronunciation, reading)
class SessionModel {
  final String id;
  final String type; // qa, pronunciation, reading
  final String documentId;
  final List<SessionMessage> messages;
  final int? score;
  final DateTime createdAt;

  const SessionModel({
    required this.id,
    required this.type,
    required this.documentId,
    this.messages = const [],
    this.score,
    required this.createdAt,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionModel(
      id: doc.id,
      type: data['type'] ?? 'qa',
      documentId: data['documentId'] ?? '',
      messages: (data['messages'] as List<dynamic>?)
              ?.map((m) => SessionMessage.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      score: data['score'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'documentId': documentId,
      'messages': messages.map((m) => m.toMap()).toList(),
      'score': score,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SessionModel addMessage(SessionMessage message) {
    return SessionModel(
      id: id,
      type: type,
      documentId: documentId,
      messages: [...messages, message],
      score: score,
      createdAt: createdAt,
    );
  }
}

/// Tin nhắn trong session (Q&A chat)
class SessionMessage {
  final String role; // user, assistant
  final String content;
  final DateTime timestamp;
  final List<int>? sourcesUsed; // chunk indices cho Q&A

  const SessionMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.sourcesUsed,
  });

  factory SessionMessage.fromMap(Map<String, dynamic> map) {
    return SessionMessage(
      role: map['role'] ?? 'user',
      content: map['content'] ?? '',
      timestamp:
          (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sourcesUsed: (map['sourcesUsed'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      if (sourcesUsed != null) 'sourcesUsed': sourcesUsed,
    };
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}
