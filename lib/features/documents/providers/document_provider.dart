import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/text_chunker.dart';
import '../../../shared/models/document_model.dart';
import '../services/pdf_parser.dart';

/// Trạng thái upload & parse tài liệu
class DocumentState {
  final bool isUploading;
  final bool isParsing;
  final double uploadProgress;
  final String? errorMessage;
  final String? statusMessage;

  const DocumentState({
    this.isUploading = false,
    this.isParsing = false,
    this.uploadProgress = 0,
    this.errorMessage,
    this.statusMessage,
  });

  DocumentState copyWith({
    bool? isUploading,
    bool? isParsing,
    double? uploadProgress,
    String? errorMessage,
    String? statusMessage,
  }) {
    return DocumentState(
      isUploading: isUploading ?? this.isUploading,
      isParsing: isParsing ?? this.isParsing,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: errorMessage,
      statusMessage: statusMessage,
    );
  }

  bool get isProcessing => isUploading || isParsing;
}

/// Document Notifier — quản lý upload, parse, CRUD tài liệu
class DocumentNotifier extends StateNotifier<DocumentState> {
  final FirebaseService _firebaseService = FirebaseService();

  DocumentNotifier() : super(const DocumentState());

  /// Parse tài liệu trên device và lưu text chunks vào Firestore
  /// (Không upload file gốc lên Storage — tiết kiệm chi phí)
  Future<void> uploadAndParse({
    required String fileName,
    required Uint8List fileBytes,
    required String fileType,
  }) async {
    try {
      // 1. Parse text trước để kiểm tra file hợp lệ
      state = state.copyWith(
        isParsing: true,
        uploadProgress: 0.1,
        statusMessage: 'Đang trích xuất nội dung...',
      );

      String extractedText = '';
      int pageCount = 0;

      if (fileType == 'pdf') {
        final result = PdfParserService.parsePdf(fileBytes);
        extractedText = result.text;
        pageCount = result.pageCount;
      } else {
        throw Exception(
            'Định dạng .$fileType chưa được hỗ trợ. Vui lòng dùng file PDF.');
      }

      if (extractedText.trim().isEmpty) {
        state = state.copyWith(
          isParsing: false,
          errorMessage:
              'Không thể trích xuất text từ file này. File có thể là ảnh scan.',
        );
        return;
      }

      // 2. Tạo document record trên Firestore
      state = state.copyWith(
        uploadProgress: 0.3,
        statusMessage: 'Đang tạo tài liệu...',
      );

      final docId = await _firebaseService.createDocument({
        'title': _cleanFileName(fileName),
        'fileType': fileType,
        'fileName': fileName,
        'status': 'parsing',
        'pageCount': pageCount,
        'chunkCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Chunk text
      state = state.copyWith(
        uploadProgress: 0.5,
        statusMessage: 'Đang chia nhỏ nội dung...',
      );

      final chunks = TextChunker.chunkText(extractedText);

      // 4. Lưu chunks vào Firestore
      state = state.copyWith(
        uploadProgress: 0.8,
        statusMessage: 'Đang lưu dữ liệu...',
      );

      await _firebaseService.saveChunks(docId, chunks);

      // 5. Cập nhật trạng thái document → ready
      await _firebaseService.updateDocument(docId, {
        'status': 'ready',
        'chunkCount': chunks.length,
      });

      state = state.copyWith(
        isParsing: false,
        uploadProgress: 1.0,
        statusMessage: 'Hoàn tất! Đã tạo ${chunks.length} phần.',
      );

      // Reset state sau 2 giây
      await Future.delayed(const Duration(seconds: 2));
      state = const DocumentState();
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        isParsing: false,
        errorMessage: 'Lỗi: ${e.toString()}',
      );
    }
  }

  /// Xóa tài liệu
  Future<void> deleteDocument(String docId) async {
    try {
      await _firebaseService.deleteDocument(docId);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Không thể xóa tài liệu: ${e.toString()}',
      );
    }
  }

  /// Cập nhật lastOpenedAt
  Future<void> markAsOpened(String docId) async {
    await _firebaseService.updateDocument(docId, {
      'lastOpenedAt': FieldValue.serverTimestamp(),
    });
  }

  void clearError() {
    state = const DocumentState();
  }

  String _cleanFileName(String name) {
    return name
        .replaceAll(RegExp(r'\.(pdf|docx|epub)$', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .trim();
  }
}

// ── Providers ──

final documentProvider =
    StateNotifierProvider<DocumentNotifier, DocumentState>(
  (ref) => DocumentNotifier(),
);

/// Stream các documents của user hiện tại
final documentsStreamProvider = StreamProvider<List<DocumentModel>>((ref) {
  return FirebaseService().getDocumentsStream().map(
        (snapshot) => snapshot.docs
            .map((doc) => DocumentModel.fromFirestore(doc))
            .toList(),
      );
});
