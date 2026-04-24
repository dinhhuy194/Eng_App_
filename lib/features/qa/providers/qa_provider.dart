import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/gemini_service.dart';

/// Trạng thái Q&A
class QAState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;

  const QAState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  QAState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
  }) {
    return QAState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Tin nhắn chat
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final List<int>? sources;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.sources,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, String> toHistoryMap() {
    return {
      'role': isUser ? 'user' : 'assistant',
      'content': text,
    };
  }
}

/// Q&A Notifier — quản lý hội thoại Q&A với AI
class QANotifier extends StateNotifier<QAState> {
  final GeminiService _geminiService = GeminiService();
  final String documentId;

  QANotifier({required this.documentId}) : super(const QAState());

  /// Gửi câu hỏi
  Future<void> sendQuestion(String question) async {
    if (question.trim().isEmpty || state.isLoading) return;

    // Thêm tin nhắn user
    final userMsg = ChatMessage(text: question, isUser: true);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      errorMessage: null,
    );

    try {
      // Build conversation history (giữ 6 turns gần nhất)
      final history = state.messages
          .where((m) => !m.isError)
          .toList()
          .reversed
          .take(12) // 6 turns = 12 messages (user + ai)
          .toList()
          .reversed
          .map((m) => m.toHistoryMap())
          .toList();

      final result = await _geminiService.askQuestion(
        question: question,
        documentId: documentId,
        conversationHistory: history,
      );

      final aiMsg = ChatMessage(
        text: result['answer'] ?? 'Không có câu trả lời',
        isUser: false,
        sources: List<int>.from(result['sourcesUsed'] ?? []),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );
    } catch (e) {
      final errorMsg = ChatMessage(
        text: 'Lỗi: ${e.toString().replaceAll('Exception: ', '')}',
        isUser: false,
        isError: true,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Xóa lịch sử chat
  void clearMessages() {
    state = const QAState();
  }

  /// Xóa lỗi
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

// ── Provider ──

/// Provider cho Q&A — cần truyền documentId qua family
final qaProvider =
    StateNotifierProvider.family<QANotifier, QAState, String>(
  (ref, documentId) => QANotifier(documentId: documentId),
);
