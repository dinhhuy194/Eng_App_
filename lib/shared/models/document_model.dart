import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một tài liệu đã upload
class DocumentModel {
  final String id;
  final String title;
  final String? fileUrl;
  final String fileType; // pdf, docx, epub
  final String status; // uploading, parsing, ready, error
  final int pageCount;
  final int chunkCount;
  final DateTime createdAt;
  final DateTime? lastOpenedAt;

  const DocumentModel({
    required this.id,
    required this.title,
    this.fileUrl,
    required this.fileType,
    required this.status,
    this.pageCount = 0,
    this.chunkCount = 0,
    required this.createdAt,
    this.lastOpenedAt,
  });

  /// Tạo từ Firestore document
  factory DocumentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DocumentModel(
      id: doc.id,
      title: data['title'] ?? '',
      fileUrl: data['fileUrl'],
      fileType: data['fileType'] ?? 'pdf',
      status: data['status'] ?? 'uploading',
      pageCount: data['pageCount'] ?? 0,
      chunkCount: data['chunkCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastOpenedAt: (data['lastOpenedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Chuyển sang Map để lưu Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'status': status,
      'pageCount': pageCount,
      'chunkCount': chunkCount,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastOpenedAt != null)
        'lastOpenedAt': Timestamp.fromDate(lastOpenedAt!),
    };
  }

  /// Copy with pattern
  DocumentModel copyWith({
    String? id,
    String? title,
    String? fileUrl,
    String? fileType,
    String? status,
    int? pageCount,
    int? chunkCount,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      status: status ?? this.status,
      pageCount: pageCount ?? this.pageCount,
      chunkCount: chunkCount ?? this.chunkCount,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  /// Icon dựa theo loại file
  String get fileIcon {
    switch (fileType) {
      case 'pdf':
        return '📄';
      case 'docx':
        return '📝';
      case 'epub':
        return '📖';
      default:
        return '📁';
    }
  }

  bool get isReady => status == 'ready';
  bool get isUploading => status == 'uploading';
  bool get isParsing => status == 'parsing';
  bool get isError => status == 'error';
}

/// Model cho một chunk của tài liệu
class ChunkModel {
  final int index;
  final String text;
  final int tokenCount;

  const ChunkModel({
    required this.index,
    required this.text,
    required this.tokenCount,
  });

  factory ChunkModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChunkModel(
      index: data['index'] ?? 0,
      text: data['text'] ?? '',
      tokenCount: data['tokenCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'index': index,
      'text': text,
      'tokenCount': tokenCount,
    };
  }
}
