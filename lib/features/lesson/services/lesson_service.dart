import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/lesson_model.dart';

/// LessonService — CRUD + generate lessons từ document chunks
///
/// Firestore path: users/{uid}/lessons/{lessonId}
class LessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton
  static final LessonService _instance = LessonService._internal();
  factory LessonService() => _instance;
  LessonService._internal();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _lessonsRef {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('lessons');
  }

  // ═══════════════════════════════════════════
  //  GENERATE LESSONS
  // ═══════════════════════════════════════════

  /// Chia document chunks thành các lessons (mỗi lesson ~3-5 chunks)
  /// Trả về số lessons đã tạo
  Future<int> generateLessonsFromDocument({
    required String documentId,
    required String documentTitle,
    required List<Map<String, dynamic>> chunks,
    int chunksPerLesson = 3,
  }) async {
    if (chunks.isEmpty) return 0;

    // Kiểm tra đã tạo chưa
    final existing = await _lessonsRef
        .where('documentId', isEqualTo: documentId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      debugPrint('📚 [LessonService] Lessons đã tồn tại cho document $documentId');
      return existing.docs.length;
    }

    // Chia chunks thành groups
    final int totalLessons = (chunks.length / chunksPerLesson).ceil();
    final batch = _firestore.batch();

    for (int i = 0; i < totalLessons; i++) {
      final startIndex = i * chunksPerLesson;
      final endIndex = (startIndex + chunksPerLesson).clamp(0, chunks.length);
      final chunkIndices = List<int>.generate(
        endIndex - startIndex,
        (j) => startIndex + j,
      );

      final lessonDoc = _lessonsRef.doc();
      batch.set(lessonDoc, {
        'documentId': documentId,
        'documentTitle': documentTitle,
        'title': 'Bài ${i + 1}: ${_generateLessonTitle(chunks, startIndex)}',
        'lessonIndex': i,
        'chunkIndices': chunkIndices,
        'totalSteps': chunkIndices.length,
        'currentStep': 0,
        'progress': 0.0,
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint('📚 [LessonService] Đã tạo $totalLessons lessons cho "$documentTitle"');
    return totalLessons;
  }

  /// Tạo title cho lesson dựa trên nội dung chunk đầu tiên
  String _generateLessonTitle(
      List<Map<String, dynamic>> chunks, int startIndex) {
    if (startIndex >= chunks.length) return 'Nội dung';
    final text = chunks[startIndex]['text'] as String? ?? '';
    // Lấy ~30 ký tự đầu, tìm điểm cắt hợp lý (dấu cách)
    if (text.length <= 40) return text;
    final cutoff = text.substring(0, 40).lastIndexOf(' ');
    return '${text.substring(0, cutoff > 10 ? cutoff : 40)}...';
  }

  // ═══════════════════════════════════════════
  //  READ
  // ═══════════════════════════════════════════

  /// Stream lessons cho document cụ thể
  Stream<List<LessonModel>> getLessonsForDocument(String documentId) {
    return _lessonsRef
        .where('documentId', isEqualTo: documentId)
        .orderBy('lessonIndex')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LessonModel.fromFirestore(doc))
            .toList());
  }

  /// Lấy 1 lesson
  Future<LessonModel?> getLesson(String lessonId) async {
    final doc = await _lessonsRef.doc(lessonId).get();
    if (!doc.exists) return null;
    return LessonModel.fromFirestore(doc);
  }

  /// Lấy tất cả lessons (cho Home Screen stats)
  Future<List<LessonModel>> getAllLessons() async {
    final snapshot = await _lessonsRef
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => LessonModel.fromFirestore(doc))
        .toList();
  }

  // ═══════════════════════════════════════════
  //  UPDATE
  // ═══════════════════════════════════════════

  /// Cập nhật progress (khi user chuyển step)
  Future<void> updateProgress(String lessonId, int currentStep, int totalSteps) async {
    final progress = totalSteps > 0 ? currentStep / totalSteps : 0.0;
    final completed = currentStep >= totalSteps;

    final data = <String, dynamic>{
      'currentStep': currentStep,
      'progress': progress,
      'completed': completed,
    };

    if (completed) {
      data['completedAt'] = FieldValue.serverTimestamp();
    }

    await _lessonsRef.doc(lessonId).update(data);
    debugPrint('📚 [LessonService] Progress: $currentStep/$totalSteps (${(progress * 100).toInt()}%)');
  }

  /// Đánh dấu hoàn thành
  Future<void> markCompleted(String lessonId) async {
    await _lessonsRef.doc(lessonId).update({
      'completed': true,
      'progress': 1.0,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reset progress
  Future<void> resetProgress(String lessonId) async {
    await _lessonsRef.doc(lessonId).update({
      'currentStep': 0,
      'progress': 0.0,
      'completed': false,
      'completedAt': FieldValue.delete(),
    });
  }

  // ═══════════════════════════════════════════
  //  DELETE
  // ═══════════════════════════════════════════

  /// Xóa tất cả lessons của document
  Future<void> deleteLessonsForDocument(String documentId) async {
    final snapshot = await _lessonsRef
        .where('documentId', isEqualTo: documentId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
