import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../constants/api_constants.dart';

/// Service tập trung cho các thao tác Firebase
/// Auth, Firestore, Storage
class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── Singleton ──
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // ═══════════════════════════════════════════
  //  AUTH
  // ═══════════════════════════════════════════

  User? get currentUser => _auth.currentUser;
  String? get userId => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Tạo hoặc cập nhật user profile trong Firestore
  Future<void> createUserProfile(User user) async {
    final ref = _firestore
        .collection(ApiConstants.usersCollection)
        .doc(user.uid);

    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'name': user.displayName ?? 'Người dùng',
        'email': user.email ?? '',
        'avatarUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'dailyApiUsage': 0,
      });
    }
  }

  // ═══════════════════════════════════════════
  //  FIRESTORE — Documents
  // ═══════════════════════════════════════════

  /// Reference đến documents subcollection của user hiện tại
  CollectionReference get _documentsRef {
    return _firestore
        .collection(ApiConstants.usersCollection)
        .doc(userId)
        .collection(ApiConstants.documentsSubcollection);
  }

  /// Lấy danh sách tài liệu
  Stream<QuerySnapshot> getDocumentsStream() {
    return _documentsRef.orderBy('createdAt', descending: true).snapshots();
  }

  /// Tạo document mới
  Future<String> createDocument(Map<String, dynamic> data) async {
    final doc = await _documentsRef.add(data);
    return doc.id;
  }

  /// Cập nhật document
  Future<void> updateDocument(String docId, Map<String, dynamic> data) async {
    await _documentsRef.doc(docId).update(data);
  }

  /// Xóa document và tất cả chunks
  Future<void> deleteDocument(String docId) async {
    // Xóa chunks
    final chunks = await _documentsRef
        .doc(docId)
        .collection(ApiConstants.chunksSubcollection)
        .get();
    for (final chunk in chunks.docs) {
      await chunk.reference.delete();
    }

    // Xóa file trên Storage
    try {
      final doc = await _documentsRef.doc(docId).get();
      final fileUrl = (doc.data() as Map<String, dynamic>?)?['fileUrl'];
      if (fileUrl != null) {
        await _storage.refFromURL(fileUrl).delete();
      }
    } catch (_) {
      // File có thể không tồn tại
    }

    // Xóa document
    await _documentsRef.doc(docId).delete();
  }

  // ═══════════════════════════════════════════
  //  FIRESTORE — Chunks
  // ═══════════════════════════════════════════

  /// Lưu chunks cho document
  Future<void> saveChunks(
      String docId, List<Map<String, dynamic>> chunks) async {
    final batch = _firestore.batch();
    final chunksRef = _documentsRef
        .doc(docId)
        .collection(ApiConstants.chunksSubcollection);

    for (int i = 0; i < chunks.length; i++) {
      batch.set(chunksRef.doc(i.toString()), chunks[i]);
    }
    await batch.commit();
  }

  /// Lấy tất cả chunks của document
  Future<List<Map<String, dynamic>>> getChunks(String docId) async {
    final snapshot = await _documentsRef
        .doc(docId)
        .collection(ApiConstants.chunksSubcollection)
        .orderBy('index')
        .get();

    return snapshot.docs
        .map((doc) => doc.data())
        .toList();
  }

  // ═══════════════════════════════════════════
  //  FIRESTORE — Quizzes
  // ═══════════════════════════════════════════

  CollectionReference get _quizzesRef {
    return _firestore
        .collection(ApiConstants.usersCollection)
        .doc(userId)
        .collection(ApiConstants.quizzesSubcollection);
  }

  Future<String> saveQuiz(Map<String, dynamic> data) async {
    final doc = await _quizzesRef.add(data);
    return doc.id;
  }

  Future<void> updateQuiz(String quizId, Map<String, dynamic> data) async {
    await _quizzesRef.doc(quizId).update(data);
  }

  Stream<QuerySnapshot> getQuizzesStream(String documentId) {
    return _quizzesRef
        .where('documentId', isEqualTo: documentId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ═══════════════════════════════════════════
  //  FIRESTORE — Sessions
  // ═══════════════════════════════════════════

  CollectionReference get _sessionsRef {
    return _firestore
        .collection(ApiConstants.usersCollection)
        .doc(userId)
        .collection(ApiConstants.sessionsSubcollection);
  }

  Future<String> createSession(Map<String, dynamic> data) async {
    final doc = await _sessionsRef.add(data);
    return doc.id;
  }

  Future<void> updateSession(
      String sessionId, Map<String, dynamic> data) async {
    await _sessionsRef.doc(sessionId).update(data);
  }

  // ═══════════════════════════════════════════
  //  STORAGE
  // ═══════════════════════════════════════════

  /// Upload file lên Firebase Storage
  Future<String> uploadFile({
    required String fileName,
    required Uint8List fileBytes,
    required String docId,
  }) async {
    final ref = _storage.ref().child(
        '${ApiConstants.userStoragePath(userId!)}/$docId/$fileName');
    
    final uploadTask = await ref.putData(
      fileBytes,
      SettableMetadata(contentType: _getContentType(fileName)),
    );

    return await uploadTask.ref.getDownloadURL();
  }

  String _getContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'epub':
        return 'application/epub+zip';
      default:
        return 'application/octet-stream';
    }
  }
}
